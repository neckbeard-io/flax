import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flax/services/updater/platform_installers/macos_installer.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_service.dart';

void main() {
  group('UpdateService semver comparison', () {
    test('correctly compares version components', () {
      expect(UpdateService.compareSemver('0.4.6', '0.4.5'), greaterThan(0));
      expect(UpdateService.compareSemver('0.5.0', '0.4.9'), greaterThan(0));
      expect(UpdateService.compareSemver('1.0.0', '0.9.9'), greaterThan(0));
      expect(UpdateService.compareSemver('0.4.5', '0.4.5'), equals(0));
      expect(UpdateService.compareSemver('0.4.5', '0.4.6'), lessThan(0));
      expect(UpdateService.compareSemver('v0.4.6', '0.4.5'), greaterThan(0));
    });

    test('correctly compares pre-release versions', () {
      // Newer major/minor/patch takes precedence over pre-releases of older versions
      expect(
        UpdateService.compareSemver('0.5.6-dev.1', '0.5.5'),
        greaterThan(0),
      );
      expect(UpdateService.compareSemver('0.5.5', '0.5.6-dev.1'), lessThan(0));

      // Sequential pre-releases of the same version
      expect(
        UpdateService.compareSemver('0.5.6-dev.2', '0.5.6-dev.1'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareSemver('0.5.6-dev.1', '0.5.6-dev.2'),
        lessThan(0),
      );

      // Stable release has higher precedence than pre-release of the same version
      expect(
        UpdateService.compareSemver('0.5.6', '0.5.6-dev.2'),
        greaterThan(0),
      );
      expect(UpdateService.compareSemver('0.5.6-dev.2', '0.5.6'), lessThan(0));

      // Identical pre-release versions
      expect(
        UpdateService.compareSemver('0.5.6-dev.1', 'v0.5.6-dev.1'),
        equals(0),
      );

      // Windows 4-part numeric version representations (e.g. 0.5.7.2 for 0.5.7-dev.2)
      expect(
        UpdateService.compareSemver('0.5.7-dev.3', '0.5.7.2'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareSemver('0.5.7.2', '0.5.7-dev.3'),
        lessThan(0),
      );
      expect(UpdateService.compareSemver('0.5.7-dev.2', '0.5.7.2'), equals(0));
      expect(UpdateService.compareSemver('0.5.7', '0.5.7.2'), greaterThan(0));
      expect(
        UpdateService.compareSemver('0.5.7.2', '0.5.7-dev.1'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareSemver('0.5.7-dev.1', '0.5.6.0'),
        greaterThan(0),
      );
    });

    test('formatDisplayVersion converts Windows 4-part versions', () {
      expect(UpdateService.formatDisplayVersion('0.5.7.2'), '0.5.7-dev.2');
      expect(UpdateService.formatDisplayVersion('v0.5.7.3'), '0.5.7-dev.3');
      expect(UpdateService.formatDisplayVersion('0.5.6.0'), '0.5.6');
      expect(UpdateService.formatDisplayVersion('0.5.6'), '0.5.6');
      expect(UpdateService.formatDisplayVersion('0.5.7-dev.2'), '0.5.7-dev.2');
    });

    test('UpdateChannel parsing', () {
      expect(UpdateChannel.fromString('dev'), equals(UpdateChannel.dev));
      expect(UpdateChannel.fromString('DEV'), equals(UpdateChannel.dev));
      expect(UpdateChannel.fromString('stable'), equals(UpdateChannel.stable));
      expect(UpdateChannel.fromString(null), equals(UpdateChannel.stable));
      expect(UpdateChannel.fromString('other'), equals(UpdateChannel.stable));
    });
  });

  group('UpdateService asset matching', () {
    final service = UpdateService();

    final testRelease = ReleaseInfo(
      tagName: 'v0.4.6',
      version: '0.4.6',
      title: 'flax v0.4.6',
      body:
          '### Added\n- Self-updater framework.\n\n---\nInstall notes here...',
      htmlUrl: 'https://github.com/neckbeard-io/flax/releases/tag/v0.4.6',
      publishedAt: DateTime.now(),
      isPrerelease: true,
      assets: const [
        ReleaseAsset(
          id: 1,
          name: 'flax-0.4.6-android-universal.apk',
          downloadUrl: 'http://example.com/flax.apk',
          sizeBytes: 90000000,
          contentType: 'application/vnd.android.package-archive',
        ),
        ReleaseAsset(
          id: 2,
          name: 'flax-0.4.6-windows-x64-setup.exe',
          downloadUrl: 'http://example.com/flax-setup.exe',
          sizeBytes: 16000000,
          contentType: 'application/x-msdownload',
        ),
        ReleaseAsset(
          id: 3,
          name: 'flax-0.4.6-macos-universal.dmg',
          downloadUrl: 'http://example.com/flax.dmg',
          sizeBytes: 38000000,
          contentType: 'application/x-apple-diskimage',
        ),
        ReleaseAsset(
          id: 4,
          name: 'flax-0.4.6-linux-amd64.deb',
          downloadUrl: 'http://example.com/flax.deb',
          sizeBytes: 14000000,
          contentType: 'application/vnd.debian.binary-package',
        ),
        ReleaseAsset(
          id: 5,
          name: 'flax-0.4.6-linux-x86_64.rpm',
          downloadUrl: 'http://example.com/flax.rpm',
          sizeBytes: 18000000,
          contentType: 'application/x-rpm',
        ),
        ReleaseAsset(
          id: 6,
          name: 'flax-0.4.6-linux-x64.tar.gz',
          downloadUrl: 'http://example.com/flax.tar.gz',
          sizeBytes: 18000000,
          contentType: 'application/gzip',
        ),
      ],
    );

    test('matches Android APK', () {
      final asset = service.findMatchingAsset(
        testRelease,
        InstallMethod.androidApk,
      );
      expect(asset?.name, equals('flax-0.4.6-android-universal.apk'));
    });

    test('matches Windows setup.exe', () {
      final asset = service.findMatchingAsset(
        testRelease,
        InstallMethod.windowsInstaller,
      );
      expect(asset?.name, equals('flax-0.4.6-windows-x64-setup.exe'));
    });

    test('matches macOS DMG', () {
      final asset = service.findMatchingAsset(
        testRelease,
        InstallMethod.macosDmg,
      );
      expect(asset?.name, equals('flax-0.4.6-macos-universal.dmg'));
    });

    test('matches Linux DEB and RPM', () {
      final debAsset = service.findMatchingAsset(
        testRelease,
        InstallMethod.linuxDeb,
      );
      expect(debAsset?.name, equals('flax-0.4.6-linux-amd64.deb'));

      final rpmAsset = service.findMatchingAsset(
        testRelease,
        InstallMethod.linuxRpm,
      );
      expect(rpmAsset?.name, equals('flax-0.4.6-linux-x86_64.rpm'));
    });

    test('concise changelog strips install divider', () {
      expect(
        testRelease.conciseChangelog,
        equals('### Added\n- Self-updater framework.'),
      );
    });

    test('ReleaseInfo copyWith works as expected', () {
      final updated = testRelease.copyWith(
        title: 'New Title',
        body: 'New Body',
      );
      expect(updated.title, equals('New Title'));
      expect(updated.body, equals('New Body'));
      expect(updated.tagName, equals(testRelease.tagName));
    });
  });

  group('UpdateService fetchLatestRelease with changelog aggregation', () {
    late Dio dio;
    late UpdateService service;

    setUp(() {
      dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {
                    'tag_name': 'v0.5.7-dev.18',
                    'name': 'flax v0.5.7-dev.18',
                    'body':
                        '### Fixed\n- Fix 18.\n\n---\nFor installation instructions...',
                    'html_url':
                        'https://github.com/neckbeard-io/flax/releases/tag/v0.5.7-dev.18',
                    'published_at': '2026-09-08T07:14:22Z',
                    'prerelease': true,
                    'assets': [],
                  },
                  {
                    'tag_name': 'v0.5.7-dev.17',
                    'name': 'flax v0.5.7-dev.17',
                    'body':
                        '### Fixed\n- Fix 17.\n\n---\nFor installation instructions...',
                    'html_url':
                        'https://github.com/neckbeard-io/flax/releases/tag/v0.5.7-dev.17',
                    'published_at': '2026-09-08T04:06:19Z',
                    'prerelease': true,
                    'assets': [],
                  },
                  {
                    'tag_name': 'v0.5.7-dev.16',
                    'name': 'flax v0.5.7-dev.16',
                    'body':
                        '### Added\n- Feat 16.\n\n---\nFor installation instructions...',
                    'html_url':
                        'https://github.com/neckbeard-io/flax/releases/tag/v0.5.7-dev.16',
                    'published_at': '2026-09-08T03:25:11Z',
                    'prerelease': true,
                    'assets': [],
                  },
                  {
                    'tag_name': 'v0.5.6',
                    'name': 'flax v0.5.6',
                    'body':
                        '### Added\n- Stable 0.5.6.\n\n---\nFor installation instructions...',
                    'html_url':
                        'https://github.com/neckbeard-io/flax/releases/tag/v0.5.6',
                    'published_at': '2026-08-29T06:25:48Z',
                    'prerelease': false,
                    'assets': [],
                  },
                ],
              ),
            );
          },
        ),
      );
      service = UpdateService(dio: dio);
    });

    test('single-version hop retains clean single release changelog', () async {
      final release = await service.fetchLatestRelease(
        channel: UpdateChannel.dev,
        currentVersion: '0.5.7-dev.17',
      );
      expect(release, isNotNull);
      expect(release!.version, equals('0.5.7-dev.18'));
      expect(release.conciseChangelog, equals('### Fixed\n- Fix 18.'));
    });

    test(
      'multi-version hop aggregates changelogs of intermediate releases',
      () async {
        final release = await service.fetchLatestRelease(
          channel: UpdateChannel.dev,
          currentVersion: '0.5.7-dev.16',
        );
        expect(release, isNotNull);
        expect(release!.version, equals('0.5.7-dev.18'));
        expect(
          release.conciseChangelog,
          equals(
            '## v0.5.7-dev.18\n### Fixed\n- Fix 18.\n\n'
            '## v0.5.7-dev.17\n### Fixed\n- Fix 17.',
          ),
        );
      },
    );

    test('stable channel filters out pre-releases', () async {
      final release = await service.fetchLatestRelease(
        channel: UpdateChannel.stable,
        currentVersion: '0.5.5',
      );
      expect(release, isNotNull);
      expect(release!.version, equals('0.5.6'));
      expect(release.conciseChangelog, equals('### Added\n- Stable 0.5.6.'));
    });
  });

  group('MacOSInstaller', () {
    test('findCurrentAppBundlePath returns valid app path on macOS', () {
      final appPath = MacOSInstaller.findCurrentAppBundlePath();
      expect(appPath, isNotEmpty);
      expect(appPath.endsWith('.app'), isTrue);
    });

    test('getMountedVolumes returns valid volume list without throwing', () {
      final volumes = MacOSInstaller.getMountedVolumes();
      expect(volumes, isNotNull);
    });

    test(
      'findAppBundleInside finds existing app bundle in directory',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'flax-test-mount-',
        );
        addTearDown(() async {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        });

        final fakeAppDir = Directory(p.join(tempDir.path, 'flax.app'));
        await fakeAppDir.create(recursive: true);

        final result = await MacOSInstaller.findAppBundleInside(
          tempDir.path,
          '/Applications/flax.app',
        );
        expect(result, isNotNull);
        expect(p.basename(result!), equals('flax.app'));
      },
    );

    test('findAppBundleInside returns null when no app exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('flax-test-empty-');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });

      final result = await MacOSInstaller.findAppBundleInside(
        tempDir.path,
        '/Applications/flax.app',
      );
      expect(result, isNull);
    });

    test(
      'findAppBundleInside finds app bundle inside attached DMG private mount',
      () async {
        if (!Platform.isMacOS) return;

        final tempDir = await Directory.systemTemp.createTemp('flax-dmg-test-');
        addTearDown(() async {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        });

        final pkgDir = Directory(p.join(tempDir.path, 'pkg'));
        final appDir = Directory(p.join(pkgDir.path, 'flax.app'));
        await appDir.create(recursive: true);

        final dmgPath = p.join(tempDir.path, 'test.dmg');
        await Process.run('hdiutil', [
          'create',
          '-volname',
          'flax_unit_test',
          '-srcfolder',
          pkgDir.path,
          '-ov',
          '-format',
          'UDZO',
          dmgPath,
        ]);

        final mountDir = Directory(p.join(tempDir.path, 'mnt'));
        await mountDir.create();

        final mountRes = await Process.run('hdiutil', [
          'attach',
          dmgPath,
          '-mountpoint',
          mountDir.path,
          '-nobrowse',
          '-readonly',
          '-noautoopen',
          '-noverify',
        ]);
        expect(mountRes.exitCode, equals(0));

        try {
          final found = await MacOSInstaller.findAppBundleInside(
            mountDir.path,
            '/Applications/flax.app',
          );
          expect(found, isNotNull);
          expect(p.basename(found!), equals('flax.app'));
        } finally {
          await Process.run('hdiutil', [
            'detach',
            mountDir.path,
            '-force',
            '-quiet',
          ]);
        }
      },
    );
  });
}
