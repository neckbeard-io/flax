import Cocoa
import FlutterMacOS
import MediaPlayer

class NowPlayingBridge: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.flax/now_playing", binaryMessenger: messenger)
        super.init()

        channel.setMethodCallHandler(handleMethodCall)
        setupRemoteCommands()
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateNowPlaying":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                return
            }
            updateNowPlayingInfo(args)
            result(nil)

        case "updatePlaybackState":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                return
            }
            updatePlaybackState(args)
            result(nil)

        case "clearNowPlaying":
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            if #available(macOS 10.13, *) {
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPlay", arguments: nil)
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPause", arguments: nil)
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onTogglePlayPause", arguments: nil)
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onNext", arguments: nil)
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPrevious", arguments: nil)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.channel.invokeMethod("onSeek", arguments: posEvent.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo(_ args: [String: Any]) {
        var info = [String: Any]()

        if let title = args["title"] as? String {
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = args["artist"] as? String {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = args["album"] as? String {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let duration = args["duration"] as? Double {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let position = args["position"] as? Double {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }
        if let rate = args["rate"] as? Double {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
            if #available(macOS 10.13, *) {
                MPNowPlayingInfoCenter.default().playbackState = rate > 0 ? .playing : .paused
            }
        }
        if let trackNumber = args["trackNumber"] as? Int {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }

        // Load artwork from URL if provided
        if let artUrlString = args["artUrl"] as? String,
           let artUrl = URL(string: artUrlString) {
            loadArtwork(from: artUrl) { artwork in
                if let artwork = artwork {
                    info[MPMediaItemPropertyArtwork] = artwork
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    private func updatePlaybackState(_ args: [String: Any]) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        if let position = args["position"] as? Double {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }
        if let rate = args["rate"] as? Double {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
            if #available(macOS 10.13, *) {
                MPNowPlayingInfoCenter.default().playbackState = rate > 0 ? .playing : .paused
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(from url: URL, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async { completion(artwork) }
        }.resume()
    }
}
