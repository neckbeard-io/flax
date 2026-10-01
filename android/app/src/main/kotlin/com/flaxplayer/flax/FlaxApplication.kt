package com.flaxplayer.flax

import android.app.Application
import android.content.ComponentName
import android.support.v4.media.MediaBrowserCompat
import androidx.annotation.Keep
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServicePlugin

class FlaxApplication : Application() {
    companion object {
        @Keep
        @JvmStatic
        val REQUIRED_DRAWABLES = intArrayOf(
            R.drawable.ic_action_favorite_filled,
            R.drawable.ic_action_favorite_border,
            R.drawable.ic_action_shuffle_on,
            R.drawable.ic_action_shuffle_off,
            R.drawable.ic_music_note,
            R.drawable.ic_favorite_heart,
            R.drawable.ic_album_collection,
            R.drawable.ic_artist_avatar,
            R.drawable.ic_offline_mode,
            R.drawable.ic_star_rating,
            R.drawable.ic_download_notification,
        )
    }

    /**
     * A connection to our own AudioService, held for the life of the process.
     *
     * audio_service destroys its Flutter engine whenever the service is
     * destroyed with no Activity attached: open flax, back out without playing,
     * and the service unbinds and takes the engine with it. The next Android
     * Auto connection then starts a fresh engine that nothing configures — no
     * car or primary-network channels — and audio_service forwards Android
     * Auto's first browse to a Dart side that has not registered for it yet.
     * Holding a binding keeps the service, and the one configured engine, alive
     * until the process itself goes.
     */
    private var audioServiceBinding: MediaBrowserCompat? = null

    override fun onCreate() {
        super.onCreate()
        try {
            val engine = AudioServicePlugin.getFlutterEngine(this)
            FlaxEngineHelper.configure(engine, this)
            FlaxMediaSessionHelper.wrapServiceListener(this)
        } catch (e: Exception) {
            android.util.Log.e("FlaxApplication", "Failed to initialize FlaxApplication engine: ${e.message}", e)
        }
        holdAudioServiceBinding()
    }

    private fun holdAudioServiceBinding() {
        try {
            audioServiceBinding = MediaBrowserCompat(
                this,
                ComponentName(this, AudioService::class.java),
                object : MediaBrowserCompat.ConnectionCallback() {},
                null,
            ).also { it.connect() }
        } catch (e: Exception) {
            android.util.Log.e("FlaxApplication", "Failed to bind AudioService: ${e.message}", e)
        }
    }
}
