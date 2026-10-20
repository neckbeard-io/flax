package com.flaxplayer.flax

import android.content.Context
import android.support.v4.media.session.MediaSessionCompat
import com.ryanheise.audioservice.AudioService
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Adds the media session's commands to the playback trace Dart keeps in
 * `logs/flax-playback.log` (`lib/core/logging/playback_trace.dart`), with the
 * app that sent each one: Android Auto, the car's Bluetooth, the
 * notification. Dart is never told who sent a command. Android Auto
 * connecting and loading flax's menu are written here too, so a drive where
 * flax was missing from Android Auto's launcher says which side dropped it.
 */
object PlaybackTrace {
    private const val FILE_NAME = "flax-playback.log"

    fun record(context: Context?, event: String) {
        val service = audioService()
        write(context ?: service, "$event, from ${caller(service)}")
    }

    /**
     * A request for one of the browse roots, with the app that made it. This
     * is Android Auto loading flax's menu; a car connection with none after
     * it means Android Auto never asked for flax.
     */
    fun recordBrowse(context: Context?, parentId: String?) {
        val service = audioService()
        val browser = try {
            service?.currentBrowserInfo?.packageName
        } catch (_: Exception) {
            null
        }
        write(context ?: service, "browse $parentId, from ${browser ?: "unknown"}")
    }

    /** An event no app sent, such as a car connecting. */
    fun note(context: Context?, event: String) {
        write(context ?: audioService(), event)
    }

    private fun write(context: Context?, line: String) {
        try {
            val dir = context?.getExternalFilesDir(null) ?: return
            val logs = File(dir, "logs").apply { mkdirs() }
            val time = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            File(logs, FILE_NAME).appendText("$time $line\n")
        } catch (_: Exception) {
        }
    }

    /** The app whose command the media session is handling right now. */
    private fun caller(service: AudioService?): String = try {
        val field = AudioService::class.java.getDeclaredField("mediaSession")
        field.isAccessible = true
        val session = field.get(service) as? MediaSessionCompat
        session?.currentControllerInfo?.packageName ?: "unknown"
    } catch (_: Exception) {
        "unknown"
    }

    private fun audioService(): AudioService? = try {
        val field = AudioService::class.java.getDeclaredField("instance")
        field.isAccessible = true
        field.get(null) as? AudioService
    } catch (_: Exception) {
        null
    }
}
