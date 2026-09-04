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

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun enqueue(context: Context, tasks: List<DownloadTask>, concurrency: Int = 4) {
        maxConcurrency = concurrency.coerceIn(1, 16)
        tasks.forEach { canceledSongIds.remove(it.songId) }
        pendingQueue.addAll(tasks)
        totalEnqueuedTasks.addAndGet(tasks.size)

        val intent = Intent(context, FlaxDownloadService::class.java).apply {
            action = FlaxDownloadService.ACTION_START_DOWNLOADS
        }
        try {
            context.startForegroundService(intent)
        } catch (e: Exception) {
            context.startService(intent)
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

    fun cancelAll(context: Context) {
        pendingQueue.clear()
        activeTasks.clear()
        canceledSongIds.clear()
        totalEnqueuedTasks.set(0)
        completedSessionTasks.set(0)
        totalSessionBytes.set(0)

        val intent = Intent(context, FlaxDownloadService::class.java).apply {
            action = FlaxDownloadService.ACTION_CANCEL_ALL
        }
        context.startService(intent)
        sendEvent(mapOf("type" to "canceled"))
    }

    fun resetSession() {
        activeTasks.clear()
        canceledSongIds.clear()
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
