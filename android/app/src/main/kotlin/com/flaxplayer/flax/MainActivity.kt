package com.flaxplayer.flax

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.flaxplayer.flax.download.DownloadTask
import com.flaxplayer.flax.download.FlaxDownloadManager
import com.flaxplayer.flax.sync.FlaxSyncManager
import com.ryanheise.audioservice.AudioServiceActivity
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

class MainActivity : AudioServiceActivity() {
    private val INSTALLER_CHANNEL = "com.flax/package_installer"
    private val INSTALLER_EVENTS = "com.flax/package_installer_events"
    private val DOWNLOADER_CHANNEL = "com.flax/native_downloader"
    private val DOWNLOADER_EVENTS = "com.flax/native_downloader_events"
    private val SYNC_CHANNEL = "com.flax/background_sync"

    private var installerEventSink: EventChannel.EventSink? = null
    private var apkDownloadCall: okhttp3.Call? = null
    private val installerClient by lazy {
        OkHttpClient.Builder()
            .followRedirects(true)
            .followSslRedirects(true)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        }
    }

    private fun requestLocationPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                1002
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                                if (!packageManager.canRequestPackageInstalls()) {
                                    val permissionIntent = Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName")
                                    ).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(permissionIntent)
                                    result.success(false)
                                    return@setMethodCallHandler
                                }
                            }
                            val file = File(filePath)
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
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
                                            runOnUiThread {
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

                            runOnUiThread {
                                result.success(destFile.absolutePath)
                            }
                        } catch (e: Exception) {
                            tempFile.delete()
                            val isCanceled = apkDownloadCall?.isCanceled() == true
                            runOnUiThread {
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
                    requestNotificationPermission()
                    result.success(true)
                }
                "requestLocationPermission" -> {
                    requestLocationPermission()
                    result.success(true)
                }
                "startDownload" -> {
                    requestNotificationPermission()
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
                        FlaxDownloadManager.enqueue(this, tasks, concurrency, notificationTitle)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "tasks list is required", null)
                    }
                }
                "cancelSongs" -> {
                    val songIds = call.argument<List<String>>("songIds")
                    if (songIds != null) {
                        FlaxDownloadManager.cancelSongs(this, songIds.toSet())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "songIds list is required", null)
                    }
                }
                "cancelAll" -> {
                    FlaxDownloadManager.cancelAll(this)
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
                    FlaxSyncManager.schedulePeriodicSync(this, intervalHours, requiresCharging, wifiOnly, fullMetadata)
                    result.success(true)
                }
                "cancelPeriodicSync" -> {
                    FlaxSyncManager.cancelPeriodicSync(this)
                    result.success(true)
                }
                "triggerImmediateSync" -> {
                    FlaxSyncManager.triggerImmediateSync(this)
                    result.success(true)
                }
                "getSyncStatus" -> {
                    val status = FlaxSyncManager.getSyncStatus(this)
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }
}
