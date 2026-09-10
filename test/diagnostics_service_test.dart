import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/diagnostics/diagnostics_sanitizer.dart';
import 'package:flax/services/diagnostics/diagnostics_service.dart';

void main() {
  group('DiagnosticsSanitizer', () {
    test('redacts Subsonic query parameters in URLs', () {
      const raw =
          'GET https://myserver.lan:4533/rest/ping?u=admin&t=deadbeef1234&s=salt5678&p=plainpass&token=secrettoken&password=mypassword&v=1.16.1&c=flax&f=json';
      final sanitized = DiagnosticsSanitizer.sanitize(raw);

      expect(sanitized, isNot(contains('admin')));
      expect(sanitized, isNot(contains('deadbeef1234')));
      expect(sanitized, isNot(contains('salt5678')));
      expect(sanitized, isNot(contains('plainpass')));
      expect(sanitized, isNot(contains('secrettoken')));
      expect(sanitized, isNot(contains('mypassword')));

      expect(sanitized, contains('u=[REDACTED_USER]'));
      expect(sanitized, contains('t=[REDACTED]'));
      expect(sanitized, contains('s=[REDACTED]'));
      expect(sanitized, contains('p=[REDACTED]'));
      expect(sanitized, contains('token=[REDACTED]'));
      expect(sanitized, contains('password=[REDACTED]'));
      expect(sanitized, contains('v=1.16.1'));
      expect(sanitized, contains('c=flax'));
    });

    test('redacts JSON credentials and auth headers', () {
      const raw = '''
{
  "username": "superadmin",
  "token": "tok123",
  "tokenHash": "hash456",
  "salt": "salt789",
  "password": "secretpassword"
}
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
Authorization: Basic YWRtaW46cGFzc3dvcmQ=
''';
      final sanitized = DiagnosticsSanitizer.sanitize(raw);

      expect(sanitized, isNot(contains('superadmin')));
      expect(sanitized, isNot(contains('tok123')));
      expect(sanitized, isNot(contains('hash456')));
      expect(sanitized, isNot(contains('salt789')));
      expect(sanitized, isNot(contains('secretpassword')));
      expect(
        sanitized,
        isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
      );
      expect(sanitized, isNot(contains('YWRtaW46cGFzc3dvcmQ=')));

      expect(sanitized, contains('"username": "[REDACTED_USER]"'));
      expect(sanitized, contains('"token": "[REDACTED]"'));
      expect(sanitized, contains('"tokenHash": "[REDACTED]"'));
      expect(sanitized, contains('"salt": "[REDACTED]"'));
      expect(sanitized, contains('"password": "[REDACTED]"'));
      expect(sanitized, contains('[REDACTED_AUTH]'));
    });

    test(
      'redacts server URLs and IP addresses while preserving public repositories',
      () {
        const raw = '''
Connecting to https://nas.homelab.local:4533/rest
Resolved LAN IP 192.168.1.55:4533
Reporting bug to https://github.com/neckbeard-io/flax/issues/new?title=Bug
Documentation at https://www.navidrome.org/docs/api
Specification at http://opensubsonic.netlify.app/docs
''';
        final sanitized = DiagnosticsSanitizer.sanitize(
          raw,
          serverUrl: 'https://nas.homelab.local:4533',
        );

        expect(sanitized, isNot(contains('nas.homelab.local')));
        expect(sanitized, isNot(contains('192.168.1.55')));

        expect(sanitized, contains('https://[REDACTED_SERVER]/rest'));
        expect(sanitized, contains('[REDACTED_IP]'));

        // Public open source references must be preserved
        expect(
          sanitized,
          contains('https://github.com/neckbeard-io/flax/issues/new?title=Bug'),
        );
        expect(sanitized, contains('https://www.navidrome.org/docs/api'));
        expect(sanitized, contains('http://opensubsonic.netlify.app/docs'));
      },
    );

    test('redacts user home directory paths on macOS, Linux, and Windows', () {
      const macPath =
          '/Users/alice/Library/Application Support/com.flax/flax.db';
      const linuxPath = '/home/bob/.config/flax/settings.json';
      const winPath = r'C:\Users\charlie\AppData\Local\flax\cache\audio.mp3';
      const winForwardPath = 'C:/Users/david/AppData/Local/flax';

      final sanitizedMac = DiagnosticsSanitizer.sanitize(macPath);
      final sanitizedLinux = DiagnosticsSanitizer.sanitize(linuxPath);
      final sanitizedWin = DiagnosticsSanitizer.sanitize(winPath);
      final sanitizedWinForward = DiagnosticsSanitizer.sanitize(winForwardPath);

      expect(sanitizedMac, isNot(contains('alice')));
      expect(
        sanitizedMac,
        equals('~/Library/Application Support/com.flax/flax.db'),
      );

      expect(sanitizedLinux, isNot(contains('bob')));
      expect(sanitizedLinux, equals('~/.config/flax/settings.json'));

      expect(sanitizedWin, isNot(contains('charlie')));
      expect(sanitizedWin, equals(r'~\AppData\Local\flax\cache\audio.mp3'));

      expect(sanitizedWinForward, isNot(contains('david')));
      expect(sanitizedWinForward, equals('~/AppData/Local/flax'));
    });

    test('redacts hardware UUIDs', () {
      const raw =
          'Client Device UUID: a1b2c3d4-e5f6-7890-abcd-ef1234567890 initialized';
      final sanitized = DiagnosticsSanitizer.sanitize(raw);

      expect(
        sanitized,
        isNot(contains('a1b2c3d4-e5f6-7890-abcd-ef1234567890')),
      );
      expect(
        sanitized,
        equals('Client Device UUID: [REDACTED_UUID] initialized'),
      );
    });

    test('redacts explicit username when provided', () {
      const raw = 'Cache owner is test_admin_user located at root';
      final sanitized = DiagnosticsSanitizer.sanitize(
        raw,
        username: 'test_admin_user',
      );

      expect(sanitized, isNot(contains('test_admin_user')));
      expect(sanitized, contains('[REDACTED_USER]'));
    });
  });

  group('DiagnosticsReport Markdown formatting', () {
    test('formats all sections cleanly with GitHub flavored markdown', () {
      const report = DiagnosticsReport(
        appVersion: 'v0.5.6',
        buildNumber: '185',
        updateChannel: 'Dev',
        buildMode: 'Release',
        osName: 'macOS',
        osVersion: 'Version 15.0 (Build 24A335)',
        architecture: 'macos_arm64',
        dartVersion: '3.12.2',
        outputDevice: 'auto',
        outputDescription: 'System Default',
        outputEngine: 'PipeWire',
        exclusiveMode: false,
        sampleRate: 'Auto',
        bitDepth: 'Auto',
        eqEnabled: true,
        eqPreset: 'Rock',
        eqPreamp: -2.0,
        autoEqProfile: 'Sennheiser HD 650',
        serverType: 'Navidrome',
        serverVersion: '0.53.0',
        subsonicApiVersion: '1.16.1',
        openSubsonicSupported: true,
        openSubsonicExtensions: ['songLyrics (v1)', 'replayGain (v1)'],
        serverUrlSanitized: 'https://[REDACTED_SERVER]',
        cacheLimit: '10 GB',
        audioCachedBytes: 125829120, // ~120 MB
        audioCachedTracks: 42,
        metadataCoversCached: 100,
        metadataCoversTotal: 100,
        metadataArtistsCached: 25,
        metadataArtistsTotal: 25,
        metadataBiosCached: 25,
        metadataBiosTotal: 25,
        backgroundSyncStatus: 'Scheduled',
        recentLogs: [
          '[2026-09-09T21:00:00.000] [INFO] [App] Initialized',
          '[2026-09-09T21:00:01.000] [INFO] [Player] Output connected',
        ],
      );

      final md = report.toMarkdown();

      expect(md, contains('### Environment & Client'));
      expect(md, contains('- **Flax Version**: v0.5.6 (build 185)'));
      expect(md, contains('- **Channel**: Dev'));
      expect(
        md,
        contains('- **Operating System**: macOS (Version 15.0 (Build 24A335))'),
      );

      expect(md, contains('### Audio Pipeline'));
      expect(md, contains('- **Active DAC / Output**: System Default (auto)'));
      expect(
        md,
        contains('- **Equalizer**: Enabled (Preset: Rock, Preamp: -2.0 dB)'),
      );
      expect(md, contains('- **AutoEQ Profile**: Sennheiser HD 650'));

      expect(md, contains('### Subsonic Server Capabilities'));
      expect(md, contains('- **Server Brand / Type**: Navidrome'));
      expect(md, contains('- **Subsonic API Version**: 1.16.1'));
      expect(md, contains('- **OpenSubsonic**: Supported'));
      expect(
        md,
        contains('- **Extensions**: songLyrics (v1), replayGain (v1)'),
      );

      expect(md, contains('### Storage & Caching'));
      expect(md, contains('- **Audio Cache Quota**: 10 GB'));
      expect(md, contains('Covers: 100/100, Photos: 25/25, Bios: 25/25'));

      expect(md, contains('### Recent Application Logs'));
      expect(md, contains('```'));
      expect(md, contains('[INFO] [App] Initialized'));
    });
  });
}
