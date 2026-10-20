package com.flaxplayer.flax

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.media.MediaBrowserServiceCompat
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.MediaButton

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

            // Ensure playbackState is non-NONE so Android Auto Coolwalk card and rail show up
            val currentPlaybackState = mediaSession.controller.playbackState
            if (currentPlaybackState == null || currentPlaybackState.state == PlaybackStateCompat.STATE_NONE) {
                val stateBuilder = PlaybackStateCompat.Builder()
                    .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1.0f)
                    .setActions(
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_STOP or
                        PlaybackStateCompat.ACTION_SEEK_TO or
                        PlaybackStateCompat.ACTION_PREPARE
                    )
                mediaSession.setPlaybackState(stateBuilder.build())
                Log.i(TAG, "MediaSessionCompat initialized with STATE_PAUSED (was NONE/null)")
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

            installMediaKeyCallback(service, mediaSession)

            return true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to activate MediaSession: ${e.message}", e)
            return false
        }
    }

    /**
     * Swaps audio_service's session callback for [FlaxMediaSessionCallback], so
     * the Play and Pause keys stop toggling. Once per session: a recreated
     * service brings a new session and callback, and gets it again.
     */
    private fun installMediaKeyCallback(service: AudioService, mediaSession: MediaSessionCompat) {
        try {
            val field = AudioService::class.java.getDeclaredField("mediaSessionCallback")
            field.isAccessible = true
            if (field.get(service) is FlaxMediaSessionCallback) return
            val callback = FlaxMediaSessionCallback(service)
            mediaSession.setCallback(callback)
            // audio_service also calls the callback directly, for Android
            // Auto's play-item requests.
            field.set(service, callback)
            Log.i(TAG, "Media session callback replaced with FlaxMediaSessionCallback")
        } catch (e: Exception) {
            Log.w(TAG, "Could not replace the media session callback: ${e.message}")
        }
    }

    /**
     * What Android Auto needs to list flax and show its card, for the playback
     * trace: whether Android still resolves flax's browse service, and the
     * media session's state.
     */
    fun describeForCar(context: Context): String {
        val browse = try {
            val pm = context.packageManager
            val intent = Intent(MediaBrowserServiceCompat.SERVICE_INTERFACE).setPackage(context.packageName)
            val services = if (Build.VERSION.SDK_INT >= 33) {
                pm.queryIntentServices(intent, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentServices(intent, 0)
            }
            if (services.isEmpty()) "browse service NOT found" else "browse service found"
        } catch (e: Exception) {
            "browse service unknown (${e.javaClass.simpleName})"
        }
        val session = try {
            val instanceField = AudioService::class.java.getDeclaredField("instance")
            instanceField.isAccessible = true
            val service = instanceField.get(null) as? AudioService
            val sessionField = AudioService::class.java.getDeclaredField("mediaSession")
            sessionField.isAccessible = true
            val mediaSession = service?.let { sessionField.get(it) as? MediaSessionCompat }
            when {
                service == null -> "audio service not running"
                mediaSession == null -> "no media session"
                else -> {
                    val state = mediaSession.controller.playbackState?.state
                    "session ${if (mediaSession.isActive) "active" else "inactive"}, ${stateName(state)}"
                }
            }
        } catch (e: Exception) {
            "session unknown (${e.javaClass.simpleName})"
        }
        return "$browse, $session"
    }

    private fun stateName(state: Int?): String = when (state) {
        null, PlaybackStateCompat.STATE_NONE -> "no state"
        PlaybackStateCompat.STATE_STOPPED -> "stopped"
        PlaybackStateCompat.STATE_PAUSED -> "paused"
        PlaybackStateCompat.STATE_PLAYING -> "playing"
        PlaybackStateCompat.STATE_BUFFERING -> "buffering"
        PlaybackStateCompat.STATE_CONNECTING -> "connecting"
        PlaybackStateCompat.STATE_ERROR -> "error"
        else -> "state $state"
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
        if (parentMediaId == "root" || parentMediaId == "recent") {
            PlaybackTrace.recordBrowse(context, parentMediaId)
        }
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onLoadChildren(parentMediaId, result, options)
    }

    override fun onPlay() {
        PlaybackTrace.record(context, "media session play")
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlay()
    }

    override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
        PlaybackTrace.record(context, "media session play $mediaId")
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromMediaId(mediaId, extras)
    }

    override fun onPlayFromSearch(query: String?, extras: Bundle?) {
        PlaybackTrace.record(context, "media session play from search")
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromSearch(query, extras)
    }

    override fun onPause() {
        PlaybackTrace.record(context, "media session pause")
        delegate.onPause()
    }

    override fun onStop() {
        PlaybackTrace.record(context, "media session stop")
        delegate.onStop()
    }

    // A headset or car play/pause button, which toggles. The Play and Pause
    // keys never get here: FlaxMediaSessionCallback sends them to onPlay and
    // onPause.
    override fun onClick(mediaButton: MediaButton?) {
        PlaybackTrace.record(context, "media button ${mediaButton?.name}")
        delegate.onClick(mediaButton)
    }

    override fun onSkipToNext() {
        PlaybackTrace.record(context, "media session next")
        delegate.onSkipToNext()
    }

    override fun onPlayFromUri(uri: Uri?, extras: Bundle?) {
        FlaxMediaSessionHelper.activateMediaSession(context)
        delegate.onPlayFromUri(uri, extras)
    }

    override fun onPrepare() {
        PlaybackTrace.record(context, "media session prepare")
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
