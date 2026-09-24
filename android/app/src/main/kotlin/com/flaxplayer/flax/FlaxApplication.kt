package com.flaxplayer.flax

import android.app.Application
import androidx.annotation.Keep
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

    override fun onCreate() {
        super.onCreate()
        try {
            val engine = AudioServicePlugin.getFlutterEngine(this)
            FlaxEngineHelper.configure(engine, this)
            FlaxMediaSessionHelper.wrapServiceListener(this)
        } catch (e: Exception) {
            android.util.Log.e("FlaxApplication", "Failed to initialize FlaxApplication engine: ${e.message}", e)
        }
    }
}
