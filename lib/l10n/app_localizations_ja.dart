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

  @override
  String get untrustedCertificate =>
      'サーバーの証明書は信頼されていません。自己署名証明書であるか、誰かが通信を傍受している可能性があります。このサーバーが自己署名証明書を使用していることが分かっている場合にのみ続行してください。';

  @override
  String get addWithoutVerifying => '検証せずに追加';

  @override
  String get serverConnectionTitle => 'サーバー接続';

  @override
  String get noServerFound => 'サーバーが見つかりません';

  @override
  String get localLanBadge => 'ローカルLAN';

  @override
  String get remoteBadge => 'リモート';

  @override
  String activeUrl(String url) {
    return '使用中のURL: $url';
  }

  @override
  String connectedWifi(String ssid) {
    return '接続中のWi-Fi: $ssid';
  }

  @override
  String get statusConnectedLocal => 'ローカルネットワーク経由で直接接続しています';

  @override
  String statusConnectedLocalOn(String ssid) {
    return 'ローカルネットワーク経由で直接接続しています（$ssid）';
  }

  @override
  String get statusLocalUnreachableFallback =>
      'ローカルエンドポイントに接続できません。外部URL経由で接続しています。';

  @override
  String get statusLocalUnreachable => 'ローカルエンドポイントに接続できません';

  @override
  String get securitySection => 'セキュリティ';

  @override
  String get verifyCertificates => '証明書を検証';

  @override
  String get verifyCertificatesSubtitle =>
      'オフにすると、あなたとサーバーの間のネットワーク上の誰もが、パスワードと通信内容を読み取れるようになります。自己署名証明書のサーバーの場合にのみオフにしてください。';

  @override
  String get localNetworkTarget => 'ローカルネットワーク接続先';

  @override
  String get localNetworkTargetDescription =>
      '自宅のWi-Fiでは、リクエストをサーバーに直接送ります。ヘアピンNAT、CGNAT、帯域制限を回避できます。';

  @override
  String get enableLocalEndpoint => 'ローカルLANエンドポイントを有効にする';

  @override
  String get enableLocalEndpointSubtitle => '自宅のWi-FiではローカルIPで接続します';

  @override
  String get localEndpointSettings => 'ローカルエンドポイントの設定';

  @override
  String get localHostLabel => 'ローカルIP / ホスト名';

  @override
  String get portLabel => 'ポート';

  @override
  String resolvedLocalUrl(String url) {
    return '解決されたローカルURL: $url';
  }

  @override
  String get testLocalConnection => 'ローカル接続をテスト';

  @override
  String get testEnterHost => '有効なIPアドレスまたはホスト名を入力してください';

  @override
  String get testInvalidEndpoint => 'エンドポイントの設定が無効です';

  @override
  String testConnected(int ms) {
    return '接続に成功しました（$ms ms）';
  }

  @override
  String testUnreachable(String url) {
    return '$url に接続できません。サーバーのIP、ポート、Wi-Fi接続を確認してください。';
  }

  @override
  String get targetWifiNetworks => '対象のWi-Fiネットワーク（SSID）';

  @override
  String get targetWifiNetworksDescription =>
      'このローカルIPに接続できるWi-Fiネットワーク名を指定します。空の場合は、どのWi-Fiやイーサネットでも自動的にローカル接続先を試します。';

  @override
  String addCurrentWifi(String ssid) {
    return '現在のWi-Fiを追加: 「$ssid」';
  }

  @override
  String get refreshWifiName => 'Wi-Fi名を更新';

  @override
  String get detectCurrentWifi => '現在のWi-Fiを検出';

  @override
  String get noSsidsConfigured =>
      'SSIDが設定されていません。すべてのWi-Fiとイーサネットでローカルへの直接接続を試みます。';

  @override
  String get addSsidManually => 'Wi-Fi SSIDを手動で追加';

  @override
  String get addSsidHint => '例: MyHomeNetwork_5G';

  @override
  String get addSsid => 'SSIDを追加';

  @override
  String get failoverAndProbing => 'フェイルオーバーと接続確認';

  @override
  String get automaticFailover => '外部URLへ自動でフェイルオーバー';

  @override
  String get automaticFailoverSubtitle =>
      '一致するWi-Fiでローカルエンドポイントに接続できない場合、サーバーの外部URLにシームレスに切り替えます';

  @override
  String get probeTimeout => '接続確認のタイムアウト';

  @override
  String probeTimeoutSubtitle(int ms) {
    return 'ローカルエンドポイント確認時の最大待ち時間: $ms ms';
  }

  @override
  String get serversAndConnection => 'サーバーと接続';

  @override
  String serverOnLocalLan(String url) {
    return 'ローカルLAN（$url）';
  }

  @override
  String get probingLocalEndpoint => 'ローカルエンドポイントを確認中…';

  @override
  String get localUnreachableRemoteFallback => 'ローカル接続不可・リモートに切り替え';

  @override
  String get connectionSettings => '接続設定';

  @override
  String get removeServerTitle => 'サーバーを削除しますか？';

  @override
  String removeServerMessage(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get remove => '削除';

  @override
  String get addServer => 'サーバーを追加';

  @override
  String get localTargetDisabled => '無効・リモートURLで接続';

  @override
  String localTargetActive(String url) {
    return '使用中: $url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return '使用中: $url（「$ssid」）';
  }

  @override
  String get localTargetUnreachable => '接続不可・リモート経由';

  @override
  String localTargetUnreachableOn(String ssid) {
    return '「$ssid」では接続不可・リモート経由';
  }

  @override
  String localTargetAway(String url) {
    return 'リモート: $url・自宅のWi-Fi外';
  }
}
