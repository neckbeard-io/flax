package com.flaxplayer.flax

import android.app.Application
import com.ryanheise.audioservice.AudioServicePlugin

class FlaxApplication : Application() {
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
