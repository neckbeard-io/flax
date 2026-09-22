package com.flaxplayer.flax

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.car.app.connection.CarConnection
import androidx.core.content.FileProvider
import androidx.lifecycle.Observer
import com.flaxplayer.flax.download.DownloadTask
import com.flaxplayer.flax.download.FlaxDownloadManager
import com.flaxplayer.flax.sync.FlaxSyncManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

object FlaxEngineHelper {
    private const val INSTALLER_CHANNEL = "com.flax/package_installer"
    private const val INSTALLER_EVENTS = "com.flax/package_installer_events"
    private const val DOWNLOADER_CHANNEL = "com.flax/native_downloader"
    private const val DOWNLOADER_EVENTS = "com.flax/native_downloader_events"
    private const val SYNC_CHANNEL = "com.flax/background_sync"
    private const val CAR_CHANNEL = "com.flax/car_connection"
    private const val CAR_EVENTS = "com.flax/car_connection_events"
    private const val NETWORK_CHANNEL = "com.flax/network_status"
    private const val NETWORK_EVENTS = "com.flax/network_status_events"

    private var networkEventSink: EventChannel.EventSink? = null
    private var defaultNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var carConnection: CarConnection? = null
    private var carObserver: Observer<Int>? = null
    private var carEventSink: EventChannel.EventSink? = null
    private var installerEventSink: EventChannel.EventSink? = null
    private var apkDownloadCall: okhttp3.Call? = null
    private var configuredEngine: FlutterEngine? = null

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    private val installerClient by lazy {
        OkHttpClient.Builder()
            .followRedirects(true)
            .followSslRedirects(true)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    var permissionHandler: PermissionHandler? = null

    interface PermissionHandler {
        fun requestNotificationPermission()
        fun requestLocationPermission()
    }

    fun requestWarmUpFrame() {
        mainHandler.post {
            configuredEngine?.let { engine ->
                try {
                    MethodChannel(engine.dartExecutor.binaryMessenger, CAR_CHANNEL)
                        .invokeMethod("requestWarmUpFrame", null)
                } catch (_: Exception) {}
            }
        }
    }

    fun configure(flutterEngine: FlutterEngine, context: Context) {
        if (configuredEngine == flutterEngine) {
            return
        }
        configuredEngine = flutterEngine
        val appContext = context.applicationContext

        FlaxMediaSessionHelper.wrapServiceListener(appContext)
        FlaxMediaSessionHelper.activateMediaSession(appContext)

        // Package installer event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    installerEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    installerEventSink = null
                }
            }
        )

        // Package installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                if (!appContext.packageManager.canRequestPackageInstalls()) {
                                    val permissionIntent = Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:${appContext.packageName}")
                                    ).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    appContext.startActivity(permissionIntent)
                                    result.success(false)
                                    return@setMethodCallHandler
                                }
                            }
                            val file = File(filePath)
                            val uri: Uri = FileProvider.getUriForFile(
                                appContext,
                                "${appContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            appContext.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
                }
                "downloadApk" -> {
                    val url = call.argument<String>("url")
                    val destinationPath = call.argument<String>("destinationPath")
                    if (url == null || destinationPath == null) {
                        result.error("INVALID_ARGUMENT", "url and destinationPath are required", null)
                        return@setMethodCallHandler
                    }

                    val destFile = File(destinationPath)
                    val tempFile = File("$destinationPath.tmp")
                    destFile.parentFile?.mkdirs()

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val request = Request.Builder()
                                .url(url)
                                .header("User-Agent", "Flax-UpdateChecker")
                                .header("Accept", "application/octet-stream")
                                .build()

                            val callInstance = installerClient.newCall(request)
                            apkDownloadCall = callInstance
                            val response = callInstance.execute()

                            if (!response.isSuccessful) {
                                throw Exception("HTTP ${response.code}: ${response.message}")
                            }

                            val body = response.body ?: throw Exception("Empty response body")
                            val totalBytes = body.contentLength()
                            val inputStream = body.byteStream()
                            val outputStream = FileOutputStream(tempFile)

                            var bytesRead: Int
                            var totalRead = 0L
                            val buffer = ByteArray(65536) // 64 KB high-throughput buffer
                            var lastProgressTime = System.currentTimeMillis()

                            inputStream.use { input ->
                                outputStream.use { output ->
                                    while (input.read(buffer).also { bytesRead = it } != -1) {
                                        output.write(buffer, 0, bytesRead)
                                        totalRead += bytesRead
                                        val now = System.currentTimeMillis()
                                        if (now - lastProgressTime >= 100 || totalRead == totalBytes) {
                                            lastProgressTime = now
                                            mainHandler.post {
                                                installerEventSink?.success(
                                                    mapOf(
                                                        "type" to "progress",
                                                        "received" to totalRead,
                                                        "total" to totalBytes
                                                    )
                                                )
                                            }
                                        }
                                    }
                                    output.flush()
                                }
                            }

                            if (tempFile.exists() && tempFile.length() > 0) {
                                if (destFile.exists()) destFile.delete()
                                tempFile.renameTo(destFile)
                            }

                            mainHandler.post {
                                result.success(destFile.absolutePath)
                            }
                        } catch (e: Exception) {
                            tempFile.delete()
                            val isCanceled = apkDownloadCall?.isCanceled() == true
                            mainHandler.post {
                                if (isCanceled) {
                                    result.error("CANCELED", "Download canceled", null)
                                } else {
                                    result.error("DOWNLOAD_ERROR", e.message ?: "Download failed", null)
                                }
                            }
                        } finally {
                            apkDownloadCall = null
                        }
                    }
                }
                "cancelDownload" -> {
                    apkDownloadCall?.cancel()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Native downloader method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    permissionHandler?.requestNotificationPermission()
                    result.success(true)
                }
                "requestLocationPermission" -> {
                    permissionHandler?.requestLocationPermission()
                    result.success(true)
                }
                "startDownload" -> {
                    permissionHandler?.requestNotificationPermission()
                    val rawTasks = call.argument<List<Map<String, Any?>>>("tasks")
                    val concurrency = call.argument<Int>("concurrency") ?: 4
                    val notificationTitle = call.argument<String>("notificationTitle")
                    if (rawTasks != null) {
                        val tasks = rawTasks.mapNotNull { map ->
                            val songId = map["songId"] as? String ?: return@mapNotNull null
                            val serverId = map["serverId"] as? String ?: return@mapNotNull null
                            val title = map["title"] as? String ?: return@mapNotNull null
                            val artist = map["artist"] as? String
                            val downloadUrl = map["downloadUrl"] as? String ?: return@mapNotNull null
                            val destinationPath = map["destinationPath"] as? String ?: return@mapNotNull null
                            val expectedSizeBytes = (map["expectedSizeBytes"] as? Number)?.toLong()

                            DownloadTask(
                                songId = songId,
                                serverId = serverId,
                                title = title,
                                artist = artist,
                                downloadUrl = downloadUrl,
                                destinationPath = destinationPath,
                                expectedSizeBytes = expectedSizeBytes
                            )
                        }
                        FlaxDownloadManager.enqueue(appContext, tasks, concurrency, notificationTitle)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "tasks list is required", null)
                    }
                }
                "cancelSongs" -> {
                    val songIds = call.argument<List<String>>("songIds")
                    if (songIds != null) {
                        FlaxDownloadManager.cancelSongs(appContext, songIds.toSet())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "songIds list is required", null)
                    }
                }
                "cancelAll" -> {
                    FlaxDownloadManager.cancelAll(appContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Native downloader event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADER_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FlaxDownloadManager.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    FlaxDownloadManager.setEventSink(null)
                }
            }
        )

        // Background sync method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedulePeriodicSync" -> {
                    val intervalHours = (call.argument<Number>("intervalHours"))?.toLong() ?: 24L
                    val requiresCharging = call.argument<Boolean>("requiresCharging") ?: true
                    val wifiOnly = call.argument<Boolean>("wifiOnly") ?: true
                    val fullMetadata = call.argument<Boolean>("fullMetadata") ?: false
                    FlaxSyncManager.schedulePeriodicSync(appContext, intervalHours, requiresCharging, wifiOnly, fullMetadata)
                    result.success(true)
                }
                "cancelPeriodicSync" -> {
                    FlaxSyncManager.cancelPeriodicSync(appContext)
                    result.success(true)
                }
                "triggerImmediateSync" -> {
                    FlaxSyncManager.triggerImmediateSync(appContext)
                    result.success(true)
                }
                "getSyncStatus" -> {
                    val status = FlaxSyncManager.getSyncStatus(appContext)
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }

        // Car connection channel
        if (carConnection == null) {
            try {
                val conn = CarConnection(appContext)
                carConnection = conn
                val observer = Observer<Int> { type ->
                    val isConnected = (type == CarConnection.CONNECTION_TYPE_PROJECTION || type == CarConnection.CONNECTION_TYPE_NATIVE)
                    if (isConnected) {
                        FlaxMediaSessionHelper.activateMediaSession(appContext)
                    }
                    mainHandler.post {
                        carEventSink?.success(isConnected)
                    }
                }
                carObserver = observer
                conn.type.observeForever(observer)
            } catch (_: Exception) {}
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isCarConnected" -> {
                    val type = carConnection?.type?.value ?: CarConnection.CONNECTION_TYPE_NOT_CONNECTED
                    val isConnected = (type == CarConnection.CONNECTION_TYPE_PROJECTION || type == CarConnection.CONNECTION_TYPE_NATIVE)
                    result.success(isConnected)
                }
                "activateMediaSession" -> {
                    val success = FlaxMediaSessionHelper.activateMediaSession(appContext)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CAR_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    carEventSink = events
                    val currentType = carConnection?.type?.value ?: CarConnection.CONNECTION_TYPE_NOT_CONNECTED
                    val isConnected = (currentType == CarConnection.CONNECTION_TYPE_PROJECTION || currentType == CarConnection.CONNECTION_TYPE_NATIVE)
                    events?.success(isConnected)
                }

                override fun onCancel(arguments: Any?) {
                    carEventSink = null
                }
            }
        )

        // Primary network status channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrimaryNetworkInfo" -> {
                    result.success(getPrimaryNetworkInfo(appContext))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    networkEventSink = events
                    val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    if (cm != null && defaultNetworkCallback == null) {
                        val callback = object : ConnectivityManager.NetworkCallback() {
                            override fun onAvailable(network: Network) {
                                mainHandler.post {
                                    networkEventSink?.success(getPrimaryNetworkInfo(appContext))
                                }
                            }
                            override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                                mainHandler.post {
                                    networkEventSink?.success(getPrimaryNetworkInfo(appContext))
                                }
                            }
                            override fun onLost(network: Network) {
                                mainHandler.post {
                                    networkEventSink?.success(getPrimaryNetworkInfo(appContext))
                                }
                            }
                        }
                        defaultNetworkCallback = callback
                        try {
                            cm.registerDefaultNetworkCallback(callback)
                        } catch (_: Exception) {}
                    }
                    events?.success(getPrimaryNetworkInfo(appContext))
                }

                override fun onCancel(arguments: Any?) {
                    networkEventSink = null
                    val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    if (cm != null && defaultNetworkCallback != null) {
                        try {
                            cm.unregisterNetworkCallback(defaultNetworkCallback!!)
                        } catch (_: Exception) {}
                        defaultNetworkCallback = null
                    }
                }
            }
        )
    }

    @Suppress("DEPRECATION")
    fun getPrimaryNetworkInfo(context: Context): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return mapOf(
                "primaryTransport" to "none",
                "isWifiPrimary" to false,
                "isCellularPrimary" to false,
                "isEthernetPrimary" to false,
                "isWifiConnected" to false,
                "isWifiValidated" to false
            )

        val activeNetwork = cm.activeNetwork
        val activeCaps = activeNetwork?.let { cm.getNetworkCapabilities(it) }

        val allNetworks = cm.allNetworks
        var anyWifiConnected = false
        var anyWifiValidated = false
        var anyCellularConnected = false
        var anyCellularValidated = false

        for (network in allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            val isValidated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI_AWARE)) {
                anyWifiConnected = true
                if (isValidated) {
                    anyWifiValidated = true
                }
            }
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                anyCellularConnected = true
                if (isValidated) {
                    anyCellularValidated = true
                }
            }
        }

        var primaryTransport = "none"
        var isWifiPrimary = false
        var isCellularPrimary = false
        var isEthernetPrimary = false

        if (activeCaps != null && activeCaps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            val isEthernet = activeCaps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
            val isWifi = activeCaps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                         activeCaps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI_AWARE)
            val isCellular = activeCaps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
            val isVpn = activeCaps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            val isValidated = activeCaps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

            if (isEthernet) {
                primaryTransport = "ethernet"
                isEthernetPrimary = true
            } else if (isCellular) {
                primaryTransport = "cellular"
                isCellularPrimary = true
            } else if (isWifi) {
                if (!isValidated && anyCellularValidated) {
                    primaryTransport = "cellular"
                    isCellularPrimary = true
                } else {
                    primaryTransport = "wifi"
                    isWifiPrimary = isValidated || !anyCellularConnected
                }
            } else if (isVpn) {
                if (anyWifiValidated) {
                    primaryTransport = "wifi"
                    isWifiPrimary = true
                } else if (anyCellularValidated || anyCellularConnected) {
                    primaryTransport = "cellular"
                    isCellularPrimary = true
                } else {
                    primaryTransport = "vpn"
                }
            } else {
                primaryTransport = "other"
            }
        } else {
            if (anyCellularValidated) {
                primaryTransport = "cellular"
                isCellularPrimary = true
            } else if (anyWifiValidated) {
                primaryTransport = "wifi"
                isWifiPrimary = true
            } else if (anyWifiConnected && !anyCellularConnected) {
                primaryTransport = "wifi"
                isWifiPrimary = true
            }
        }

        return mapOf(
            "primaryTransport" to primaryTransport,
            "isWifiPrimary" to isWifiPrimary,
            "isCellularPrimary" to isCellularPrimary,
            "isEthernetPrimary" to isEthernetPrimary,
            "isWifiConnected" to anyWifiConnected,
            "isWifiValidated" to anyWifiValidated
        )
    }
}
