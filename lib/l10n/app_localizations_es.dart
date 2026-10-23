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
  String get amoledBlackSubtitle =>
      'Negro puro tras todos los temas oscuros, para pantallas OLED';

  @override
  String get colorTheme => 'Tema de color';

  @override
  String get colorThemeHint =>
      'Cada tema tiene una versión clara y otra oscura';

  @override
  String get themePaletteDevice => 'Dispositivo';

  @override
  String get themePaletteDeviceDescription =>
      'Tu fondo de pantalla o color de acento';

  @override
  String get themePaletteFlax => 'Flax';

  @override
  String get themePaletteFlaxDescription => 'Violeta clásico';

  @override
  String get themePaletteAlbum => 'Álbum';

  @override
  String get themePaletteAlbumDescription =>
      'Los colores siguen a la portada que suena';

  @override
  String get themePaletteEvergreen => 'Siempreverde';

  @override
  String get themePaletteEvergreenDescription =>
      'Verdes de bosque, de noche y de día';

  @override
  String get themePaletteNord => 'Nord';

  @override
  String get themePaletteNordDescription => 'Azules árticos y apagados';

  @override
  String get themePaletteCatppuccin => 'Catppuccin';

  @override
  String get themePaletteCatppuccinDescription => 'Pasteles suaves';

  @override
  String get themePaletteDracula => 'Dracula';

  @override
  String get themePaletteDraculaDescription => 'Morado y rosa sobre carbón';

  @override
  String get themePaletteGruvbox => 'Gruvbox';

  @override
  String get themePaletteGruvboxDescription =>
      'Marrones cálidos retro y naranja';

  @override
  String get themePaletteSynthwave => 'Synthwave';

  @override
  String get themePaletteSynthwaveDescription => 'Magenta neón y cian';

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

  @override
  String get shareQueue => 'Compartir la cola entre dispositivos';

  @override
  String get shareQueueOn =>
      'La cola y la posición se guardan en el servidor y tus otros dispositivos las retoman';

  @override
  String get shareQueueOff =>
      'La cola de este dispositivo nunca se guarda en el servidor ni se sustituye por la de otro dispositivo';

  @override
  String get artistEyebrow => 'ARTISTA';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get discography => 'Discografía';

  @override
  String get releaseGroupAlbums => 'Álbumes';

  @override
  String get releaseGroupEpsSingles => 'EP y sencillos';

  @override
  String get releaseGroupLive => 'En directo';

  @override
  String get releaseGroupCompilations => 'Recopilatorios';

  @override
  String get releaseGroupOther => 'Otros lanzamientos';

  @override
  String releaseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lanzamientos',
      one: '1 lanzamiento',
    );
    return '$_temp0';
  }

  @override
  String releasesDownloaded(int downloaded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$downloaded de $total lanzamientos descargados',
      one: '$downloaded de 1 lanzamiento descargado',
    );
    return '$_temp0';
  }

  @override
  String get popular => 'Populares';

  @override
  String get similarArtists => 'Artistas similares';

  @override
  String get readMore => 'Leer más';

  @override
  String get aboutEyebrow => 'ACERCA DE';

  @override
  String get viewGrid => 'Cuadrícula';

  @override
  String get viewList => 'Lista';

  @override
  String get columnTitle => 'TÍTULO';

  @override
  String get columnYear => 'AÑO';

  @override
  String get columnTracks => 'PISTAS';

  @override
  String get columnLength => 'DURACIÓN';

  @override
  String get columnRating => 'VALORACIÓN';

  @override
  String get androidAutoSettings => 'Android Auto';

  @override
  String get androidAutoTabs => 'Pestañas';

  @override
  String get androidAutoTabsHint =>
      'Elige hasta 4. El coche las muestra en este orden.';

  @override
  String get androidAutoTabRecentlyAdded => 'Añadidos recientemente';

  @override
  String get androidAutoTabFavorites => 'Favoritos';

  @override
  String get audioDevices => 'Dispositivos de audio';

  @override
  String audioDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos',
      one: '1 dispositivo',
      zero: 'Aún no hay dispositivos',
    );
    return '$_temp0';
  }

  @override
  String get audioDevicesEmpty =>
      'Aún no hay dispositivos. La salida en uso aparece aquí en cuanto Flax reproduce a través de ella.';

  @override
  String get audioDeviceConnected => 'Conectado ahora';

  @override
  String audioDeviceLastUsed(String date) {
    return 'Último uso: $date';
  }

  @override
  String eqProfileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      one: '1 perfil',
    );
    return '$_temp0';
  }

  @override
  String get audioDeviceAutoSwitch => 'Cambiar el ecualizador automáticamente';

  @override
  String get audioDeviceAutoSwitchSubtitle =>
      'Restaura el perfil predeterminado cuando este dispositivo pasa a ser la salida';

  @override
  String get audioDeviceDefaultProfile => 'Perfil predeterminado';

  @override
  String get audioDeviceRename => 'Cambiar nombre del dispositivo';

  @override
  String get deviceNameLabel => 'Nombre';

  @override
  String get audioDeviceRenameHelper =>
      'Déjalo vacío para usar el nombre del sistema';

  @override
  String get audioDeviceForget => 'Olvidar dispositivo';

  @override
  String audioDeviceForgetTitle(String name) {
    return '¿Olvidar $name?';
  }

  @override
  String get audioDeviceForgetMessage =>
      'También se eliminan sus perfiles de ecualizador. Se volverá a añadir, sin ecualización, la próxima vez que lo uses.';

  @override
  String get audioDeviceForgetInUse =>
      'No se puede olvidar el dispositivo en uso';

  @override
  String get forget => 'Olvidar';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get eqOutputDevice => 'Dispositivo de salida';

  @override
  String get eqProfile => 'Perfil';

  @override
  String eqProfileDefaultName(String name) {
    return '$name (predeterminado)';
  }

  @override
  String get eqNoProfile => 'Sin perfil';

  @override
  String get eqAutoSwitch => 'Cambio automático';

  @override
  String get eqAutoSwitchTooltip =>
      'Cambiar al perfil predeterminado de este dispositivo cuando pase a ser la salida';

  @override
  String get eqProfileActions => 'Acciones del perfil';

  @override
  String get eqProfileNew => 'Nuevo perfil…';

  @override
  String get eqProfileNewHelper =>
      'Empieza como copia de los ajustes actuales. Los cambios se guardan en el perfil en uso a medida que los haces.';

  @override
  String get eqProfileRename => 'Cambiar nombre del perfil…';

  @override
  String get eqProfileMakeDefault => 'Establecer como predeterminado';

  @override
  String get eqProfileDelete => 'Eliminar perfil';

  @override
  String eqProfileDeleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get eqProfileNameLabel => 'Nombre del perfil';

  @override
  String get eqProfileKeepOne => 'Un dispositivo conserva al menos un perfil';

  @override
  String get audioDevicesManage => 'Gestionar dispositivos';
}
