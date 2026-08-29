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
}
