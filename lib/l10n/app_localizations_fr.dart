// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer =>
      'Connectez-vous à votre serveur de musique';

  @override
  String get serverName => 'Nom du serveur';

  @override
  String get serverNameHint => 'Mon serveur';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get serverUrlHint => 'https://musique.exemple.com';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get connect => 'Se connecter';

  @override
  String get connecting => 'Connexion...';

  @override
  String get required => 'Requis';

  @override
  String get enterValidUrl => 'Entrez une URL valide avec http(s)://';

  @override
  String get language => 'Langue';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artistes';

  @override
  String get navPlaylists => 'Listes de lecture';

  @override
  String get navDownloads => 'Téléchargements';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get appearance => 'Apparence & Interface';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get amoledBlack => 'Noir pur AMOLED';

  @override
  String get amoledBlackSubtitle =>
      'Noir pur derrière chaque thème sombre, pour les écrans OLED';

  @override
  String get colorTheme => 'Thème de couleur';

  @override
  String get colorThemeHint =>
      'Chaque thème existe en version claire et sombre';

  @override
  String get themePaletteDevice => 'Appareil';

  @override
  String get themePaletteDeviceDescription =>
      'Votre fond d’écran ou votre couleur d’accent';

  @override
  String get themePaletteFlax => 'Flax';

  @override
  String get themePaletteFlaxDescription => 'Violet classique';

  @override
  String get themePaletteAlbum => 'Album';

  @override
  String get themePaletteAlbumDescription =>
      'Les couleurs suivent la pochette en cours';

  @override
  String get themePaletteEvergreen => 'Sempervirent';

  @override
  String get themePaletteEvergreenDescription =>
      'Verts de forêt, de nuit comme de jour';

  @override
  String get themePaletteNord => 'Nord';

  @override
  String get themePaletteNordDescription => 'Bleus arctiques et feutrés';

  @override
  String get themePaletteCatppuccin => 'Catppuccin';

  @override
  String get themePaletteCatppuccinDescription => 'Pastels doux';

  @override
  String get themePaletteDracula => 'Dracula';

  @override
  String get themePaletteDraculaDescription => 'Violet et rose sur anthracite';

  @override
  String get themePaletteGruvbox => 'Gruvbox';

  @override
  String get themePaletteGruvboxDescription => 'Bruns chauds rétro et orange';

  @override
  String get themePaletteSynthwave => 'Synthwave';

  @override
  String get themePaletteSynthwaveDescription => 'Magenta néon et cyan';

  @override
  String get audioAndPlayback => 'Audio & Lecture';

  @override
  String get storageAndCaching => 'Stockage & Cache';

  @override
  String get networkAndStreaming => 'Réseau & Streaming';

  @override
  String get aboutAndSystem => 'À propos & Système';

  @override
  String get nowPlaying => 'Lecture en cours';

  @override
  String get queue => 'File d\'attente';

  @override
  String get play => 'Lecture';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Suivant';

  @override
  String get previous => 'Précédent';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get done => 'Terminé';

  @override
  String get retry => 'Réessayer';

  @override
  String get error => 'Erreur';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
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
      'Le certificat du serveur n\'est pas fiable. Il est peut-être auto-signé, ou quelqu\'un intercepte peut-être la connexion. Ne continuez que si vous savez que ce serveur utilise un certificat auto-signé.';

  @override
  String get addWithoutVerifying => 'Ajouter sans vérifier';

  @override
  String get serverConnectionTitle => 'Connexion au serveur';

  @override
  String get noServerFound => 'Aucun serveur trouvé';

  @override
  String get localLanBadge => 'LAN local';

  @override
  String get remoteBadge => 'Distant';

  @override
  String activeUrl(String url) {
    return 'URL active : $url';
  }

  @override
  String connectedWifi(String ssid) {
    return 'Wi-Fi connecté : $ssid';
  }

  @override
  String get statusConnectedLocal => 'Connecté directement via le réseau local';

  @override
  String statusConnectedLocalOn(String ssid) {
    return 'Connecté directement via le réseau local ($ssid)';
  }

  @override
  String get statusLocalUnreachableFallback =>
      'Point d\'accès local injoignable. Connexion via l\'URL externe.';

  @override
  String get statusLocalUnreachable => 'Point d\'accès local injoignable';

  @override
  String get securitySection => 'Sécurité';

  @override
  String get verifyCertificates => 'Vérifier les certificats';

  @override
  String get verifyCertificatesSubtitle =>
      'Si vous le désactivez, toute personne sur le réseau entre vous et le serveur peut lire votre mot de passe et votre trafic. Uniquement pour un serveur au certificat auto-signé.';

  @override
  String get localNetworkTarget => 'Cible réseau local';

  @override
  String get localNetworkTargetDescription =>
      'Envoie les requêtes directement à votre serveur sur le Wi-Fi de votre domicile. Contourne le hairpin NAT, le CGNAT et les limites de bande passante.';

  @override
  String get enableLocalEndpoint => 'Activer le point d\'accès LAN local';

  @override
  String get enableLocalEndpointSubtitle =>
      'Se connecter via l\'IP locale sur le Wi-Fi du domicile';

  @override
  String get localEndpointSettings => 'Paramètres du point d\'accès local';

  @override
  String get localHostLabel => 'IP locale / nom d\'hôte';

  @override
  String get portLabel => 'Port';

  @override
  String resolvedLocalUrl(String url) {
    return 'URL locale résolue : $url';
  }

  @override
  String get testLocalConnection => 'Tester la connexion locale';

  @override
  String get testEnterHost => 'Entrez une adresse IP ou un nom d\'hôte valide';

  @override
  String get testInvalidEndpoint => 'Configuration du point d\'accès invalide';

  @override
  String testConnected(int ms) {
    return 'Connexion réussie ($ms ms)';
  }

  @override
  String testUnreachable(String url) {
    return 'Injoignable à $url. Vérifiez l\'IP du serveur, le port et la connexion Wi-Fi.';
  }

  @override
  String get targetWifiNetworks => 'Réseaux Wi-Fi cibles (SSID)';

  @override
  String get targetWifiNetworksDescription =>
      'Indiquez les noms des réseaux Wi-Fi sur lesquels cette IP locale est joignable. Si la liste est vide, la cible locale est essayée automatiquement sur tout réseau Wi-Fi ou Ethernet.';

  @override
  String addCurrentWifi(String ssid) {
    return 'Ajouter le Wi-Fi actuel : « $ssid »';
  }

  @override
  String get refreshWifiName => 'Actualiser le nom du Wi-Fi';

  @override
  String get detectCurrentWifi => 'Détecter le Wi-Fi actuel';

  @override
  String get noSsidsConfigured =>
      'Aucun SSID configuré. La connexion locale directe sera tentée sur tous les réseaux Wi-Fi et Ethernet.';

  @override
  String get addSsidManually => 'Ajouter un SSID Wi-Fi manuellement';

  @override
  String get addSsidHint => 'ex. MonReseauMaison_5G';

  @override
  String get addSsid => 'Ajouter le SSID';

  @override
  String get failoverAndProbing => 'Basculement et vérification';

  @override
  String get automaticFailover =>
      'Basculer automatiquement vers l\'URL externe';

  @override
  String get automaticFailoverSubtitle =>
      'Si le point d\'accès local est injoignable sur un Wi-Fi correspondant, basculer de façon transparente vers l\'URL externe du serveur';

  @override
  String get probeTimeout => 'Délai de vérification';

  @override
  String probeTimeoutSubtitle(int ms) {
    return 'Temps d\'attente maximal pour vérifier le point d\'accès local : $ms ms';
  }

  @override
  String get serversAndConnection => 'Serveurs et connexion';

  @override
  String serverOnLocalLan(String url) {
    return 'LAN local ($url)';
  }

  @override
  String get probingLocalEndpoint => 'Vérification du point d\'accès local…';

  @override
  String get localUnreachableRemoteFallback =>
      'Local injoignable · Repli sur l\'URL distante';

  @override
  String get connectionSettings => 'Paramètres de connexion';

  @override
  String get removeServerTitle => 'Supprimer le serveur ?';

  @override
  String removeServerMessage(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get remove => 'Supprimer';

  @override
  String get addServer => 'Ajouter un serveur';

  @override
  String get localTargetDisabled => 'Désactivé · Connexion via l\'URL distante';

  @override
  String localTargetActive(String url) {
    return 'Actif : $url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return 'Actif : $url sur « $ssid »';
  }

  @override
  String get localTargetUnreachable =>
      'Injoignable · Connexion via l\'URL distante';

  @override
  String localTargetUnreachableOn(String ssid) {
    return 'Injoignable sur « $ssid » · Connexion via l\'URL distante';
  }

  @override
  String localTargetAway(String url) {
    return 'Distant : $url · Hors du Wi-Fi du domicile';
  }

  @override
  String get shareQueue => 'Partager la file d\'attente entre appareils';

  @override
  String get shareQueueOn =>
      'La file d\'attente et la position sont enregistrées sur le serveur et reprises par vos autres appareils';

  @override
  String get shareQueueOff =>
      'La file d\'attente de cet appareil n\'est jamais enregistrée sur le serveur ni remplacée par celle d\'un autre appareil';

  @override
  String get artistEyebrow => 'ARTISTE';

  @override
  String get shuffle => 'Lecture aléatoire';

  @override
  String get discography => 'Discographie';

  @override
  String get releaseGroupAlbums => 'Albums';

  @override
  String get releaseGroupEpsSingles => 'EP et singles';

  @override
  String get releaseGroupLive => 'Live';

  @override
  String get releaseGroupCompilations => 'Compilations';

  @override
  String get releaseGroupOther => 'Autres sorties';

  @override
  String releaseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sorties',
      one: '1 sortie',
    );
    return '$_temp0';
  }

  @override
  String releasesDownloaded(int downloaded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$downloaded sur $total sorties téléchargées',
      one: '$downloaded sur 1 sortie téléchargée',
    );
    return '$_temp0';
  }

  @override
  String get popular => 'Populaires';

  @override
  String get similarArtists => 'Artistes similaires';

  @override
  String get readMore => 'Lire la suite';

  @override
  String get aboutEyebrow => 'À PROPOS';

  @override
  String get viewGrid => 'Grille';

  @override
  String get viewList => 'Liste';

  @override
  String get columnTitle => 'TITRE';

  @override
  String get columnYear => 'ANNÉE';

  @override
  String get columnTracks => 'MORCEAUX';

  @override
  String get columnLength => 'DURÉE';

  @override
  String get columnRating => 'NOTE';

  @override
  String get androidAutoSettings => 'Android Auto';

  @override
  String get androidAutoTabs => 'Onglets';

  @override
  String get androidAutoTabsHint =>
      'Choisissez-en jusqu\'à 4. La voiture les affiche dans cet ordre.';

  @override
  String get androidAutoTabRecentlyAdded => 'Ajouts récents';

  @override
  String get androidAutoTabFavorites => 'Favoris';
}
