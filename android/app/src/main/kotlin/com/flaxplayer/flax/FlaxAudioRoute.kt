package com.flaxplayer.flax

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Reports which device media plays through, and each change to it, so flax
 * can switch to that device's EQ profile (#69).
 *
 * Sends `{id, name, type}`. [AudioDeviceInfo.getId] changes every time a
 * device reconnects, so the id is built from the type and the address — a
 * Bluetooth device's MAC — or the product name where there is no address.
 */
object FlaxAudioRoute {
    private const val CHANNEL = "com.flax/audio_route"
    private const val EVENTS = "com.flax/audio_route_events"

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private var sink: EventChannel.EventSink? = null
    private var callback: AudioDeviceCallback? = null
    private var lastSent: Map<String, Any?>? = null

    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentOutput" -> result.success(currentOutput(appContext))
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    startListening(appContext)
                    lastSent = currentOutput(appContext)
                    events?.success(lastSent)
                }

                override fun onCancel(arguments: Any?) {
                    stopListening(appContext)
                    sink = null
                }
            }
        )
    }

    private fun startListening(context: Context) {
        if (callback != null) return
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) = changed(context)
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) = changed(context)
        }
        callback = cb
        audioManager.registerAudioDeviceCallback(cb, mainHandler)
    }

    private fun stopListening(context: Context) {
        val cb = callback ?: return
        context.getSystemService(AudioManager::class.java)?.unregisterAudioDeviceCallback(cb)
        callback = null
    }

    private fun changed(context: Context) {
        val current = currentOutput(context)
        // A Bluetooth connection announces its profiles one at a time.
        if (current == lastSent) return
        lastSent = current
        sink?.success(current)
    }

    fun currentOutput(context: Context): Map<String, Any?>? {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return null
        val outputs = try {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter { it.isSink }
        } catch (_: Exception) {
            return null
        }
        val device = routedForMedia(audioManager, outputs)
            ?: outputs.filter { priority(it.type) >= 0 }.maxByOrNull { priority(it.type) }
            ?: return null
        return describe(device)
    }

    /**
     * Where Android says media goes. Android 13 and later answer directly;
     * earlier versions fall back to the device a user would expect to win.
     */
    private fun routedForMedia(audioManager: AudioManager, outputs: List<AudioDeviceInfo>): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        return try {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            audioManager.getAudioDevicesForAttributes(attributes).firstOrNull { routed ->
                outputs.any { it.id == routed.id }
            }
        } catch (_: Exception) {
            null
        }
    }

    /** Higher wins. Negative: never a media output (earpiece, telephony). */
    private fun priority(type: Int): Int = when (type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> 90
        AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER -> 85
        AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_DEVICE -> 80
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET -> 70
        AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC -> 60
        AudioDeviceInfo.TYPE_LINE_DIGITAL, AudioDeviceInfo.TYPE_LINE_ANALOG -> 50
        AudioDeviceInfo.TYPE_BUS -> 40
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> 10
        else -> -1
    }

    private fun describe(device: AudioDeviceInfo): Map<String, Any?> {
        val kind = when (device.type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE -> "usb_dac"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "headphone_jack"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtin_speaker"
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_LINE_DIGITAL -> "hdmi_optical"
            else -> "other"
        }
        val product = device.productName?.toString()?.trim().orEmpty()
        // A USB address names the port, not the device, so the product does.
        val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && kind == "bluetooth") {
            device.address.orEmpty()
        } else {
            ""
        }
        val key = when {
            address.isNotEmpty() -> address
            kind == "builtin_speaker" || kind == "headphone_jack" -> ""
            else -> product
        }
        val id = if (key.isEmpty()) "android/$kind" else "android/$kind/$key"
        // The phone's own outputs report the phone's model as their name.
        val name = product.ifEmpty { Build.MODEL }
        return mapOf("id" to id, "name" to name, "type" to kind)
    }
}
