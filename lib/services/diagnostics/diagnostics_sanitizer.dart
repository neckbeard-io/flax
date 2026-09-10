/// Automated scrubber and redaction pipeline for diagnostic reports and logs.
///
/// Strips authentication secrets, passwords, tokens, private server addresses,
/// user home directories, and hardware identifiers before export.
class DiagnosticsSanitizer {
  DiagnosticsSanitizer._();

  // Regex patterns for URL parameters (Subsonic auth & credentials)
  static final _urlParamRedactions = [
    RegExp(r'(?<=[?&]|^)(token)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(salt)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(password)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(t)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(s)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(p)=([^&\s]+)', caseSensitive: false),
    RegExp(r'(?<=[?&]|^)(u)=([^&\s]+)', caseSensitive: false),
  ];

  // Regex for JSON secrets
  static final _jsonRedactions = [
    RegExp(
      r'"(token|tokenHash|password|salt)"\s*:\s*"[^"]*"',
      caseSensitive: false,
    ),
    RegExp(r'"(username)"\s*:\s*"[^"]*"', caseSensitive: false),
  ];

  // Authorization headers
  static final _authHeaderPattern = RegExp(
    r'(Bearer|Basic)\s+[a-zA-Z0-9_\-\.\+/=]+',
    caseSensitive: false,
  );

  // User home directories
  static final _userPathPattern = RegExp(
    r'(/Users/[^/\s\\]+)|(/home/[^/\s\\]+)|([A-Za-z]:\\[Uu]sers\\[^/\\\s]+)|([A-Za-z]:/[Uu]sers/[^/\s]+)',
    caseSensitive: false,
  );

  // General server URLs (preserves well-known public open-source project domains)
  static final _generalUrlPattern = RegExp(
    r'(https?://)([a-zA-Z0-9.\-_]+(?::\d+)?)',
    caseSensitive: false,
  );

  // IPv4 addresses (4 octets)
  static final _ipv4Pattern = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b');

  // Hardware and system UUIDs
  static final _uuidPattern = RegExp(
    r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
  );

  /// Sanitizes [input], redacting all sensitive credentials, URLs, and file paths.
  ///
  /// Optionally passes [serverUrl] and [username] to scrub any literal mentions of the
  /// active user or server address that might appear in logs or text.
  static String sanitize(String input, {String? serverUrl, String? username}) {
    if (input.isEmpty) return input;
    var result = input;

    // 1. Redact specific server URL / host if provided
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      final trimmed = serverUrl.trim();
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasAuthority) {
        result = result.replaceAll(
          trimmed,
          '${uri.scheme}://[REDACTED_SERVER]',
        );
        result = result.replaceAll(uri.authority, '[REDACTED_SERVER]');
        if (uri.host.isNotEmpty &&
            uri.host != 'localhost' &&
            uri.host != '127.0.0.1') {
          result = result.replaceAll(uri.host, '[REDACTED_SERVER]');
        }
      }
    }

    // 2. Redact query parameters in URLs
    for (final reg in _urlParamRedactions) {
      result = result.replaceAllMapped(reg, (m) {
        final key = m.group(1);
        if (key != null && key.toLowerCase() == 'u') {
          return '$key=[REDACTED_USER]';
        }
        return '$key=[REDACTED]';
      });
    }

    // 3. Redact JSON fields
    for (final reg in _jsonRedactions) {
      result = result.replaceAllMapped(reg, (m) {
        final key = m.group(1);
        if (key != null && key.toLowerCase() == 'username') {
          return '"$key": "[REDACTED_USER]"';
        }
        return '"$key": "[REDACTED]"';
      });
    }

    // 4. Redact auth headers
    result = result.replaceAll(_authHeaderPattern, '[REDACTED_AUTH]');

    // 5. Redact general URLs (except public GitHub / Navidrome / Subsonic domains)
    result = result.replaceAllMapped(_generalUrlPattern, (m) {
      final scheme = m.group(1)!;
      final host = m.group(2)!;
      final lower = host.toLowerCase();
      if (lower.contains('github.com') ||
          lower.contains('navidrome.org') ||
          lower.contains('opensubsonic.netlify.app') ||
          lower.contains('subsonic.org')) {
        return '$scheme$host';
      }
      return '$scheme[REDACTED_SERVER]';
    });

    // 6. Redact standalone IP addresses
    result = result.replaceAllMapped(_ipv4Pattern, (m) {
      return '[REDACTED_IP]';
    });

    // 7. Redact file system user home directories
    result = result.replaceAll(_userPathPattern, '~');

    // 8. Redact active username if explicitly provided
    if (username != null && username.trim().length >= 3) {
      final escapedUser = RegExp.escape(username.trim());
      result = result.replaceAll(
        RegExp(escapedUser, caseSensitive: false),
        '[REDACTED_USER]',
      );
    }

    // 9. Redact hardware UUIDs
    result = result.replaceAll(_uuidPattern, '[REDACTED_UUID]');

    return result;
  }
}
