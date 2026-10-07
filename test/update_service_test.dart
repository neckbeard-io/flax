import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flax/services/updater/platform_installers/macos_installer.dart';
import 'package:flax/services/updater/platform_installers/windows_installer.dart';
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

  group('WindowsInstaller tests', () {
    test(
      'buildInstallerArgs configures user-level silent install correctly',
      () {
        final args = WindowsInstaller.buildInstallerArgs(
          installDir: r'C:\Users\tester\AppData\Local\Programs\flax',
          silent: true,
          isUserWritable: true,
        );

        expect(args, contains('/VERYSILENT'));
        expect(args, contains('/SP-'));
        expect(args, contains('/SUPPRESSMSGBOXES'));
        expect(args, contains('/NORESTART'));
        expect(args, contains('/CLOSEAPPLICATIONS'));
        expect(args, contains('/NORESTARTAPPLICATIONS'));
        expect(args, isNot(contains('/RESTARTAPPLICATIONS')));
        expect(args, contains(WindowsInstaller.relaunchArg));
        expect(args, contains('/CURRENTUSER'));
        expect(args, contains('/LOG'));
        expect(args, isNot(contains('/ALLUSERS')));
        expect(
          args,
          contains(r'/DIR=C:\Users\tester\AppData\Local\Programs\flax'),
        );
      },
    );

    test(
      'buildInstallerArgs configures administrative install for non-writable dirs',
      () {
        final args = WindowsInstaller.buildInstallerArgs(
          installDir: r'C:\Program Files\flax',
          silent: true,
          isUserWritable: false,
          logFilePath: r'C:\Temp\install.log',
        );

        expect(args, isNot(contains('/CURRENTUSER')));
        expect(args, contains('/ALLUSERS'));
        expect(args, contains(r'/LOG=C:\Temp\install.log'));
        expect(args, contains(r'/DIR=C:\Program Files\flax'));
      },
    );

    test('buildInstallerArgs respects non-silent mode', () {
      final args = WindowsInstaller.buildInstallerArgs(
        installDir: r'C:\Users\tester\flax',
        silent: false,
      );

      expect(args, isNot(contains('/VERYSILENT')));
      expect(args, isNot(contains(WindowsInstaller.relaunchArg)));
      expect(args, contains(r'/DIR=C:\Users\tester\flax'));
    });

    test('Setup receives the install directory intact', () {
      // A space and an apostrophe, in the directory and in the log path.
      const installDir = r"C:\Users\O'Brien\My Apps\flax";
      const logPath = r"C:\Users\O'Brien\Temp Files\flax setup.log";
      final args = WindowsInstaller.buildInstallerArgs(
        installDir: installDir,
        logFilePath: logPath,
      );

      // Process.start builds the command line; Setup splits it.
      final received = _innoSetupArgs(_dartWindowsCommandLine(args));

      expect(received, args.map((arg) => arg.replaceAll('"', '')).toList());
      expect(received, contains('/DIR=$installDir'));
      expect(received, contains('/LOG=$logPath'));
      for (final arg in args) {
        expect(arg, isNot(contains('"')), reason: 'Setup reads \\" as text');
      }
    });

    group('installer', () {
      final iss = File('packaging/windows/flax.iss').readAsStringSync();
      final launches = iss
          .split('[Run]')
          .last
          .split(RegExp(r'^\[', multiLine: true))
          .first
          .split('\n')
          .where((line) => line.contains('{#AppExeName}'))
          .toList();

      test('opens flax silently only when the updater asks', () {
        // A silent install that is not an update must leave flax closed, and
        // an update must open exactly one copy.
        expect(launches, hasLength(2));
        final silent = launches.where((l) => !l.contains('skipifsilent'));
        expect(silent, hasLength(1));
        expect(silent.single, contains('Check: RelaunchAfterUpdate'));
        expect(silent.single, contains('runasoriginaluser'));
        expect(silent.single, isNot(contains('postinstall')));
      });

      test('reads the same switch the updater passes', () {
        final code = iss.split('[Code]').last;
        final check = RegExp(
          r'function RelaunchAfterUpdate: Boolean;\s*begin\s*(.*?)\s*end;',
          dotAll: true,
        ).firstMatch(code);
        expect(check, isNotNull);
        expect(check!.group(1), contains('WizardSilent'));

        final param = RegExp(
          r"ExpandConstant\('\{param:(\w+)\|0\}'\) = '(\w+)'",
        ).firstMatch(check.group(1)!);
        expect(param, isNotNull);
        expect(
          WindowsInstaller.relaunchArg,
          '/${param!.group(1)}=${param.group(2)}',
        );
      });
    });

    test('deleteLeftovers removes old installers and update scripts', () async {
      final tempDir = await Directory.systemTemp.createTemp('flax-leftovers-');
      addTearDown(() => tempDir.delete(recursive: true));
      const leftovers = [
        'flax-0.6.1-dev.3-windows-x64-setup.exe',
        'flax_update_10176.ps1',
      ];
      const kept = [
        'flax-0.6.1-dev.3-windows-x64.zip',
        'flax_updater.log',
        'Setup Log 2026-10-07 #001.txt',
        'other-setup.exe',
      ];
      for (final name in [...leftovers, ...kept]) {
        File(p.join(tempDir.path, name)).writeAsStringSync('x');
      }

      final deleted = await WindowsInstaller.deleteLeftovers(tempDir);

      expect(deleted, leftovers.length);
      final remaining = tempDir
          .listSync()
          .map((e) => p.basename(e.path))
          .toList();
      expect(remaining, unorderedEquals(kept));
    });

    test(
      'canWriteWithoutElevation checks write permissions on directory',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'flax-perm-test-',
        );
        addTearDown(() async {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        });

        expect(WindowsInstaller.canWriteWithoutElevation(tempDir.path), isTrue);
      },
    );
  });

  group('UpdateState copyWith', () {
    test('clears localFilePath when clearLocalFilePath is true', () {
      const state = UpdateState(
        stage: UpdateStage.readyToInstall,
        localFilePath: '/tmp/old_flax.exe',
        downloadProgress: 1.0,
      );

      final updated = state.copyWith(
        stage: UpdateStage.available,
        clearLocalFilePath: true,
        downloadProgress: 0.0,
      );

      expect(updated.localFilePath, isNull);
      expect(updated.downloadProgress, 0.0);
      expect(updated.stage, UpdateStage.available);
    });

    test('preserves localFilePath when clearLocalFilePath is false', () {
      const state = UpdateState(
        stage: UpdateStage.readyToInstall,
        localFilePath: '/tmp/old_flax.exe',
      );

      final updated = state.copyWith(stage: UpdateStage.installing);

      expect(updated.localFilePath, '/tmp/old_flax.exe');
      expect(updated.stage, UpdateStage.installing);
    });
  });
}

