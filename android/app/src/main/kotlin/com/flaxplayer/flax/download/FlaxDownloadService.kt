package com.flaxplayer.flax.download

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.flaxplayer.flax.MainActivity
import com.flaxplayer.flax.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.ConnectionPool
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class FlaxDownloadService : Service() {

    companion object {
        const val ACTION_START_DOWNLOADS = "com.flax.download.START"
        const val ACTION_CHECK_QUEUE = "com.flax.download.CHECK_QUEUE"
        const val ACTION_CANCEL_ALL = "com.flax.download.CANCEL_ALL"
        const val CHANNEL_ID = "flax_audio_downloads_v2"
        const val NOTIFICATION_ID = 9021
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private lateinit var notificationManager: NotificationManager

    private val okHttpClient = OkHttpClient.Builder()
        .connectionPool(ConnectionPool(32, 5, TimeUnit.MINUTES))
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val isDownloading = AtomicBoolean(false)
    private val activeWorkerCount = java.util.concurrent.atomic.AtomicInteger(0)
    private val workerLock = Any()

    // Speed tracking
    private var lastSpeedCheckTime = System.currentTimeMillis()
    private var lastSpeedBytes = 0L
    private var currentSpeedBytesPerSec = 0L
    private var lastNotificationTime = 0L

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        acquireLocks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL_ALL -> {
                cancelAllDownloads()
            }
            ACTION_CHECK_QUEUE -> {
                checkQueueStatus()
            }
            ACTION_START_DOWNLOADS -> {
                val total = FlaxDownloadManager.totalEnqueuedTasks.get()
                val completed = FlaxDownloadManager.completedSessionTasks.get()

                if (isDownloading.compareAndSet(false, true)) {
                    val initialNotification = buildNotification("Downloading music...", completed, total, 0)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(NOTIFICATION_ID, initialNotification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                    } else {
                        startForeground(NOTIFICATION_ID, initialNotification)
                    }
                } else {
                    updateNotification("Downloading tracks...", completed, total, currentSpeedBytesPerSec)
                }
                ensureWorkersRunning()
            }
        }
        return START_NOT_STICKY
    }

    private fun acquireLocks() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Flax::AudioDownloadWakeLock").apply {
                setReferenceCounted(false)
                acquire(TimeUnit.HOURS.toMillis(2))
            }

            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiLockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wifiManager.createWifiLock(wifiLockMode, "Flax::AudioDownloadWifiLock").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (_: Exception) {}
    }

    private fun releaseLocks() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: Exception) {}
    }

    private fun ensureWorkersRunning() {
        synchronized(workerLock) {
            val concurrency = FlaxDownloadManager.maxConcurrency.coerceAtLeast(1)
            val current = activeWorkerCount.get()
            val needed = (concurrency - current).coerceAtLeast(0)

            for (i in 0 until needed) {
                activeWorkerCount.incrementAndGet()
                serviceScope.launch {
                    try {
                        while (isActive) {
                            val task = FlaxDownloadManager.pendingQueue.poll() ?: break
                            if (FlaxDownloadManager.canceledSongIds.contains(task.songId)) {
                                continue
                            }
                            downloadSingleTask(task)
                        }
                    } catch (_: Exception) {
                    } finally {
                        activeWorkerCount.decrementAndGet()
                        checkQueueStatus()
                    }
                }
            }
        }
    }

    private fun checkQueueStatus() {
        if (!FlaxDownloadManager.pendingQueue.isEmpty()) {
            ensureWorkersRunning()
            return
        }
        if (FlaxDownloadManager.pendingQueue.isEmpty() &&
            FlaxDownloadManager.activeTasks.isEmpty() &&
            activeWorkerCount.get() == 0) {
            isDownloading.set(false)
            val finalCompleted = FlaxDownloadManager.completedSessionTasks.get()
            val finalBytes = FlaxDownloadManager.totalSessionBytes.get()
            FlaxDownloadManager.notifyQueueCompleted(finalCompleted, finalBytes)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun downloadSingleTask(task: DownloadTask) {
        if (FlaxDownloadManager.canceledSongIds.contains(task.songId)) return

        FlaxDownloadManager.notifyTaskStarted(task)
        updateNotification(
            task.title,
            FlaxDownloadManager.completedSessionTasks.get(),
            FlaxDownloadManager.totalEnqueuedTasks.get(),
            currentSpeedBytesPerSec
        )

        val destFile = File(task.destinationPath)
        val tempFile = File("${task.destinationPath}.tmp")
        destFile.parentFile?.mkdirs()

        var taskBytes = 0L
        val buffer = ByteArray(65536) // 64 KB high-throughput buffer

        try {
            val request = Request.Builder()
                .url(task.downloadUrl)
                .header("Connection", "keep-alive")
                .header("Accept-Encoding", "identity")
                .build()

            val response = okHttpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                throw Exception("HTTP ${response.code}: ${response.message}")
            }

            val body = response.body ?: throw Exception("Empty response body")
            val totalLength = body.contentLength()
            val inputStream = body.byteStream()
            val outputStream = FileOutputStream(tempFile)

            var bytesRead: Int
            var lastProgressTime = System.currentTimeMillis()

            inputStream.use { input ->
                outputStream.use { output ->
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        if (FlaxDownloadManager.canceledSongIds.contains(task.songId)) {
                            throw Exception("Canceled")
                        }
                        output.write(buffer, 0, bytesRead)
                        taskBytes += bytesRead
                        FlaxDownloadManager.totalSessionBytes.addAndGet(bytesRead.toLong())

                        val now = System.currentTimeMillis()
                        if (now - lastProgressTime >= 250) {
                            lastProgressTime = now
                            calculateSpeed(now)
                            val completed = FlaxDownloadManager.completedSessionTasks.get()
                            val total = FlaxDownloadManager.totalEnqueuedTasks.get()
                            FlaxDownloadManager.notifyTaskProgress(
                                task.songId,
                                task.serverId,
                                taskBytes,
                                totalLength,
                                currentSpeedBytesPerSec,
                                completed,
                                total
                            )
                            updateNotificationThrottled(task.title, completed, total, currentSpeedBytesPerSec)
                        }
                    }
                    output.flush()
                }
            }

            if (tempFile.exists() && tempFile.length() > 0) {
                if (destFile.exists()) destFile.delete()
                tempFile.renameTo(destFile)
            }

            val done = FlaxDownloadManager.completedSessionTasks.incrementAndGet()
            val total = FlaxDownloadManager.totalEnqueuedTasks.get()
            FlaxDownloadManager.notifyTaskCompleted(task, destFile.absolutePath, done, total)
            updateNotification(task.title, done, total, currentSpeedBytesPerSec)

        } catch (e: Exception) {
            tempFile.delete()
            val done = FlaxDownloadManager.completedSessionTasks.get()
            val total = FlaxDownloadManager.totalEnqueuedTasks.get()
            FlaxDownloadManager.notifyTaskFailed(task, e.message ?: "Unknown download error", done, total)
        }
    }

    private fun calculateSpeed(now: Long) {
        val timeDelta = now - lastSpeedCheckTime
        if (timeDelta >= 1000) {
            val total = FlaxDownloadManager.totalSessionBytes.get()
            val byteDelta = total - lastSpeedBytes
            currentSpeedBytesPerSec = if (timeDelta > 0) (byteDelta * 1000) / timeDelta else 0L
            lastSpeedBytes = total
            lastSpeedCheckTime = now
        }
    }

    private fun updateNotificationThrottled(title: String, completed: Int, total: Int, speed: Long) {
        val now = System.currentTimeMillis()
        if (now - lastNotificationTime >= 500) {
            lastNotificationTime = now
            updateNotification(title, completed, total, speed)
        }
    }

    private fun updateNotification(title: String, completed: Int, total: Int, speed: Long) {
        notificationManager.notify(NOTIFICATION_ID, buildNotification(title, completed, total, speed))
    }

    private fun buildNotification(title: String, completed: Int, total: Int, speed: Long): Notification {
        val speedStr = if (speed > 0) " • ${formatBytes(speed)}/s" else ""
        val defaultPrefix = FlaxDownloadManager.customNotificationTitle ?: if (total > 0) "Downloading $total tracks" else "Downloading music"
        val contentTitle = "$defaultPrefix$speedStr"
        val contentText = if (total > 0) "($completed/$total) $title" else title

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingOpenIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cancelIntent = Intent(this, FlaxDownloadService::class.java).apply {
            action = ACTION_CANCEL_ALL
        }
        val pendingCancelIntent = PendingIntent.getService(
            this,
            1,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setContentIntent(pendingOpenIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", pendingCancelIntent)

        if (total > 0) {
            builder.setProgress(total, completed.coerceAtMost(total), false)
        } else {
            builder.setProgress(0, 0, true)
        }

        return builder.build()
    }

    private fun formatBytes(bytes: Long): String {
        return when {
            bytes >= 1000L * 1000L * 1000L -> String.format("%.1f GB", bytes / (1000.0 * 1000.0 * 1000.0))
            bytes >= 1000L * 1000L -> String.format("%.1f MB", bytes / (1000.0 * 1000.0))
            bytes >= 1000L -> String.format("%.1f KB", bytes / 1000.0)
            else -> "$bytes B"
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                notificationManager.deleteNotificationChannel("flax_download_channel")
            } catch (_: Exception) {}

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Flax Downloads",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows live download progress and transfer speeds for offline caching."
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun cancelAllDownloads() {
        FlaxDownloadManager.cancelAll(this)
        isDownloading.set(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        releaseLocks()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
