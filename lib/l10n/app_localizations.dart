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
