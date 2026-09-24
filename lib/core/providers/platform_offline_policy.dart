import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Defines platform-specific rules for connectivity, auto-offline transitions,
/// and sleep/wake network reassociation.
abstract class PlatformOfflinePolicy {
  const PlatformOfflinePolicy();

  /// Resolves the policy matching the current runtime operating system.
  factory PlatformOfflinePolicy.current() {
    if (Platform.isAndroid) return const AndroidOfflinePolicy();
    if (Platform.isIOS) return const IosOfflinePolicy();
    if (Platform.isMacOS) return const MacOsOfflinePolicy();
    if (Platform.isWindows) return const WindowsOfflinePolicy();
    return const LinuxOfflinePolicy();
  }

  /// Whether automotive / Android Auto / CarPlay connection triggers apply.
  bool get supportsCarConnection;

  /// Whether cellular-specific auto-offline settings apply.
  bool get supportsCellular;

  /// Consecutive reachability failures required before declaring server unreachable.
  int get reachabilityFailureThreshold;

  /// Delay after wake / resume before probing reachability, allowing interfaces to associate.
  Duration get wakeProbeDelay;

  /// Whether a reachability failure automatically forces offline library mode.
  bool get autoOfflineOnReachabilityFailure;

  /// Whether total loss of physical network interfaces automatically forces offline library mode.
  bool get autoOfflineOnNoNetwork;

  /// Whether server reachability status is persisted to disk across app sessions.
  bool get persistReachabilityState;
}

/// Mobile Android policy: aggressive offline handling for cellular and vehicle safety.
class AndroidOfflinePolicy extends PlatformOfflinePolicy {
  const AndroidOfflinePolicy();

  @override
  bool get supportsCarConnection => true;

  @override
  bool get supportsCellular => true;

  @override
  int get reachabilityFailureThreshold => 1;

  @override
  Duration get wakeProbeDelay => Duration.zero;

  @override
  bool get autoOfflineOnReachabilityFailure => true;

  @override
  bool get autoOfflineOnNoNetwork => true;

  @override
  bool get persistReachabilityState => true;
}

/// Mobile iOS policy: aggressive offline handling for cellular and vehicle safety.
class IosOfflinePolicy extends PlatformOfflinePolicy {
  const IosOfflinePolicy();

  @override
  bool get supportsCarConnection => true;

  @override
  bool get supportsCellular => true;

  @override
  int get reachabilityFailureThreshold => 1;

  @override
  Duration get wakeProbeDelay => Duration.zero;

  @override
  bool get autoOfflineOnReachabilityFailure => true;

  @override
  bool get autoOfflineOnNoNetwork => true;

  @override
  bool get persistReachabilityState => true;
}

/// Desktop macOS policy: resilient sleep/wake handling for laptops without false offlining.
class MacOsOfflinePolicy extends PlatformOfflinePolicy {
  const MacOsOfflinePolicy();

  @override
  bool get supportsCarConnection => false;

  @override
  bool get supportsCellular => false;

  @override
  int get reachabilityFailureThreshold => 3;

  @override
  Duration get wakeProbeDelay => const Duration(seconds: 4);

  @override
  bool get autoOfflineOnReachabilityFailure => false;

  @override
  bool get autoOfflineOnNoNetwork => false;

  @override
  bool get persistReachabilityState => false;
}

/// Desktop Windows policy: resilient modern standby / hibernation handling.
class WindowsOfflinePolicy extends PlatformOfflinePolicy {
  const WindowsOfflinePolicy();

  @override
  bool get supportsCarConnection => false;

  @override
  bool get supportsCellular => false;

  @override
  int get reachabilityFailureThreshold => 3;

  @override
  Duration get wakeProbeDelay => const Duration(seconds: 4);

  @override
  bool get autoOfflineOnReachabilityFailure => false;

  @override
  bool get autoOfflineOnNoNetwork => false;

  @override
  bool get persistReachabilityState => false;
}

/// Desktop Linux policy.
class LinuxOfflinePolicy extends PlatformOfflinePolicy {
  const LinuxOfflinePolicy();

  @override
  bool get supportsCarConnection => false;

  @override
  bool get supportsCellular => false;

  @override
  int get reachabilityFailureThreshold => 3;

  @override
  Duration get wakeProbeDelay => const Duration(seconds: 2);

  @override
  bool get autoOfflineOnReachabilityFailure => false;

  @override
  bool get autoOfflineOnNoNetwork => false;

  @override
  bool get persistReachabilityState => false;
}

/// Riverpod provider supplying the current platform's offline policy.
final platformOfflinePolicyProvider = Provider<PlatformOfflinePolicy>((ref) {
  return PlatformOfflinePolicy.current();
});
