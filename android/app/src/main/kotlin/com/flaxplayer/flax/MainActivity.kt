package com.flaxplayer.flax

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity(), FlaxEngineHelper.PermissionHandler {

    override fun requestNotificationPermission() {
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

    override fun requestLocationPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                1002
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FlaxEngineHelper.permissionHandler = this

        // Fallback: If onFlutterUiDisplayed has not fired within 500ms (e.g. cached engine attaching),
        // ensure theme switches so user is not stuck on splash screen.
        window.decorView.postDelayed({
            if (!isFinishing && !isDestroyed) {
                setTheme(R.style.NormalTheme)
                window.setBackgroundDrawableResource(android.R.color.transparent)
                FlaxEngineHelper.requestWarmUpFrame()
            }
        }, 500)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlaxEngineHelper.permissionHandler = this
        FlaxEngineHelper.configure(flutterEngine, this)
        FlaxMediaSessionHelper.wrapServiceListener(applicationContext)
        FlaxMediaSessionHelper.activateMediaSession(applicationContext)
    }

    override fun onResume() {
        super.onResume()
        FlaxMediaSessionHelper.activateMediaSession(applicationContext)
        FlaxEngineHelper.requestWarmUpFrame()

        // If the Flutter UI is already displayed, ensure the launch theme is dismissed immediately
        if (flutterEngine?.renderer?.isDisplayingFlutterUi == true) {
            onFlutterUiDisplayed()
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        setTheme(R.style.NormalTheme)
        window.setBackgroundDrawableResource(android.R.color.transparent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        FlaxMediaSessionHelper.activateMediaSession(applicationContext)
    }

    override fun onDestroy() {
        if (FlaxEngineHelper.permissionHandler == this) {
            FlaxEngineHelper.permissionHandler = null
        }
        super.onDestroy()
    }
}
