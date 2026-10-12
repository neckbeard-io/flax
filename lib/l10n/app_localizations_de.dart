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

  @override
  String get untrustedCertificate =>
      'Das Zertifikat des Servers ist nicht vertrauenswürdig. Es ist möglicherweise selbstsigniert, oder jemand fängt die Verbindung ab. Fahren Sie nur fort, wenn Sie wissen, dass dieser Server ein selbstsigniertes Zertifikat verwendet.';

  @override
  String get addWithoutVerifying => 'Ohne Überprüfung hinzufügen';

  @override
  String get serverConnectionTitle => 'Serververbindung';

  @override
  String get noServerFound => 'Kein Server gefunden';

  @override
  String get localLanBadge => 'Lokales LAN';

  @override
  String get remoteBadge => 'Extern';

  @override
  String activeUrl(String url) {
    return 'Aktive URL: $url';
  }

  @override
  String connectedWifi(String ssid) {
    return 'Verbundenes WLAN: $ssid';
  }

  @override
  String get statusConnectedLocal =>
      'Direkt über das lokale Netzwerk verbunden';

  @override
  String statusConnectedLocalOn(String ssid) {
    return 'Direkt über das lokale Netzwerk verbunden ($ssid)';
  }

  @override
  String get statusLocalUnreachableFallback =>
      'Lokaler Endpunkt nicht erreichbar. Verbindung läuft über die externe URL.';

  @override
  String get statusLocalUnreachable => 'Lokaler Endpunkt nicht erreichbar';

  @override
  String get securitySection => 'Sicherheit';

  @override
  String get verifyCertificates => 'Zertifikate überprüfen';

  @override
  String get verifyCertificatesSubtitle =>
      'Wenn Sie dies ausschalten, kann jeder im Netzwerk zwischen Ihnen und dem Server Ihr Passwort und Ihren Datenverkehr mitlesen. Nur für einen Server mit selbstsigniertem Zertifikat.';

  @override
  String get localNetworkTarget => 'Lokales Netzwerkziel';

  @override
  String get localNetworkTargetDescription =>
      'Leitet Anfragen in Ihrem heimischen WLAN direkt an Ihren Server. Umgeht Hairpin-NAT, CGNAT und Bandbreitenlimits.';

  @override
  String get enableLocalEndpoint => 'Lokalen LAN-Endpunkt aktivieren';

  @override
  String get enableLocalEndpointSubtitle =>
      'Im heimischen WLAN über die lokale IP verbinden';

  @override
  String get localEndpointSettings => 'Einstellungen für den lokalen Endpunkt';

  @override
  String get localHostLabel => 'Lokale IP / Hostname';

  @override
  String get portLabel => 'Port';

  @override
  String resolvedLocalUrl(String url) {
    return 'Ermittelte lokale URL: $url';
  }

  @override
  String get testLocalConnection => 'Lokale Verbindung testen';

  @override
  String get testEnterHost =>
      'Bitte geben Sie eine gültige IP-Adresse oder einen Hostnamen ein';

  @override
  String get testInvalidEndpoint => 'Ungültige Endpunkt-Konfiguration';

  @override
  String testConnected(int ms) {
    return 'Verbindung erfolgreich ($ms ms)';
  }

  @override
  String testUnreachable(String url) {
    return 'Unter $url nicht erreichbar. Prüfen Sie Server-IP, Port und WLAN-Verbindung.';
  }

  @override
  String get targetWifiNetworks => 'Ziel-WLANs (SSIDs)';

  @override
  String get targetWifiNetworksDescription =>
      'Geben Sie die WLAN-Namen an, in denen diese lokale IP erreichbar ist. Ist die Liste leer, wird das lokale Ziel in jedem WLAN und per Ethernet automatisch versucht.';

  @override
  String addCurrentWifi(String ssid) {
    return 'Aktuelles WLAN hinzufügen: „$ssid“';
  }

  @override
  String get refreshWifiName => 'WLAN-Namen aktualisieren';

  @override
  String get detectCurrentWifi => 'Aktuelles WLAN erkennen';

  @override
  String get noSsidsConfigured =>
      'Keine SSIDs festgelegt. Die direkte lokale Verbindung wird in allen WLAN- und Ethernet-Netzwerken versucht.';

  @override
  String get addSsidManually => 'WLAN-SSID manuell hinzufügen';

  @override
  String get addSsidHint => 'z. B. MeinHeimnetz_5G';

  @override
  String get addSsid => 'SSID hinzufügen';

  @override
  String get failoverAndProbing => 'Ausfallsicherung & Prüfung';

  @override
  String get automaticFailover => 'Automatisch auf die externe URL ausweichen';

  @override
  String get automaticFailoverSubtitle =>
      'Ist der lokale Endpunkt im passenden WLAN nicht erreichbar, nahtlos auf die externe Server-URL ausweichen';

  @override
  String get probeTimeout => 'Prüf-Zeitlimit';

  @override
  String probeTimeoutSubtitle(int ms) {
    return 'Maximale Wartezeit beim Prüfen des lokalen Endpunkts: $ms ms';
  }

  @override
  String get serversAndConnection => 'Server & Verbindung';

  @override
  String serverOnLocalLan(String url) {
    return 'Lokales LAN ($url)';
  }

  @override
  String get probingLocalEndpoint => 'Lokaler Endpunkt wird geprüft …';

  @override
  String get localUnreachableRemoteFallback =>
      'Lokal nicht erreichbar · Ausweichen auf extern';

  @override
  String get connectionSettings => 'Verbindungseinstellungen';

  @override
  String get removeServerTitle => 'Server entfernen?';

  @override
  String removeServerMessage(String name) {
    return '„$name“ entfernen?';
  }

  @override
  String get remove => 'Entfernen';

  @override
  String get addServer => 'Server hinzufügen';

  @override
  String get localTargetDisabled =>
      'Deaktiviert · Verbindung über die externe URL';

  @override
  String localTargetActive(String url) {
    return 'Aktiv: $url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return 'Aktiv: $url im WLAN „$ssid“';
  }

  @override
  String get localTargetUnreachable =>
      'Nicht erreichbar · Verbindung über extern';

  @override
  String localTargetUnreachableOn(String ssid) {
    return 'In „$ssid“ nicht erreichbar · Verbindung über extern';
  }

  @override
  String localTargetAway(String url) {
    return 'Extern: $url · Nicht im heimischen WLAN';
  }
}
