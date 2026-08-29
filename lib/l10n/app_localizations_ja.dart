// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer => '音楽サーバーに接続';

  @override
  String get serverName => 'サーバー名';

  @override
  String get serverNameHint => 'マイサーバー';

  @override
  String get serverUrl => 'サーバーURL';

  @override
  String get serverUrlHint => 'https://music.example.com';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get connect => '接続';

  @override
  String get connecting => '接続中...';

  @override
  String get required => '必須';

  @override
  String get enterValidUrl => 'http(s):// を含む有効なURLを入力してください';

  @override
  String get language => '言語';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get navAlbums => 'アルバム';

  @override
  String get navArtists => 'アーティスト';

  @override
  String get navPlaylists => 'プレイリスト';

  @override
  String get navDownloads => 'ダウンロード';

  @override
  String get navSettings => '設定';

  @override
  String get navSearch => '検索';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearance => '外観とインターフェース';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get amoledBlack => 'AMOLED ピュアブラック';

  @override
  String get audioAndPlayback => 'オーディオと再生';

  @override
  String get storageAndCaching => 'ストレージとキャッシュ';

  @override
  String get networkAndStreaming => 'ネットワークとストリーミング';

  @override
  String get aboutAndSystem => '情報とシステム';

  @override
  String get nowPlaying => '再生中';

  @override
  String get queue => '再生キュー';

  @override
  String get play => '再生';

  @override
  String get pause => '一時停止';

  @override
  String get next => '次へ';

  @override
  String get previous => '前へ';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get done => '完了';

  @override
  String get retry => '再試行';

  @override
  String get error => 'エラー';

  @override
  String trackCount(int count) {
    return '$count曲';
  }

  @override
  String albumCount(int count) {
    return '$countアルバム';
  }
}
