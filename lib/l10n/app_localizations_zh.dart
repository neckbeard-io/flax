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

  @override
  String get untrustedCertificate =>
      '服务器的证书不受信任。它可能是自签名证书，也可能有人正在拦截连接。只有在您确定此服务器使用自签名证书时才继续。';

  @override
  String get addWithoutVerifying => '跳过验证并添加';

  @override
  String get serverConnectionTitle => '服务器连接';

  @override
  String get noServerFound => '未找到服务器';

  @override
  String get localLanBadge => '本地局域网';

  @override
  String get remoteBadge => '远程';

  @override
  String activeUrl(String url) {
    return '当前网址：$url';
  }

  @override
  String connectedWifi(String ssid) {
    return '已连接的 Wi-Fi：$ssid';
  }

  @override
  String get statusConnectedLocal => '已通过本地网络直接连接';

  @override
  String statusConnectedLocalOn(String ssid) {
    return '已通过本地网络直接连接（$ssid）';
  }

  @override
  String get statusLocalUnreachableFallback => '无法访问本地端点。已改用外部网址。';

  @override
  String get statusLocalUnreachable => '无法访问本地端点';

  @override
  String get securitySection => '安全';

  @override
  String get verifyCertificates => '验证证书';

  @override
  String get verifyCertificatesSubtitle =>
      '关闭后，您与服务器之间网络上的任何人都可以读取您的密码和通信内容。仅适用于使用自签名证书的服务器。';

  @override
  String get localNetworkTarget => '本地网络目标';

  @override
  String get localNetworkTargetDescription =>
      '在家庭 Wi-Fi 网络中将请求直接发送到您的服务器。可绕过 NAT 回环、CGNAT 和带宽限制。';

  @override
  String get enableLocalEndpoint => '启用本地局域网端点';

  @override
  String get enableLocalEndpointSubtitle => '在家庭 Wi-Fi 中通过本地 IP 连接';

  @override
  String get localEndpointSettings => '本地端点设置';

  @override
  String get localHostLabel => '本地 IP / 主机名';

  @override
  String get portLabel => '端口';

  @override
  String resolvedLocalUrl(String url) {
    return '解析后的本地网址：$url';
  }

  @override
  String get testLocalConnection => '测试本地连接';

  @override
  String get testEnterHost => '请输入有效的 IP 地址或主机名';

  @override
  String get testInvalidEndpoint => '端点配置无效';

  @override
  String testConnected(int ms) {
    return '连接成功（$ms ms）';
  }

  @override
  String testUnreachable(String url) {
    return '无法访问 $url。请检查服务器 IP、端口和 Wi-Fi 连接。';
  }

  @override
  String get targetWifiNetworks => '目标 Wi-Fi 网络（SSID）';

  @override
  String get targetWifiNetworksDescription =>
      '指定可以访问此本地 IP 的 Wi-Fi 网络名称。若留空，将在任何 Wi-Fi 或以太网上自动尝试本地目标。';

  @override
  String addCurrentWifi(String ssid) {
    return '添加当前 Wi-Fi：“$ssid”';
  }

  @override
  String get refreshWifiName => '刷新 Wi-Fi 名称';

  @override
  String get detectCurrentWifi => '检测当前 Wi-Fi';

  @override
  String get noSsidsConfigured => '未配置 SSID。将在所有 Wi-Fi 和以太网网络上尝试直接本地连接。';

  @override
  String get addSsidManually => '手动添加 Wi-Fi SSID';

  @override
  String get addSsidHint => '例如 MyHomeNetwork_5G';

  @override
  String get addSsid => '添加 SSID';

  @override
  String get failoverAndProbing => '故障转移与探测';

  @override
  String get automaticFailover => '自动故障转移到外部网址';

  @override
  String get automaticFailoverSubtitle =>
      '如果在匹配的 Wi-Fi 上无法访问本地端点，则无缝回退到服务器的外部网址';

  @override
  String get probeTimeout => '探测超时';

  @override
  String probeTimeoutSubtitle(int ms) {
    return '验证本地端点时的最长等待时间：$ms ms';
  }

  @override
  String get serversAndConnection => '服务器与连接';

  @override
  String serverOnLocalLan(String url) {
    return '本地局域网（$url）';
  }

  @override
  String get probingLocalEndpoint => '正在探测本地端点…';

  @override
  String get localUnreachableRemoteFallback => '本地无法访问 · 已回退到远程';

  @override
  String get connectionSettings => '连接设置';

  @override
  String get removeServerTitle => '移除服务器？';

  @override
  String removeServerMessage(String name) {
    return '移除“$name”？';
  }

  @override
  String get remove => '移除';

  @override
  String get addServer => '添加服务器';

  @override
  String get localTargetDisabled => '已停用 · 通过远程网址连接';

  @override
  String localTargetActive(String url) {
    return '使用中：$url';
  }

  @override
  String localTargetActiveOn(String url, String ssid) {
    return '使用中：$url（“$ssid”）';
  }

  @override
  String get localTargetUnreachable => '无法访问 · 已通过远程连接';

  @override
  String localTargetUnreachableOn(String ssid) {
    return '在“$ssid”上无法访问 · 已通过远程连接';
  }

  @override
  String localTargetAway(String url) {
    return '远程：$url · 不在家庭 Wi-Fi 中';
  }

  @override
  String get shareQueue => '在设备间共享播放队列';

  @override
  String get shareQueueOn => '播放队列和播放位置会保存到服务器，并由您的其他设备接续';

  @override
  String get shareQueueOff => '此设备的播放队列不会保存到服务器，也不会被其他设备的队列替换';
}
