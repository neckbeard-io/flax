import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two-pass streaming tar extraction with disk cleanup', () async {
    final tmp = Directory.systemTemp.createTempSync('tar_stream_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    // Create a mock tar archive
    final archive = Archive();
    archive.add(
      ArchiveFile.bytes(
        'index.json',
        utf8.encode(
          '[{"i": 10, "n": "Sennheiser HD 600", "s": "oratory1990", "r": 1}]',
        ),
      ),
    );
    archive.add(
      ArchiveFile.bytes(
        'Sennheiser HD 600/oratory1990/graphic.txt',
        utf8.encode('GraphicEQ: 20 1.5; 1000 0.0;'),
      ),
    );

    final tarData = TarEncoder().encode(archive);
    final tarGzData = GZipEncoder().encode(tarData);

    final archivePath = '${tmp.path}/archive.tar.gz';
    File(archivePath).writeAsBytesSync(tarGzData);

    final tarPath = '${tmp.path}/archive.tar';
    final inStream = File(archivePath).openRead();
    final outSink = File(tarPath).openWrite();
    await inStream.transform(gzip.decoder).pipe(outSink);

    // Pass 1: find index.json
    String? indexContent;
    final pass1Input = InputFileStream(tarPath);
    try {
      final decoder = TarDecoder();
      decoder.decodeStream(
        pass1Input,
        callback: (file) {
          if (file.name.endsWith('index.json')) {
            indexContent = utf8.decode(file.content as List<int>);
          }
          file.clear();
        },
      );
    } finally {
      pass1Input.closeSync();
    }

    expect(indexContent, isNotNull);
    final indexData = jsonDecode(indexContent!) as List;
    expect(indexData.length, equals(1));

    final idsFor = <String, List<int>>{
      'Sennheiser HD 600\u0000oratory1990': [10],
    };

    // Pass 2: extract curves
    final dataDir = Directory('${tmp.path}/data')..createSync();
    var written = 0;
    final pass2Input = InputFileStream(tarPath);
    try {
      final decoder = TarDecoder();
      decoder.decodeStream(
        pass2Input,
        callback: (file) {
          if (file.name.endsWith('graphic.txt')) {
            final segments = file.name.split('/');
            if (segments.length >= 3) {
              final source = segments[segments.length - 2];
              final headphone = segments[segments.length - 3];
              final ids = idsFor['$headphone\u0000$source'];
              if (ids != null) {
                final bytes = file.content as List<int>;
                for (final id in ids) {
                  File('${dataDir.path}/$id.txt').writeAsBytesSync(bytes);
                  written++;
                }
              }
            }
          }
          file.clear();
        },
      );
    } finally {
      pass2Input.closeSync();
    }

    expect(written, equals(1));
    expect(File('${dataDir.path}/10.txt').existsSync(), isTrue);
    expect(
      File('${dataDir.path}/10.txt').readAsStringSync(),
      equals('GraphicEQ: 20 1.5; 1000 0.0;'),
    );

    // Clean up archive files
    File(archivePath).deleteSync();
    File(tarPath).deleteSync();
    expect(File(tarPath).existsSync(), isFalse);
  });
}
