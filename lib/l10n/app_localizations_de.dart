// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer => 'Mit Musikserver verbinden';

  @override
  String get serverName => 'Servername';

  @override
  String get serverNameHint => 'Mein Server';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String get serverUrlHint => 'https://musik.beispiel.de';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get connect => 'Verbinden';

  @override
  String get connecting => 'Verbinde...';

  @override
  String get required => 'Erforderlich';

  @override
  String get enterValidUrl => 'Geben Sie eine gültige URL mit http(s):// ein';

  @override
  String get language => 'Sprache';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get navAlbums => 'Alben';

  @override
  String get navArtists => 'Künstler';

  @override
  String get navPlaylists => 'Wiedergabelisten';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navSearch => 'Suchen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get appearance => 'Erscheinungsbild & Oberfläche';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get amoledBlack => 'AMOLED Tiefschwarz';

  @override
  String get audioAndPlayback => 'Audio & Wiedergabe';

  @override
  String get storageAndCaching => 'Speicher & Cache';

  @override
  String get networkAndStreaming => 'Netzwerk & Streaming';

  @override
  String get aboutAndSystem => 'Über & System';

  @override
  String get nowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get queue => 'Warteschlange';

  @override
  String get play => 'Wiedergabe';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Weiter';

  @override
  String get previous => 'Zurück';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get done => 'Fertig';

  @override
  String get retry => 'Wiederholen';

  @override
  String get error => 'Fehler';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben',
      one: '1 Album',
    );
    return '$_temp0';
  }
}
