import 'package:flax/domain/models/server.dart';

/// Whether a connection for [server] to [host]:[port] accepts any certificate.
///
/// Certificates are checked everywhere except on the two hosts the user has
/// vouched for:
///
/// - the local network target, which is reached by address on the LAN and is
///   commonly self-signed;
/// - the server's remote URL, when its *Verify certificates* setting is off.
///
/// Every other host verifies: GitHub, MusicBrainz, AutoEQ, and a redirect away
/// from the server. Every Subsonic request carries the login token, so trusting
/// any certificate from any host handed it to whoever sat in the middle.
///
/// This is the one place that decides. Every `badCertificateCallback` and the
/// native downloader's per-task flag ask it.
bool acceptsAnyCertificate(Server server, String host, int port) {
  final local = server.localNetworkConfig;
  final localUrl = local.enabled ? local.localBaseUrl : null;
  if (localUrl != null && _isAt(localUrl, host, port)) return true;
  return !server.verifyCertificates && _isAt(server.baseUrl, host, port);
}

/// [acceptsAnyCertificate] for the host [url] connects to. Always false for
/// plain `http://`, which has no certificate to check.
bool acceptsAnyCertificateFor(Server server, Uri url) =>
    url.isScheme('https') && acceptsAnyCertificate(server, url.host, url.port);

bool _isAt(String baseUrl, String host, int port) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.host.toLowerCase() == host.toLowerCase() && uri.port == port;
}
