// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer => 'Conéctate a tu servidor de música';

  @override
  String get serverName => 'Nombre del servidor';

  @override
  String get serverNameHint => 'Mi servidor';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get serverUrlHint => 'https://musica.ejemplo.com';

  @override
  String get username => 'Usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get connect => 'Conectar';

  @override
  String get connecting => 'Conectando...';

  @override
  String get required => 'Obligatorio';

  @override
  String get enterValidUrl => 'Introduce una URL válida con http(s)://';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get navAlbums => 'Álbumes';

  @override
  String get navArtists => 'Artistas';

  @override
  String get navPlaylists => 'Listas de reproducción';

  @override
  String get navDownloads => 'Descargas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navSearch => 'Buscar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get appearance => 'Apariencia e interfaz';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get amoledBlack => 'Negro puro AMOLED';

  @override
  String get audioAndPlayback => 'Audio y reproducción';

  @override
  String get storageAndCaching => 'Almacenamiento y caché';

  @override
  String get networkAndStreaming => 'Red y streaming';

  @override
  String get aboutAndSystem => 'Acerca de y sistema';

  @override
  String get nowPlaying => 'Reproduciendo ahora';

  @override
  String get queue => 'Cola de reproducción';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get next => 'Siguiente';

  @override
  String get previous => 'Anterior';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get done => 'Hecho';

  @override
  String get retry => 'Reintentar';

  @override
  String get error => 'Error';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count álbumes',
      one: '1 álbum',
    );
    return '$_temp0';
  }

  @override
  String get untrustedCertificate =>
      'El certificado del servidor no es de confianza. Puede que sea autofirmado o que alguien esté interceptando la conexión. Continúa solo si sabes que este servidor usa un certificado autofirmado.';

  @override
  String get addWithoutVerifying => 'Añadir sin verificar';

  @override
  String get serverConnectionTitle => 'Conexión al servidor';

  @override
  String get noServerFound => 'No se ha encontrado ningún servidor';

  @override
  String get localLanBadge => 'LAN local';

  @override
  String get remoteBadge => 'Remoto';

  @override
  String activeUrl(String url) {
    return 'URL activa: $url';
  }

  @override
  String connectedWifi(String ssid) {
    return 'Red Wi-Fi conectada: $ssid';
  }

  @override
  String get statusConnectedLocal =>
      'Conectado directamente a través de la red local';

  @override
  String statusConnectedLocalOn(String ssid) {
    return 'Conectado directamente a través de la red local ($ssid)';
  }

  @override
  String get statusLocalUnreachableFallback =>
      'No se puede acceder al punto de conexión local. Se usa la URL externa.';

  @override
  String get statusLocalUnreachable =>
      'No se puede acceder al punto de conexión local';

  @override
  String get securitySection => 'Seguridad';

  @override
  String get verifyCertificates => 'Verificar certificados';

  @override
  String get verifyCertificatesSubtitle =>
      'Si lo desactivas, cualquiera en la red entre tú y el servidor podrá leer tu contraseña y tu tráfico. Solo para un servidor con certificado autofirmado.';

  @override
  String get localNetworkTarget => 'Destino de red local';

  @override
  String get localNetworkTargetDescription =>
      'Envía las peticiones directamente a tu servidor cuando estás en la red Wi-Fi de casa. Evita el hairpin NAT, el CGNAT y los límites de ancho de banda.';

  @override
  String get enableLocalEndpoint => 'Activar punto de conexión LAN local';

  @override
  String get enableLocalEndpointSubtitle =>
      'Conectar mediante la IP local en la red Wi-Fi de casa';

  @override
  String get localEndpointSettings => 'Ajustes del punto de conexión local';

  @override
  String get localHostLabel => 'IP local / nombre de host';

  @override
  String get portLabel => 'Puerto';

  @override
  String resolvedLocalUrl(String url) {
    return 'URL local resultante: $url';
  }

  @override
  String get testLocalConnection => 'Probar conexión local';

  @override
  String get testEnterHost =>
      'Introduce una dirección IP o un nombre de host válidos';

  @override
  String get testInvalidEndpoint =>
      'Configuración del punto de conexión no válida';

  @override
  String testConnected(int ms) {
    return 'Conexión correcta ($ms ms)';
  }

  @override
  String testUnreachable(String url) {
    return 'No se puede acceder a $url. Comprueba la IP del servidor, el puerto y la conexión Wi-Fi.';
  }

  @override
  String get targetWifiNetworks => 'Redes Wi-Fi de destino (SSID)';

  @override
  String get targetWifiNetworksDescription =>
      'Indica los nombres de las redes Wi-Fi en las que se puede acceder a esta IP local. Si no hay ninguna, se intenta usar el destino local en cualquier red Wi-Fi o Ethernet.';

  @override
  String addCurrentWifi(String ssid) {
    return 'Añadir Wi-Fi actual: «$ssid»';
  }

  @override
  String get refreshWifiName => 'Actualizar nombre de Wi-Fi';

  @override
  String get detectCurrentWifi => 'Detectar Wi-Fi actual';

  @override
  String get noSsidsConfigured =>
      'No hay SSID configurados. Se intentará la conexión local directa en todas las redes Wi-Fi y Ethernet.';

  @override
  String get addSsidManually => 'Añadir SSID de Wi-Fi manualmente';

  @override
  String get addSsidHint => 'p. ej., MiRedDeCasa_5G';

  @override
  String get addSsid => 'Añadir SSID';

  @override
  String get failoverAndProbing => 'Conmutación por error y sondeo';

  @override
  String get automaticFailover => 'Conmutación automática a la URL externa';

  @override
  String get automaticFailoverSubtitle =>
      'Si no se puede acceder al punto de conexión local en una red Wi-Fi coincidente, se usa la URL externa del servidor sin interrupciones';

  @override
  String get probeTimeout => 'Tiempo de espera del sondeo';

  @override
  String probeTimeoutSubtitle(int ms) {
    return 'Tiempo máximo de espera al comprobar el punto de conexión local: $ms ms';
  }

  @override
  String get serversAndConnection => 'Servidores y conexión';

  @override
  String serverOnLocalLan(String url) {
    return 'LAN local ($url)';
  }

  @override
  String get probingLocalEndpoint => 'Comprobando el punto de conexión local…';

  @override
  String get localUnreachableRemoteFallback =>
      'Local inaccesible · Se usa la remota';

  @override
  String get connectionSettings => 'Ajustes de conexión';

  @override
  String get removeServerTitle => '¿Quitar servidor?';

  @override
  String removeServerMessage(String name) {
    return '¿Quitar «$name»?';
  }

  @override
  String get remove => 'Quitar';

  @override
  String get addServer => 'Añadir servidor';

  @override
  String get localTargetDisabled =>
      'Desactivado · Se conecta mediante la URL remota';

  @override
  String localTargetActive(String url) {
    return 'Activo: $url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return 'Activo: $url en «$ssid»';
  }

  @override
  String get localTargetUnreachable => 'Inaccesible · Se usa la remota';

  @override
  String localTargetUnreachableOn(String ssid) {
    return 'Inaccesible en «$ssid» · Se usa la remota';
  }

  @override
  String localTargetAway(String url) {
    return 'Remoto: $url · Fuera de la red Wi-Fi de casa';
  }
}
