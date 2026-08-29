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
}
