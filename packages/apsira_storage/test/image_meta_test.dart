// From relay test/domain/media/image_meta_test.dart @ 09b28810.
// ImageMeta (07 P2-06, D-017): an image's format, stored size and EXIF
// orientation, read from its first bytes without decoding or re-encoding
// it. The fixtures in test/fixtures/media/ are tiny two-tone images (README
// there); the byte-order and range cases are built here from them.
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/media/$name').readAsBytesSync();

/// [jpeg] with an APP1 Exif segment right after its SOI marker, holding one
/// IFD0 entry: the orientation [value] in the [littleEndian] byte order, of
/// TIFF [type] (3 = SHORT).
Uint8List _withExif(
  Uint8List jpeg,
  int value, {
  bool littleEndian = true,
  int type = 3,
}) {
  final tiff = ByteData(26);
  final endian = littleEndian ? Endian.little : Endian.big;
  tiff
    ..setUint16(0, littleEndian ? 0x4949 : 0x4D4D)
    ..setUint16(2, 42, endian)
    ..setUint32(4, 8, endian)
    ..setUint16(8, 1, endian)
    ..setUint16(10, 0x0112, endian)
    ..setUint16(12, type, endian)
    ..setUint32(14, 1, endian)
    ..setUint16(18, value, endian)
    ..setUint32(22, 0, endian);
  final payload = [...'Exif'.codeUnits, 0, 0, ...tiff.buffer.asUint8List()];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    ...jpeg.sublist(2),
  ]);
}

void main() {
  group('JPEG', () {
    test('reads the size from the frame header; no EXIF means upright', () {
      final meta = ImageMeta.read(_fixture('photo.jpg'))!;
      expect(meta.mimeType, 'image/jpeg');
      expect((meta.width, meta.height), (40, 30));
      expect(meta.orientation, 1);
      expect((meta.displayWidth, meta.displayHeight), (40, 30));
    });

    test('orientation 6 (big-endian EXIF) swaps the display axes', () {
      final meta = ImageMeta.read(_fixture('orientation_6.jpg'))!;
      expect((meta.width, meta.height), (40, 20));
      expect(meta.orientation, 6);
      expect(meta.swapsAxes, isTrue);
      expect((meta.displayWidth, meta.displayHeight), (20, 40));
    });

    test('orientation 3 turns the photo over and keeps its axes', () {
      final meta = ImageMeta.read(_fixture('orientation_3.jpg'))!;
      expect(meta.orientation, 3);
      expect((meta.displayWidth, meta.displayHeight), (40, 20));
    });

    test('a little-endian EXIF block is read too', () {
      final meta = ImageMeta.read(_withExif(_fixture('photo.jpg'), 8))!;
      expect(meta.orientation, 8);
      expect((meta.displayWidth, meta.displayHeight), (30, 40));
      final big = _withExif(_fixture('photo.jpg'), 5, littleEndian: false);
      expect(ImageMeta.read(big)!.orientation, 5);
    });

    test('an orientation outside 1-8, or of the wrong type, reads as '
        'upright', () {
      for (final value in [0, 9, 300]) {
        final meta = ImageMeta.read(_withExif(_fixture('photo.jpg'), value))!;
        expect(meta.orientation, 1, reason: '$value');
      }
      final ascii = _withExif(_fixture('photo.jpg'), 6, type: 2);
      expect(ImageMeta.read(ascii)!.orientation, 1);
    });

    test('a frame header past the bytes given leaves the size unknown', () {
      final jpeg = _fixture('photo.jpg');
      final meta = ImageMeta.read(jpeg.sublist(0, 30))!;
      expect(meta.mimeType, 'image/jpeg');
      expect(meta.width, isNull);
      expect(meta.displayWidth, isNull);
    });
  });

  group('other formats', () {
    test('PNG, GIF and WebP (lossy, lossless, extended) give their size', () {
      final cases = {
        'photo.png': ('image/png', 12, 7),
        'photo.gif': ('image/gif', 9, 5),
        'lossy.webp': ('image/webp', 16, 8),
        'lossless.webp': ('image/webp', 10, 6),
      };
      for (final MapEntry(key: name, value: (mime, w, h)) in cases.entries) {
        final meta = ImageMeta.read(_fixture(name))!;
        expect(
          (meta.mimeType, meta.width, meta.height, meta.orientation),
          (mime, w, h, 1),
          reason: name,
        );
      }
    });

    test('an extended WebP carries its EXIF orientation', () {
      final meta = ImageMeta.read(_fixture('orientation_6.webp'))!;
      expect((meta.width, meta.height, meta.orientation), (16, 8, 6));
      expect((meta.displayWidth, meta.displayHeight), (8, 16));
    });

    test('HEIC and HEIF are recognised by their brand, size unknown', () {
      for (final (brand, mime) in [
        ('heic', 'image/heic'),
        ('mif1', 'image/heif'),
        ('avif', 'image/avif'),
      ]) {
        final header = Uint8List.fromList([
          0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, //
          0, 0, 0, 0, ...'mif1'.codeUnits, ...'heic'.codeUnits,
        ]);
        final meta = ImageMeta.read(header)!;
        expect(meta.mimeType, mime, reason: brand);
        expect(meta.width, isNull);
        expect(meta.orientation, 1);
      }
    });
  });

  group('robustness', () {
    test('bytes that are no known image read as null', () {
      expect(ImageMeta.read(Uint8List(0)), isNull);
      expect(ImageMeta.read('just text, not a photo'.codeUnits), isNull);
      expect(ImageMeta.read([0xFF, 0xD8]), isNull);
    });

    test('every prefix of every fixture reads without throwing', () {
      final names = Directory('test/fixtures/media')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => !n.endsWith('.md'));
      for (final name in names) {
        final bytes = _fixture(name);
        for (var n = 0; n <= bytes.length; n++) {
          expect(
            () => ImageMeta.read(bytes.sublist(0, n)),
            returnsNormally,
            reason: '$name[0..$n]',
          );
        }
      }
    });

    test('an EXIF block whose offsets point outside it is ignored', () {
      final jpeg = _withExif(_fixture('photo.jpg'), 6);
      // The IFD0 offset (TIFF bytes 4-7, after SOI, APP1 header and
      // 'Exif\0\0') pointed far past the segment.
      final broken = Uint8List.fromList(jpeg)
        ..setRange(4 + 2 + 6 + 4, 4 + 2 + 6 + 8, [0xFF, 0xFF, 0x00, 0x00]);
      final meta = ImageMeta.read(broken)!;
      expect(meta.orientation, 1);
      expect((meta.width, meta.height), (40, 30));
    });

    test('headerLength covers the JPEG segments a camera writes before its '
        'frame header (EXIF with thumbnail, ICC profile)', () {
      expect(ImageMeta.headerLength, greaterThanOrEqualTo(256 * 1024));
    });
  });
}
