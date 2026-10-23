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
  String get amoledBlackSubtitle =>
      'Reines Schwarz hinter jedem dunklen Design, für OLED-Bildschirme';

  @override
  String get colorTheme => 'Farbdesign';

  @override
  String get colorThemeHint =>
      'Jedes Design gibt es in einer hellen und einer dunklen Version';

  @override
  String get themePaletteDevice => 'Gerät';

  @override
  String get themePaletteDeviceDescription =>
      'Ihr Hintergrundbild oder Ihre Akzentfarbe';

  @override
  String get themePaletteFlax => 'Flax';

  @override
  String get themePaletteFlaxDescription => 'Klassisches Violett';

  @override
  String get themePaletteAlbum => 'Album';

  @override
  String get themePaletteAlbumDescription =>
      'Farben folgen dem aktuellen Cover';

  @override
  String get themePaletteEvergreen => 'Immergrün';

  @override
  String get themePaletteEvergreenDescription =>
      'Waldgrün, bei Nacht und bei Tag';

  @override
  String get themePaletteNord => 'Nord';

  @override
  String get themePaletteNordDescription => 'Arktische, gedämpfte Blautöne';

  @override
  String get themePaletteCatppuccin => 'Catppuccin';

  @override
  String get themePaletteCatppuccinDescription => 'Sanfte Pastelltöne';

  @override
  String get themePaletteDracula => 'Dracula';

  @override
  String get themePaletteDraculaDescription => 'Lila und Pink auf Anthrazit';

  @override
  String get themePaletteGruvbox => 'Gruvbox';

  @override
  String get themePaletteGruvboxDescription =>
      'Warme Retro-Brauntöne und Orange';

  @override
  String get themePaletteSynthwave => 'Synthwave';

  @override
  String get themePaletteSynthwaveDescription => 'Neon-Magenta und Cyan';

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

  @override
  String get shareQueue => 'Warteschlange zwischen Geräten teilen';

  @override
  String get shareQueueOn =>
      'Warteschlange und Position werden auf dem Server gespeichert und von Ihren anderen Geräten übernommen';

  @override
  String get shareQueueOff =>
      'Die Warteschlange dieses Geräts wird nie auf dem Server gespeichert oder durch die eines anderen Geräts ersetzt';

  @override
  String get artistEyebrow => 'KÜNSTLER';

  @override
  String get shuffle => 'Zufallswiedergabe';

  @override
  String get discography => 'Diskografie';

  @override
  String get releaseGroupAlbums => 'Alben';

  @override
  String get releaseGroupEpsSingles => 'EPs & Singles';

  @override
  String get releaseGroupLive => 'Live';

  @override
  String get releaseGroupCompilations => 'Kompilationen';

  @override
  String get releaseGroupOther => 'Weitere Veröffentlichungen';

  @override
  String releaseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Veröffentlichungen',
      one: '1 Veröffentlichung',
    );
    return '$_temp0';
  }

  @override
  String releasesDownloaded(int downloaded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$downloaded von $total Veröffentlichungen heruntergeladen',
      one: '$downloaded von 1 Veröffentlichung heruntergeladen',
    );
    return '$_temp0';
  }

  @override
  String get popular => 'Beliebt';

  @override
  String get similarArtists => 'Ähnliche Künstler';

  @override
  String get readMore => 'Mehr lesen';

  @override
  String get aboutEyebrow => 'ÜBER';

  @override
  String get viewGrid => 'Raster';

  @override
  String get viewList => 'Liste';

  @override
  String get columnTitle => 'TITEL';

  @override
  String get columnYear => 'JAHR';

  @override
  String get columnTracks => 'STÜCKE';

  @override
  String get columnLength => 'DAUER';

  @override
  String get columnRating => 'BEWERTUNG';

  @override
  String get androidAutoSettings => 'Android Auto';

  @override
  String get androidAutoTabs => 'Tabs';

  @override
  String get androidAutoTabsHint =>
      'Wählen Sie bis zu 4 aus. Das Auto zeigt sie in dieser Reihenfolge.';

  @override
  String get androidAutoTabRecentlyAdded => 'Zuletzt hinzugefügt';

  @override
  String get androidAutoTabFavorites => 'Favoriten';

  @override
  String get audioDevices => 'Audiogeräte';

  @override
  String audioDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte',
      one: '1 Gerät',
      zero: 'Noch keine Geräte',
    );
    return '$_temp0';
  }

  @override
  String get audioDevicesEmpty =>
      'Noch keine Geräte. Das verwendete Ausgabegerät erscheint hier, sobald Flax darüber abspielt.';

  @override
  String get audioDeviceConnected => 'Jetzt verbunden';

  @override
  String audioDeviceLastUsed(String date) {
    return 'Zuletzt verwendet: $date';
  }

  @override
  String eqProfileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Profile',
      one: '1 Profil',
    );
    return '$_temp0';
  }

  @override
  String get audioDeviceAutoSwitch => 'EQ automatisch wechseln';

  @override
  String get audioDeviceAutoSwitchSubtitle =>
      'Stellt das Standardprofil wieder her, wenn dieses Gerät zur Ausgabe wird';

  @override
  String get audioDeviceDefaultProfile => 'Standardprofil';

  @override
  String get audioDeviceRename => 'Gerät umbenennen';

  @override
  String get deviceNameLabel => 'Name';

  @override
  String get audioDeviceRenameHelper =>
      'Leer lassen, um den Systemnamen zu verwenden';

  @override
  String get audioDeviceForget => 'Gerät vergessen';

  @override
  String audioDeviceForgetTitle(String name) {
    return '$name vergessen?';
  }

  @override
  String get audioDeviceForgetMessage =>
      'Seine EQ-Profile werden ebenfalls gelöscht. Bei der nächsten Verwendung wird es ohne EQ neu hinzugefügt.';

  @override
  String get audioDeviceForgetInUse =>
      'Das verwendete Gerät kann nicht vergessen werden';

  @override
  String get forget => 'Vergessen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get eqOutputDevice => 'Ausgabegerät';

  @override
  String get eqProfile => 'Profil';

  @override
  String eqProfileDefaultName(String name) {
    return '$name (Standard)';
  }

  @override
  String get eqNoProfile => 'Kein Profil';

  @override
  String get eqAutoSwitch => 'Automatisch wechseln';

  @override
  String get eqAutoSwitchTooltip =>
      'Zum Standardprofil dieses Geräts wechseln, sobald es zur Ausgabe wird';

  @override
  String get eqProfileActions => 'Profilaktionen';

  @override
  String get eqProfileNew => 'Neues Profil …';

  @override
  String get eqProfileNewHelper =>
      'Beginnt als Kopie der aktuellen Einstellungen. Änderungen werden sofort im verwendeten Profil gespeichert.';

  @override
  String get eqProfileRename => 'Profil umbenennen …';

  @override
  String get eqProfileMakeDefault => 'Als Standard festlegen';

  @override
  String get eqProfileDelete => 'Profil löschen';

  @override
  String eqProfileDeleteTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get eqProfileNameLabel => 'Profilname';

  @override
  String get eqProfileKeepOne => 'Ein Gerät behält mindestens ein Profil';

  @override
  String get audioDevicesManage => 'Geräte verwalten';
}
