import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Flax'**
  String get appName;

  /// Header subtitle on setup screen
  ///
  /// In en, this message translates to:
  /// **'Connect to your music server'**
  String get connectToMusicServer;

  /// Label for server name text field
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get serverName;

  /// Hint text for server name
  ///
  /// In en, this message translates to:
  /// **'My Server'**
  String get serverNameHint;

  /// Label for server URL text field
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// Hint text for server URL
  ///
  /// In en, this message translates to:
  /// **'https://music.example.com'**
  String get serverUrlHint;

  /// Label for username text field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Label for password text field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Connect button label on setup screen
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Connecting status label on setup screen
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// Validation message when a required field is empty
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Validation message for invalid server URL
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL with http(s)://'**
  String get enterValidUrl;

  /// Language label and section header
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Option to follow system/OS default settings
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Navigation title for Albums
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get navAlbums;

  /// Navigation title for Artists
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get navArtists;

  /// Navigation title for Playlists
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// Navigation title for Downloads
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// Navigation title for Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Navigation title for Search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Title of settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section for appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance & Interface'**
  String get appearance;

  /// Theme label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Row on Settings › Theme choosing System, Light or Dark
  ///
  /// In en, this message translates to:
  /// **'Light or dark'**
  String get themeMode;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// AMOLED pure black theme option
  ///
  /// In en, this message translates to:
  /// **'AMOLED Pure Black'**
  String get amoledBlack;

  /// Subtitle of the AMOLED pure black switch in Settings
  ///
  /// In en, this message translates to:
  /// **'Pure black behind every dark theme, for OLED screens'**
  String get amoledBlackSubtitle;

  /// Title of the color theme picker in Settings
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get colorTheme;

  /// Hint under the color theme picker title in Settings
  ///
  /// In en, this message translates to:
  /// **'Every theme has a light and a dark version'**
  String get colorThemeHint;

  /// Name of the Device color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get themePaletteDevice;

  /// Description under the Device color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper or accent color'**
  String get themePaletteDeviceDescription;

  /// Name of the Flax color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Flax'**
  String get themePaletteFlax;

  /// Description under the Flax color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Classic violet'**
  String get themePaletteFlaxDescription;

  /// Name of the Album color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get themePaletteAlbum;

  /// Description under the Album color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Colors follow the playing cover'**
  String get themePaletteAlbumDescription;

  /// Name of the Evergreen color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Evergreen'**
  String get themePaletteEvergreen;

  /// Description under the Evergreen color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Forest greens, night and day'**
  String get themePaletteEvergreenDescription;

  /// Name of the Nord color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get themePaletteNord;

  /// Description under the Nord color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Arctic, muted blues'**
  String get themePaletteNordDescription;

  /// Name of the Catppuccin color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Catppuccin'**
  String get themePaletteCatppuccin;

  /// Description under the Catppuccin color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Soft pastels'**
  String get themePaletteCatppuccinDescription;

  /// Name of the Dracula color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Dracula'**
  String get themePaletteDracula;

  /// Description under the Dracula color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Purple and pink on charcoal'**
  String get themePaletteDraculaDescription;

  /// Name of the Gruvbox color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Gruvbox'**
  String get themePaletteGruvbox;

  /// Description under the Gruvbox color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Retro warm browns and orange'**
  String get themePaletteGruvboxDescription;

  /// Name of the Synthwave color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Synthwave'**
  String get themePaletteSynthwave;

  /// Description under the Synthwave color theme swatch in Settings
  ///
  /// In en, this message translates to:
  /// **'Neon magenta and cyan'**
  String get themePaletteSynthwaveDescription;

  /// Settings section for audio
  ///
  /// In en, this message translates to:
  /// **'Audio & Playback'**
  String get audioAndPlayback;

  /// Settings section for storage and caching
  ///
  /// In en, this message translates to:
  /// **'Storage & Caching'**
  String get storageAndCaching;

  /// Settings section for network and streaming
  ///
  /// In en, this message translates to:
  /// **'Network & Streaming'**
  String get networkAndStreaming;

  /// Settings section for about and system
  ///
  /// In en, this message translates to:
  /// **'About & System'**
  String get aboutAndSystem;

  /// Now playing header
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// Play queue header
  ///
  /// In en, this message translates to:
  /// **'Play Queue'**
  String get queue;

  /// Play action
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Pause action
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Next track action
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous track action
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Done button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Pluralized track count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// Pluralized album count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String albumCount(int count);

  /// Shown when adding a server fails because its TLS certificate isn't trusted
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate isn\'t trusted. It may be self-signed, or someone may be intercepting the connection. Only continue if you know this server uses a self-signed certificate.'**
  String get untrustedCertificate;

  /// Adds a server whose certificate isn't trusted, with certificate checks off for it
  ///
  /// In en, this message translates to:
  /// **'Add without verifying'**
  String get addWithoutVerifying;

  /// Title of a server's connection settings screen
  ///
  /// In en, this message translates to:
  /// **'Server Connection'**
  String get serverConnectionTitle;

  /// Connection settings opened for a server that no longer exists
  ///
  /// In en, this message translates to:
  /// **'No server found'**
  String get noServerFound;

  /// Badge: connected through the local network target
  ///
  /// In en, this message translates to:
  /// **'Local LAN'**
  String get localLanBadge;

  /// Badge: connected through the server's remote URL
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remoteBadge;

  /// The URL requests currently go to
  ///
  /// In en, this message translates to:
  /// **'Active URL: {url}'**
  String activeUrl(String url);

  /// The Wi-Fi network the device is on
  ///
  /// In en, this message translates to:
  /// **'Connected Wi-Fi: {ssid}'**
  String connectedWifi(String ssid);

  /// Status: requests go straight to the local network target
  ///
  /// In en, this message translates to:
  /// **'Connected directly via local network'**
  String get statusConnectedLocal;

  /// Status: as statusConnectedLocal, naming the Wi-Fi network
  ///
  /// In en, this message translates to:
  /// **'Connected directly via local network ({ssid})'**
  String statusConnectedLocalOn(String ssid);

  /// Status: the local target did not answer, so requests use the remote URL
  ///
  /// In en, this message translates to:
  /// **'Local endpoint unreachable. Routed via external URL.'**
  String get statusLocalUnreachableFallback;

  /// Status: the local target did not answer and failover is off
  ///
  /// In en, this message translates to:
  /// **'Local endpoint unreachable'**
  String get statusLocalUnreachable;

  /// Section title for certificate settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySection;

  /// Switch: check the server's TLS certificate
  ///
  /// In en, this message translates to:
  /// **'Verify Certificates'**
  String get verifyCertificates;

  /// What turning Verify Certificates off risks
  ///
  /// In en, this message translates to:
  /// **'Turning this off lets anyone on the network between you and the server read your password and traffic. Only for a self-signed server.'**
  String get verifyCertificatesSubtitle;

  /// Feature name: connecting to the server by its LAN address on home Wi-Fi
  ///
  /// In en, this message translates to:
  /// **'Local Network Target'**
  String get localNetworkTarget;

  /// Explains the Local Network Target
  ///
  /// In en, this message translates to:
  /// **'Route requests directly to your server on your home Wi-Fi network. Bypasses hairpin NAT, CGNAT, and bandwidth limits.'**
  String get localNetworkTargetDescription;

  /// Switch: turn the Local Network Target on
  ///
  /// In en, this message translates to:
  /// **'Enable Local LAN Endpoint'**
  String get enableLocalEndpoint;

  /// Subtitle of enableLocalEndpoint
  ///
  /// In en, this message translates to:
  /// **'Connect via local IP when on home Wi-Fi'**
  String get enableLocalEndpointSubtitle;

  /// Section title for the local target's address
  ///
  /// In en, this message translates to:
  /// **'Local Endpoint Settings'**
  String get localEndpointSettings;

  /// Field label: the server's LAN address
  ///
  /// In en, this message translates to:
  /// **'Local IP / Hostname'**
  String get localHostLabel;

  /// Field label: network port
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portLabel;

  /// The full local URL built from the fields above
  ///
  /// In en, this message translates to:
  /// **'Resolved Local URL: {url}'**
  String resolvedLocalUrl(String url);

  /// Button: try reaching the local target now
  ///
  /// In en, this message translates to:
  /// **'Test Local Connection'**
  String get testLocalConnection;

  /// Connection test: the address field is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid IP address or hostname'**
  String get testEnterHost;

  /// Connection test: the address could not be turned into a URL
  ///
  /// In en, this message translates to:
  /// **'Invalid endpoint configuration'**
  String get testInvalidEndpoint;

  /// Connection test succeeded, with the time it took
  ///
  /// In en, this message translates to:
  /// **'Connected successfully ({ms} ms)'**
  String testConnected(int ms);

  /// Connection test failed
  ///
  /// In en, this message translates to:
  /// **'Unreachable at {url}. Verify server IP, port, and Wi-Fi connection.'**
  String testUnreachable(String url);

  /// Section title: Wi-Fi networks where the local target is used
  ///
  /// In en, this message translates to:
  /// **'Target Wi-Fi Networks (SSIDs)'**
  String get targetWifiNetworks;

  /// Explains the target Wi-Fi networks list
  ///
  /// In en, this message translates to:
  /// **'Specify the Wi-Fi network names where this local IP is reachable. If empty, local target is automatically attempted on any Wi-Fi or Ethernet.'**
  String get targetWifiNetworksDescription;

  /// Chip: add the Wi-Fi network the device is on
  ///
  /// In en, this message translates to:
  /// **'Add Current Wi-Fi: \"{ssid}\"'**
  String addCurrentWifi(String ssid);

  /// Button: read the Wi-Fi name again
  ///
  /// In en, this message translates to:
  /// **'Refresh Wi-Fi Name'**
  String get refreshWifiName;

  /// Button: find out which Wi-Fi network the device is on
  ///
  /// In en, this message translates to:
  /// **'Detect Current Wi-Fi'**
  String get detectCurrentWifi;

  /// Shown when the target Wi-Fi list is empty
  ///
  /// In en, this message translates to:
  /// **'No SSIDs configured. Direct local connection will be attempted on all Wi-Fi and Ethernet networks.'**
  String get noSsidsConfigured;

  /// Field label: type a Wi-Fi network name
  ///
  /// In en, this message translates to:
  /// **'Add Wi-Fi SSID manually'**
  String get addSsidManually;

  /// Example Wi-Fi network name in the field above
  ///
  /// In en, this message translates to:
  /// **'e.g. MyHomeNetwork_5G'**
  String get addSsidHint;

  /// Tooltip: add the typed Wi-Fi network name
  ///
  /// In en, this message translates to:
  /// **'Add SSID'**
  String get addSsid;

  /// Section title: falling back to the remote URL, and probe timing
  ///
  /// In en, this message translates to:
  /// **'Failover & Probing'**
  String get failoverAndProbing;

  /// Switch: use the remote URL when the local target does not answer
  ///
  /// In en, this message translates to:
  /// **'Automatic Failover to External URL'**
  String get automaticFailover;

  /// Subtitle of automaticFailover
  ///
  /// In en, this message translates to:
  /// **'If local endpoint is unreachable on matching Wi-Fi, seamlessly fallback to external server URL'**
  String get automaticFailoverSubtitle;

  /// Setting: how long to wait for the local target
  ///
  /// In en, this message translates to:
  /// **'Probe Timeout'**
  String get probeTimeout;

  /// Subtitle of probeTimeout, with the current value
  ///
  /// In en, this message translates to:
  /// **'Maximum time to wait when verifying local endpoint: {ms} ms'**
  String probeTimeoutSubtitle(int ms);

  /// Settings section title
  ///
  /// In en, this message translates to:
  /// **'Servers & Connection'**
  String get serversAndConnection;

  /// Server list subtitle: connected through the local target at this URL
  ///
  /// In en, this message translates to:
  /// **'Local LAN ({url})'**
  String serverOnLocalLan(String url);

  /// Status: checking whether the local target answers
  ///
  /// In en, this message translates to:
  /// **'Probing local endpoint...'**
  String get probingLocalEndpoint;

  /// Server list subtitle: local target did not answer, using the remote URL
  ///
  /// In en, this message translates to:
  /// **'Local unreachable · Remote fallback'**
  String get localUnreachableRemoteFallback;

  /// Tooltip: open a server's connection settings
  ///
  /// In en, this message translates to:
  /// **'Connection Settings'**
  String get connectionSettings;

  /// Dialog title: confirm removing a server
  ///
  /// In en, this message translates to:
  /// **'Remove server?'**
  String get removeServerTitle;

  /// Dialog body: confirm removing the named server
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String removeServerMessage(String name);

  /// Button: remove the item
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Button: add another server
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// Local Network Target subtitle: turned off
  ///
  /// In en, this message translates to:
  /// **'Disabled · Connects via remote URL'**
  String get localTargetDisabled;

  /// Local Network Target subtitle: in use at this URL
  ///
  /// In en, this message translates to:
  /// **'Active: {url}'**
  String localTargetActive(String url);

  /// Local Network Target subtitle: in use at this URL on this Wi-Fi network
  ///
  /// In en, this message translates to:
  /// **'Active: {url} on \"{ssid}\"'**
  String localTargetActiveOn(String url, String ssid);

  /// Local Network Target subtitle: did not answer, using the remote URL
  ///
  /// In en, this message translates to:
  /// **'Unreachable · Routed via remote'**
  String get localTargetUnreachable;

  /// As localTargetUnreachable, naming the Wi-Fi network
  ///
  /// In en, this message translates to:
  /// **'Unreachable on \"{ssid}\" · Routed via remote'**
  String localTargetUnreachableOn(String ssid);

  /// Local Network Target subtitle: not on a target Wi-Fi network
  ///
  /// In en, this message translates to:
  /// **'Remote: {url} · Away from home Wi-Fi'**
  String localTargetAway(String url);

  /// Audio & Playback settings switch: share the play queue with other devices through the server
  ///
  /// In en, this message translates to:
  /// **'Share queue between devices'**
  String get shareQueue;

  /// Subtitle of the Share queue between devices switch while it is on
  ///
  /// In en, this message translates to:
  /// **'Queue and position are saved to the server and picked up by your other devices'**
  String get shareQueueOn;

  /// Subtitle of the Share queue between devices switch while it is off: the queue is isolated in both directions
  ///
  /// In en, this message translates to:
  /// **'This device\'s queue is never saved to the server or replaced by another device\'s'**
  String get shareQueueOff;

  /// Small capitalized label above the artist name in the desktop artist page header
  ///
  /// In en, this message translates to:
  /// **'ARTIST'**
  String get artistEyebrow;

  /// Button on the artist page that plays all of the artist's songs in random order
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// Heading above the list of an artist's releases on the desktop artist page
  ///
  /// In en, this message translates to:
  /// **'Discography'**
  String get discography;

  /// Heading for an artist's studio albums in the discography
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get releaseGroupAlbums;

  /// Heading for an artist's EPs and singles in the discography
  ///
  /// In en, this message translates to:
  /// **'EPs & Singles'**
  String get releaseGroupEpsSingles;

  /// Heading for an artist's live albums in the discography
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get releaseGroupLive;

  /// Heading for an artist's compilations in the discography
  ///
  /// In en, this message translates to:
  /// **'Compilations'**
  String get releaseGroupCompilations;

  /// Heading for an artist's soundtracks, remixes, demos and other releases in the discography
  ///
  /// In en, this message translates to:
  /// **'Other releases'**
  String get releaseGroupOther;

  /// How many releases an artist has, in the artist page header
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 release} other{{count} releases}}'**
  String releaseCount(int count);

  /// Artist page header while offline: how many of the artist's releases are downloaded
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{downloaded} of 1 release downloaded} other{{downloaded} of {total} releases downloaded}}'**
  String releasesDownloaded(int downloaded, int total);

  /// Heading for an artist's most popular songs on the artist page
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// Heading for artists similar to this one on the artist page
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get similarArtists;

  /// Link under a shortened artist biography that opens the whole text
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// Small capitalized label above the artist name in the full biography dialog
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutEyebrow;

  /// Tooltip of the button that shows an artist's releases as a grid of covers
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// Tooltip of the button that shows an artist's releases as a list
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// Column heading in the artist page's release list: the release name
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get columnTitle;

  /// Column heading in the artist page's release list: release year
  ///
  /// In en, this message translates to:
  /// **'YEAR'**
  String get columnYear;

  /// Column heading in the artist page's release list: number of tracks
  ///
  /// In en, this message translates to:
  /// **'TRACKS'**
  String get columnTracks;

  /// Column heading in the artist page's release list: total running time
  ///
  /// In en, this message translates to:
  /// **'LENGTH'**
  String get columnLength;

  /// Column heading in the artist page's release list: the release's star rating
  ///
  /// In en, this message translates to:
  /// **'RATING'**
  String get columnRating;

  /// Settings tile in Appearance & Interface, and the title of its page: Android Auto's options (phones only)
  ///
  /// In en, this message translates to:
  /// **'Android Auto'**
  String get androidAutoSettings;

  /// Section heading on the Android Auto settings page: which tabs the car shows across the top of its screen
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get androidAutoTabs;

  /// Hint under the Tabs heading on the Android Auto settings page
  ///
  /// In en, this message translates to:
  /// **'Choose up to 4. The car shows them in this order.'**
  String get androidAutoTabsHint;

  /// Android Auto tab choice: the newest albums
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get androidAutoTabRecentlyAdded;

  /// Android Auto tab choice: the albums marked as favorites (hearts)
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get androidAutoTabFavorites;

  /// Settings tile in Audio & Playback, and the title of its page: every output device flax has played through, with their EQ profiles
  ///
  /// In en, this message translates to:
  /// **'Audio Devices'**
  String get audioDevices;

  /// Subtitle of the Audio Devices settings tile when no device is in use yet: how many devices have been recorded
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No devices yet} =1{1 device} other{{count} devices}}'**
  String audioDevicesCount(int count);

  /// Shown on the Audio Devices page before any device has been recorded
  ///
  /// In en, this message translates to:
  /// **'No devices yet. The output in use is added here once flax plays through it.'**
  String get audioDevicesEmpty;

  /// Audio Devices page: shown under the device audio is going to right now
  ///
  /// In en, this message translates to:
  /// **'Connected now'**
  String get audioDeviceConnected;

  /// Audio Devices page: when a device that is not connected was last the output
  ///
  /// In en, this message translates to:
  /// **'Last used {date}'**
  String audioDeviceLastUsed(String date);

  /// Audio Devices page: how many EQ profiles a device has
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 profile} other{{count} profiles}}'**
  String eqProfileCount(int count);

  /// Audio Devices page: switch that makes a device restore its default EQ profile when it connects
  ///
  /// In en, this message translates to:
  /// **'Switch EQ automatically'**
  String get audioDeviceAutoSwitch;

  /// Audio Devices page: explains the Switch EQ automatically switch
  ///
  /// In en, this message translates to:
  /// **'Restores the default profile when this device becomes the output'**
  String get audioDeviceAutoSwitchSubtitle;

  /// Audio Devices page: heading over a device's profiles, where one is chosen as the default
  ///
  /// In en, this message translates to:
  /// **'Default profile'**
  String get audioDeviceDefaultProfile;

  /// Audio Devices page: button and dialog title for giving a device its own name
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get audioDeviceRename;

  /// Label of the name field in the Rename device dialog
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get deviceNameLabel;

  /// Helper text under the name field in the Rename device dialog
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the system\'s name'**
  String get audioDeviceRenameHelper;

  /// Audio Devices page: button that deletes a device and its EQ profiles
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get audioDeviceForget;

  /// Title of the dialog confirming Forget device
  ///
  /// In en, this message translates to:
  /// **'Forget {name}?'**
  String audioDeviceForgetTitle(String name);

  /// Body of the dialog confirming Forget device
  ///
  /// In en, this message translates to:
  /// **'Its EQ profiles are deleted too. It is added again, with no EQ, the next time it is used.'**
  String get audioDeviceForgetMessage;

  /// Tooltip on the disabled Forget device button of the device audio is going to
  ///
  /// In en, this message translates to:
  /// **'The device in use can\'t be forgotten'**
  String get audioDeviceForgetInUse;

  /// Confirm button of the Forget device dialog
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// Confirm button of a rename dialog
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Equalizer screen: caption under the name of the device audio is going to
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get eqOutputDevice;

  /// Equalizer screen: label of the menu that picks one of the output device's EQ profiles
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get eqProfile;

  /// A profile's name marked as its device's default, in the profile menu and the device list
  ///
  /// In en, this message translates to:
  /// **'{name} (default)'**
  String eqProfileDefaultName(String name);

  /// Equalizer screen: the profile menu when the equalizer is not following any of the device's profiles
  ///
  /// In en, this message translates to:
  /// **'No profile'**
  String get eqNoProfile;

  /// Equalizer screen: short label of the switch that restores the device's default profile when it connects
  ///
  /// In en, this message translates to:
  /// **'Auto-switch'**
  String get eqAutoSwitch;

  /// Tooltip of the Auto-switch switch on the Equalizer screen
  ///
  /// In en, this message translates to:
  /// **'Switch to this device\'s default profile whenever it becomes the output'**
  String get eqAutoSwitchTooltip;

  /// Tooltip of the menu button beside the profile menu on the Equalizer screen
  ///
  /// In en, this message translates to:
  /// **'Profile actions'**
  String get eqProfileActions;

  /// Profile actions menu item, and the title of its dialog: save the current EQ as a new profile of the device
  ///
  /// In en, this message translates to:
  /// **'New profile…'**
  String get eqProfileNew;

  /// Helper text in the New profile dialog
  ///
  /// In en, this message translates to:
  /// **'Starts as a copy of the current settings. Changes are saved to the profile in use as you make them.'**
  String get eqProfileNewHelper;

  /// Profile actions menu item, and the title of its dialog
  ///
  /// In en, this message translates to:
  /// **'Rename profile…'**
  String get eqProfileRename;

  /// Profile actions menu item: make the profile in use the one the device restores when it connects
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get eqProfileMakeDefault;

  /// Profile actions menu item, and the tooltip of a profile's delete button on the Audio Devices page
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get eqProfileDelete;

  /// Title of the dialog confirming a profile's deletion
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String eqProfileDeleteTitle(String name);

  /// Label of the name field in the New profile and Rename profile dialogs
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get eqProfileNameLabel;

  /// Tooltip of a disabled delete button: a device's only profile cannot be deleted
  ///
  /// In en, this message translates to:
  /// **'A device keeps at least one profile'**
  String get eqProfileKeepOne;

  /// Profile actions menu item on the Equalizer screen: opens the Audio Devices page
  ///
  /// In en, this message translates to:
  /// **'Manage devices'**
  String get audioDevicesManage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
