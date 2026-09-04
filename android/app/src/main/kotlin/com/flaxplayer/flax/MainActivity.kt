package com.flaxplayer.flax

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.flaxplayer.flax.download.DownloadTask
import com.flaxplayer.flax.download.FlaxDownloadManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val INSTALLER_CHANNEL = "com.flax/package_installer"
    private val DOWNLOADER_CHANNEL = "com.flax/native_downloader"
    private val DOWNLOADER_EVENTS = "com.flax/native_downloader_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Package installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
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
            } else {
                result.notImplemented()
            }
        }

        // Native downloader method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val rawTasks = call.argument<List<Map<String, Any?>>>("tasks")
                    val concurrency = call.argument<Int>("concurrency") ?: 4
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
                        FlaxDownloadManager.enqueue(this, tasks, concurrency)
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
    }
}
