package com.flaxplayer.flax;

import android.content.Intent;
import android.view.KeyEvent;

import com.ryanheise.audioservice.AudioService;

/**
 * audio_service's media session callback, except that the Play and Pause keys
 * do what they say.
 *
 * audio_service hands KEYCODE_MEDIA_PLAY and KEYCODE_MEDIA_PAUSE to Dart as
 * the same "media" button as KEYCODE_MEDIA_PLAY_PAUSE, which toggles. A Play
 * key sent while playing therefore paused, and the pair of keys Android Auto
 * sends a few seconds after connecting cancelled out: music it had just asked
 * for stayed paused. Only the play/pause and headset keys toggle now.
 *
 * Java, not Kotlin: the parent is a non-static inner class of AudioService,
 * and only Java can name the outer instance in the super call.
 */
public class FlaxMediaSessionCallback extends AudioService.MediaSessionCallback {
    private final AudioService service;

    public FlaxMediaSessionCallback(AudioService service) {
        service.super();
        this.service = service;
    }

    @Override
    public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
        @SuppressWarnings("deprecation")
        final KeyEvent event = mediaButtonEvent == null
                ? null
                : (KeyEvent) mediaButtonEvent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
        if (event == null) return super.onMediaButtonEvent(mediaButtonEvent);

        final int keyCode = event.getKeyCode();
        final boolean down = event.getAction() == KeyEvent.ACTION_DOWN;
        // audio_service sends its own notification's Play and Pause as these
        // two keys; they are transport commands, traced as such by the
        // listener, not keys from outside.
        if (keyCode != AudioService.KEYCODE_BYPASS_PLAY
                && keyCode != AudioService.KEYCODE_BYPASS_PAUSE) {
            PlaybackTrace.INSTANCE.record(
                    service,
                    "media key " + KeyEvent.keyCodeToString(keyCode) + (down ? " down" : " up"));
        }

        switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_PLAY:
                if (down) onPlay();
                return true;
            case KeyEvent.KEYCODE_MEDIA_PAUSE:
                if (down) onPause();
                return true;
            default:
                return super.onMediaButtonEvent(mediaButtonEvent);
        }
    }
}
