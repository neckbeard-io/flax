// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Flax';

  @override
  String get connectToMusicServer => '连接到您的音乐服务器';

  @override
  String get serverName => '服务器名称';

  @override
  String get serverNameHint => '我的服务器';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get serverUrlHint => 'https://music.example.com';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get connect => '连接';

  @override
  String get connecting => '正在连接...';

  @override
  String get required => '必填';

  @override
  String get enterValidUrl => '请输入包含 http(s):// 的有效网址';

  @override
  String get language => '语言';

  @override
  String get systemDefault => '系统默认';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '艺术家';

  @override
  String get navPlaylists => '播放列表';

  @override
  String get navDownloads => '下载';

  @override
  String get navSettings => '设置';

  @override
  String get navSearch => '搜索';

  @override
  String get settingsTitle => '设置';

  @override
  String get appearance => '外观与界面';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get amoledBlack => 'AMOLED 纯黑';

  @override
  String get audioAndPlayback => '音频与播放';

  @override
  String get storageAndCaching => '存储与缓存';

  @override
  String get networkAndStreaming => '网络与串流';

  @override
  String get aboutAndSystem => '关于与系统';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get queue => '播放队列';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get next => '下一首';

  @override
  String get previous => '上一首';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get done => '完成';

  @override
  String get retry => '重试';

  @override
  String get error => '错误';

  @override
  String trackCount(int count) {
    return '$count 首曲目';
  }

  @override
  String albumCount(int count) {
    return '$count 张专辑';
  }
}
