// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer => 'Connect to your music server';

  @override
  String get serverName => 'Server Name';

  @override
  String get serverNameHint => 'My Server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://music.example.com';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting...';

  @override
  String get required => 'Required';

  @override
  String get enterValidUrl => 'Enter a valid URL with http(s)://';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSearch => 'Search';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance & Interface';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get amoledBlack => 'AMOLED Pure Black';

  @override
  String get audioAndPlayback => 'Audio & Playback';

  @override
  String get storageAndCaching => 'Storage & Caching';

  @override
  String get networkAndStreaming => 'Network & Streaming';

  @override
  String get aboutAndSystem => 'About & System';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get queue => 'Play Queue';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get untrustedCertificate =>
      'The server\'s certificate isn\'t trusted. It may be self-signed, or someone may be intercepting the connection. Only continue if you know this server uses a self-signed certificate.';

  @override
  String get addWithoutVerifying => 'Add without verifying';

  @override
  String get serverConnectionTitle => 'Server Connection';

  @override
  String get noServerFound => 'No server found';

  @override
  String get localLanBadge => 'Local LAN';

  @override
  String get remoteBadge => 'Remote';

  @override
  String activeUrl(String url) {
    return 'Active URL: $url';
  }

  @override
  String connectedWifi(String ssid) {
    return 'Connected Wi-Fi: $ssid';
  }

  @override
  String get statusConnectedLocal => 'Connected directly via local network';

  @override
  String statusConnectedLocalOn(String ssid) {
    return 'Connected directly via local network ($ssid)';
  }

  @override
  String get statusLocalUnreachableFallback =>
      'Local endpoint unreachable. Routed via external URL.';

  @override
  String get statusLocalUnreachable => 'Local endpoint unreachable';

  @override
  String get securitySection => 'Security';

  @override
  String get verifyCertificates => 'Verify Certificates';

  @override
  String get verifyCertificatesSubtitle =>
      'Turning this off lets anyone on the network between you and the server read your password and traffic. Only for a self-signed server.';

  @override
  String get localNetworkTarget => 'Local Network Target';

  @override
  String get localNetworkTargetDescription =>
      'Route requests directly to your server on your home Wi-Fi network. Bypasses hairpin NAT, CGNAT, and bandwidth limits.';

  @override
  String get enableLocalEndpoint => 'Enable Local LAN Endpoint';

  @override
  String get enableLocalEndpointSubtitle =>
      'Connect via local IP when on home Wi-Fi';

  @override
  String get localEndpointSettings => 'Local Endpoint Settings';

  @override
  String get localHostLabel => 'Local IP / Hostname';

  @override
  String get portLabel => 'Port';

  @override
  String resolvedLocalUrl(String url) {
    return 'Resolved Local URL: $url';
  }

  @override
  String get testLocalConnection => 'Test Local Connection';

  @override
  String get testEnterHost => 'Please enter a valid IP address or hostname';

  @override
  String get testInvalidEndpoint => 'Invalid endpoint configuration';

  @override
  String testConnected(int ms) {
    return 'Connected successfully ($ms ms)';
  }

  @override
  String testUnreachable(String url) {
    return 'Unreachable at $url. Verify server IP, port, and Wi-Fi connection.';
  }

  @override
  String get targetWifiNetworks => 'Target Wi-Fi Networks (SSIDs)';

  @override
  String get targetWifiNetworksDescription =>
      'Specify the Wi-Fi network names where this local IP is reachable. If empty, local target is automatically attempted on any Wi-Fi or Ethernet.';

  @override
  String addCurrentWifi(String ssid) {
    return 'Add Current Wi-Fi: \"$ssid\"';
  }

  @override
  String get refreshWifiName => 'Refresh Wi-Fi Name';

  @override
  String get detectCurrentWifi => 'Detect Current Wi-Fi';

  @override
  String get noSsidsConfigured =>
      'No SSIDs configured. Direct local connection will be attempted on all Wi-Fi and Ethernet networks.';

  @override
  String get addSsidManually => 'Add Wi-Fi SSID manually';

  @override
  String get addSsidHint => 'e.g. MyHomeNetwork_5G';

  @override
  String get addSsid => 'Add SSID';

  @override
  String get failoverAndProbing => 'Failover & Probing';

  @override
  String get automaticFailover => 'Automatic Failover to External URL';

  @override
  String get automaticFailoverSubtitle =>
      'If local endpoint is unreachable on matching Wi-Fi, seamlessly fallback to external server URL';

  @override
  String get probeTimeout => 'Probe Timeout';

  @override
  String probeTimeoutSubtitle(int ms) {
    return 'Maximum time to wait when verifying local endpoint: $ms ms';
  }

  @override
  String get serversAndConnection => 'Servers & Connection';

  @override
  String serverOnLocalLan(String url) {
    return 'Local LAN ($url)';
  }

  @override
  String get probingLocalEndpoint => 'Probing local endpoint...';

  @override
  String get localUnreachableRemoteFallback =>
      'Local unreachable · Remote fallback';

  @override
  String get connectionSettings => 'Connection Settings';

  @override
  String get removeServerTitle => 'Remove server?';

  @override
  String removeServerMessage(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get addServer => 'Add Server';

  @override
  String get localTargetDisabled => 'Disabled · Connects via remote URL';

  @override
  String localTargetActive(String url) {
    return 'Active: $url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return 'Active: $url on \"$ssid\"';
  }

  @override
  String get localTargetUnreachable => 'Unreachable · Routed via remote';

  @override
  String localTargetUnreachableOn(String ssid) {
    return 'Unreachable on \"$ssid\" · Routed via remote';
  }

  @override
  String localTargetAway(String url) {
    return 'Remote: $url · Away from home Wi-Fi';
  }
}
