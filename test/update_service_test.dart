import 'package:flutter_test/flutter_test.dart';
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
  });

  group('MacOSInstaller', () {
    test('findCurrentAppBundlePath returns valid app path on macOS', () {
      final appPath = MacOSInstaller.findCurrentAppBundlePath();
      expect(appPath, isNotEmpty);
      expect(appPath.endsWith('.app'), isTrue);
    });
  });
}
