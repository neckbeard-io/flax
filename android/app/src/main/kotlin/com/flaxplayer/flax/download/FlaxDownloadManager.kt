package com.flaxplayer.flax.download

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

object FlaxDownloadManager {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    val pendingQueue = ConcurrentLinkedQueue<DownloadTask>()
    val activeTasks = ConcurrentHashMap<String, DownloadTask>()
    val canceledSongIds = ConcurrentHashMap.newKeySet<String>()

    val totalEnqueuedTasks = AtomicInteger(0)
    val completedSessionTasks = AtomicInteger(0)
    val totalSessionBytes = AtomicLong(0)

    var maxConcurrency: Int = 4
    var customNotificationTitle: String? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * Queues [tasks] and starts the service. False when Android refused to
     * start it, which it does once flax is in the background; the tasks are
     * taken back off the queue so the caller can fetch them another way.
     */
    fun enqueue(context: Context, tasks: List<DownloadTask>, concurrency: Int = 4, notificationTitle: String? = null): Boolean {
        maxConcurrency = concurrency.coerceIn(1, 32)
        customNotificationTitle = notificationTitle
        val existingIds = pendingQueue.map { it.songId }.toSet() + activeTasks.keys
        val newTasks = tasks.filter { it.songId !in existingIds }
        if (newTasks.isEmpty()) return true

        newTasks.forEach { canceledSongIds.remove(it.songId) }
        pendingQueue.addAll(newTasks)
        totalEnqueuedTasks.addAndGet(newTasks.size)

        val intent = Intent(context, FlaxDownloadService::class.java).apply {
            action = FlaxDownloadService.ACTION_START_DOWNLOADS
        }
        return try {
            context.startForegroundService(intent)
            true
        } catch (e: Exception) {
            val ids = newTasks.map { it.songId }.toSet()
            pendingQueue.removeIf { it.songId in ids }
            totalEnqueuedTasks.addAndGet(-newTasks.size)
            false
        }
    }

    fun cancelSongs(context: Context, songIds: Set<String>) {
        canceledSongIds.addAll(songIds)
        pendingQueue.removeIf { it.songId in songIds }

        val intent = Intent(context, FlaxDownloadService::class.java).apply {
            action = FlaxDownloadService.ACTION_CHECK_QUEUE
        }
        context.startService(intent)

        songIds.forEach { id ->
            sendEvent(
                mapOf(
                    "type" to "task_canceled",
                    "songId" to id
                )
            )
        }
    }

    /**
     * Empties the queue and marks every download in progress canceled, so its
     * worker stops at the next chunk. Does not touch the service.
     */
    fun clearQueue() {
        pendingQueue.clear()
        canceledSongIds.addAll(activeTasks.keys)
        customNotificationTitle = null
        totalEnqueuedTasks.set(0)
        completedSessionTasks.set(0)
        totalSessionBytes.set(0)
    }

    /**
     * Cancels everything, from Dart. The service stops, removes its
     * notification and reports `canceled`.
     *
     * This used to clear the queue and then send the service a cancel that
     * called back into here, which sent another: the service restarted itself
     * every few milliseconds, and downloads still in flight re-posted the
     * notification, which no cancel removed.
     */
    fun cancelAll(context: Context) {
        clearQueue()
        val intent = Intent(context, FlaxDownloadService::class.java).apply {
            action = FlaxDownloadService.ACTION_CANCEL_ALL
        }
        try {
            context.startService(intent)
        } catch (_: Exception) {
            // Not running, and Android will not start it from the background:
            // there is nothing to stop.
            sendEvent(mapOf("type" to "canceled"))
        }
    }

    fun resetSession() {
        activeTasks.clear()
        canceledSongIds.clear()
        customNotificationTitle = null
        totalEnqueuedTasks.set(0)
        completedSessionTasks.set(0)
        totalSessionBytes.set(0)
    }

    fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }

    fun notifyTaskStarted(task: DownloadTask) {
        activeTasks[task.songId] = task
        sendEvent(
            mapOf(
                "type" to "task_started",
                "songId" to task.songId,
                "serverId" to task.serverId,
                "title" to task.title
            )
        )
    }

    fun notifyTaskProgress(
        songId: String,
        serverId: String,
        bytesDownloaded: Long,
        totalBytes: Long,
        speedBytesPerSec: Long,
        completedCount: Int,
        totalCount: Int
    ) {
        sendEvent(
            mapOf(
                "type" to "progress",
                "songId" to songId,
                "serverId" to serverId,
                "bytesDownloaded" to bytesDownloaded,
                "totalBytes" to totalBytes,
                "speedBytesPerSec" to speedBytesPerSec,
                "completedCount" to completedCount,
                "totalCount" to totalCount
            )
        )
    }

    fun notifyTaskCompleted(task: DownloadTask, localPath: String, completedCount: Int, totalCount: Int) {
        activeTasks.remove(task.songId)
        sendEvent(
            mapOf(
                "type" to "task_completed",
                "songId" to task.songId,
                "serverId" to task.serverId,
                "localPath" to localPath,
                "completedCount" to completedCount,
                "totalCount" to totalCount
            )
        )
    }

    fun notifyTaskFailed(task: DownloadTask, error: String, completedCount: Int, totalCount: Int) {
        activeTasks.remove(task.songId)
        sendEvent(
            mapOf(
                "type" to "task_failed",
                "songId" to task.songId,
                "serverId" to task.serverId,
                "error" to error,
                "completedCount" to completedCount,
                "totalCount" to totalCount
            )
        )
    }

    fun notifyQueueCompleted(totalCompleted: Int, totalBytes: Long) {
        resetSession()
        sendEvent(
            mapOf(
                "type" to "queue_completed",
                "totalCompleted" to totalCompleted,
                "totalBytes" to totalBytes
            )
        )
    }
}
