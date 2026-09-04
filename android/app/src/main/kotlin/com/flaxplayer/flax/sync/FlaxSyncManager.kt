package com.flaxplayer.flax.sync

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object FlaxSyncManager {
    private const val PERIODIC_WORK_NAME = "flax_nightly_sync"
    private const val IMMEDIATE_WORK_NAME = "flax_immediate_sync"

    fun schedulePeriodicSync(
        context: Context,
        intervalHours: Long = 24,
        requiresCharging: Boolean = true,
        wifiOnly: Boolean = true
    ) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
            .setRequiresCharging(requiresCharging)
            .setRequiresBatteryNotLow(true)
            .build()

        val syncRequest = PeriodicWorkRequestBuilder<FlaxSyncWorker>(
            intervalHours, TimeUnit.HOURS
        )
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            syncRequest
        )
    }

    fun cancelPeriodicSync(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(PERIODIC_WORK_NAME)
    }

    fun triggerImmediateSync(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequestBuilder<FlaxSyncWorker>()
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            IMMEDIATE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    fun getSyncStatus(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastTimestamp = prefs.getLong("flutter.last_background_sync_timestamp", 0L)

        var isScheduled = false
        try {
            val workInfos = WorkManager.getInstance(context)
                .getWorkInfosForUniqueWork(PERIODIC_WORK_NAME)
                .get()
            isScheduled = workInfos.any {
                it.state == WorkInfo.State.ENQUEUED || it.state == WorkInfo.State.RUNNING
            }
        } catch (_: Exception) {}

        return mapOf(
            "isScheduled" to isScheduled,
            "lastSyncTimestamp" to if (lastTimestamp > 0) lastTimestamp else null
        )
    }
}
