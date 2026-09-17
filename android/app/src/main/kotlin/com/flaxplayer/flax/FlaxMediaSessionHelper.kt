package com.flaxplayer.flax

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import androidx.media.MediaBrowserServiceCompat
import com.ryanheise.audioservice.AudioService

object FlaxMediaSessionHelper {
    private const val TAG = "FlaxMediaSession"

    fun activateMediaSession(context: Context? = null): Boolean {
        try {
            val instanceField = AudioService::class.java.getDeclaredField("instance")
            instanceField.isAccessible = true
            val service = instanceField.get(null) as? AudioService
            if (service == null) {
                Log.d(TAG, "AudioService.instance is not initialized yet")
                return false
            }

            val sessionField = AudioService::class.java.getDeclaredField("mediaSession")
            sessionField.isAccessible = true
            val mediaSession = sessionField.get(service) as? MediaSessionCompat
            if (mediaSession == null) {
                Log.d(TAG, "mediaSession is null on AudioService")
                return false
            }

            if (!mediaSession.isActive) {
                mediaSession.isActive = true
                Log.i(TAG, "MediaSessionCompat explicitly set active (isActive = true)")
            }

            // Ensure session activity PendingIntent is attached
            val contentIntentField = AudioService::class.java.getDeclaredField("contentIntent")
            contentIntentField.isAccessible = true
            var contentIntent = contentIntentField.get(null) as? PendingIntent

            if (contentIntent == null && context != null) {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "com.ryanheise.audioservice.NOTIFICATION_CLICK"
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val flags = if (Build.VERSION.SDK_INT >= 23) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                contentIntent = PendingIntent.getActivity(context, 1000, intent, flags)
                contentIntentField.set(null, contentIntent)
            }

            if (contentIntent != null) {
                mediaSession.setSessionActivity(contentIntent)
            }

            // Wrap listener if not already wrapped
            wrapServiceListener(context)

            return true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to activate MediaSession: ${e.message}", e)
            return false
        }
    }

    fun wrapServiceListener(context: Context? = null) {
        try {
            val listenerField = AudioService::class.java.getDeclaredField("listener")
            listenerField.isAccessible = true
            val currentListener = listenerField.get(null) as? AudioService.ServiceListener ?: return
            if (currentListener !is FlaxServiceListenerWrapper) {
                val wrapped = FlaxServiceListenerWrapper(currentListener, context)
                listenerField.set(null, wrapped)
                Log.i(TAG, "Successfully wrapped AudioService.listener with FlaxServiceListenerWrapper")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not wrap AudioService.listener: ${e.message}")
        }
    }
}

class FlaxServiceListenerWrapper(
    private val delegate: AudioService.ServiceListener,
    private val context: Context?
) : AudioService.ServiceListener by delegate {

    override fun onLoadChildren(
        parentMediaId: String?,
        result: MediaBrowserServiceCompat.Result<MutableList<MediaBrowserCompat.MediaItem>>?,
        options: Bundle?
    ) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onLoadChildren(parentMediaId, result, options)
    }

    override fun onPlay() {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlay()
    }

    override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromMediaId(mediaId, extras)
    }

    override fun onPlayFromSearch(query: String?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromSearch(query, extras)
    }

    override fun onPlayFromUri(uri: Uri?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromUri(uri, extras)
    }

    override fun onPrepare() {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPrepare()
    }

    override fun onPrepareFromMediaId(mediaId: String?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPrepareFromMediaId(mediaId, extras)
    }

    override fun onPrepareFromSearch(query: String?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPrepareFromSearch(query, extras)
    }

    override fun onPrepareFromUri(uri: Uri?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPrepareFromUri(uri, extras)
    }
}