/// The command line `Process.start` builds from [args] on Windows, following
/// `_windowsArgumentEscape` in dart:io: an argument with a space, tab or quote
/// is wrapped in quotes, with quotes escaped and trailing backslashes doubled.
String _dartWindowsCommandLine(List<String> args) => args
    .map((arg) {
      if (arg.isEmpty) return '""';
      if (!arg.contains(' ') && !arg.contains('\t') && !arg.contains('"')) {
        return arg;
      }
      final escaped = arg.replaceAllMapped(
        RegExp(r'(\\*)"'),
        (m) => '${m[1]}${m[1]}\\"',
      );
      final trailing = RegExp(r'\\*$').firstMatch(arg)![0]!;
      return '"$escaped$trailing"';
    })
    .join(' ');

/// Splits a command line the way Inno Setup reads its parameters: whitespace
/// outside quotes ends an argument, and every double quote is dropped.
List<String> _innoSetupArgs(String commandLine) {
  final args = <String>[];
  final current = StringBuffer();
  var quoted = false;
  var inArg = false;
  for (final char in commandLine.split('')) {
    if (char == '"') {
      quoted = !quoted;
      inArg = true;
    } else if (!quoted && (char == ' ' || char == '\t')) {
      if (inArg) args.add(current.toString());
      current.clear();
      inArg = false;
    } else {
      current.write(char);
      inArg = true;
    }
  }
  if (inArg) args.add(current.toString());
  return args;
}
