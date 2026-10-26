import CoreAudio
import FlutterMacOS

/// Reports which device the system default output is, and each change to it,
/// so flax can switch to that device's EQ profile (#69).
///
/// Sends `{id, name, type}`. The id is `coreaudio/<UID>`, which is the name mpv
/// gives the same device, so choosing it under Audio Output keeps its profiles.
class AudioRouteBridge: NSObject, FlutterStreamHandler {
    private let channel: FlutterMethodChannel
    private let events: FlutterEventChannel
    private var sink: FlutterEventSink?

    /// The device whose data source (speaker or headphone jack) is watched.
    private var watchedDevice = AudioObjectID(kAudioObjectUnknown)
    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var sourceListener: AudioObjectPropertyListenerBlock?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.flax/audio_route", binaryMessenger: messenger)
        events = FlutterEventChannel(name: "com.flax/audio_route_events", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "currentOutput":
                result(self?.currentOutput())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        events.setStreamHandler(self)
    }

    deinit {
        stopListening()
    }

    // MARK: FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        sink = eventSink
        startListening()
        eventSink(currentOutput())
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopListening()
        sink = nil
        return nil
    }

    // MARK: Listening

    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var dataSourceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDataSource,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private func startListening() {
        guard defaultListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.routeChanged()
        }
        defaultListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, DispatchQueue.main, listener)
        watchDataSource(of: defaultOutputDevice())
    }

    private func stopListening() {
        if let listener = defaultListener {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, DispatchQueue.main, listener)
            defaultListener = nil
        }
        watchDataSource(of: AudioObjectID(kAudioObjectUnknown))
    }

    /// Plugging headphones into an Intel Mac's jack changes the built-in
    /// device's data source rather than the default device, so that is watched
    /// too.
    private func watchDataSource(of device: AudioObjectID) {
        if let listener = sourceListener, watchedDevice != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(watchedDevice, &dataSourceAddress, DispatchQueue.main, listener)
        }
        sourceListener = nil
        watchedDevice = device
        guard device != kAudioObjectUnknown,
              AudioObjectHasProperty(device, &dataSourceAddress) else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.routeChanged()
        }
        sourceListener = listener
        AudioObjectAddPropertyListenerBlock(device, &dataSourceAddress, DispatchQueue.main, listener)
    }

    private func routeChanged() {
        let device = defaultOutputDevice()
        if device != watchedDevice {
            watchDataSource(of: device)
        }
        sink?(currentOutput())
    }

    // MARK: Reading the device

    private func defaultOutputDevice() -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, 0, nil, &size, &device)
        return status == noErr ? device : AudioObjectID(kAudioObjectUnknown)
    }

    private func currentOutput() -> [String: Any]? {
        let device = defaultOutputDevice()
        guard device != kAudioObjectUnknown,
              let uid = stringProperty(device, kAudioDevicePropertyDeviceUID) else { return nil }
        let name = stringProperty(device, kAudioObjectPropertyName) ?? uid
        let transport = uint32Property(device, kAudioDevicePropertyTransportType, scope: kAudioObjectPropertyScopeGlobal)

        var id = "coreaudio/\(uid)"
        var type = deviceType(transport)
        // The built-in output on an Intel Mac is one device whether the speaker
        // or the headphone jack is playing; only its data source tells them
        // apart. Apple silicon lists the jack as a device of its own.
        if transport == kAudioDeviceTransportTypeBuiltIn,
           let source = uint32Property(device, kAudioDevicePropertyDataSource, scope: kAudioDevicePropertyScopeOutput),
           source == fourCC("hdpn") {
            id += "#headphones"
            type = "headphone_jack"
        }
        return ["id": id, "name": name, "type": type]
    }

    private func deviceType(_ transport: UInt32?) -> String {
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "bluetooth"
        case kAudioDeviceTransportTypeUSB:
            return "usb_dac"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "hdmi_optical"
        case kAudioDeviceTransportTypeBuiltIn:
            return "builtin_speaker"
        default:
            return "other"
        }
    }

    private func stringProperty(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr, let string = value?.takeRetainedValue() else { return nil }
        return string as String
    }

    private func uint32Property(
        _ device: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func fourCC(_ code: String) -> UInt32 {
        code.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
