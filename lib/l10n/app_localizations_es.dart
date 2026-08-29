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
}
