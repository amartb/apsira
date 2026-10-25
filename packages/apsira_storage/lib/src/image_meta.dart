// From relay lib/domain/media/image_meta.dart @ 09b28810.
/// What an image file's first bytes say about it (07 P2-06, D-017): its
/// format, its stored size and its EXIF orientation, read without decoding
/// or re-encoding the image, so a photo is kept exactly as the camera or
/// the picker gave it.
///
/// The attachment row's `width` and `height` (data model §7.1) are the
/// [displayWidth] and [displayHeight]: the size the photo shows at, upright.
/// Flutter's decoder applies the EXIF orientation of JPEG and WebP itself,
/// so the viewer draws the decoded image as it is.
///
/// Read only: malformed or truncated bytes never throw. They give what
/// could be read (the format, perhaps no size) or null for no known image.
library;

import 'dart:typed_data';

/// An image's format, stored size and EXIF orientation.
final class ImageMeta {
  const ImageMeta({
    required this.mimeType,
    this.width,
    this.height,
    this.orientation = 1,
  });

  /// How many leading bytes [read] needs to find a JPEG's frame header
  /// behind the segments a camera writes first (EXIF with its thumbnail, an
  /// ICC profile); fewer may leave the size unknown.
  static const headerLength = 512 * 1024;

  /// `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/heic`,
  /// `image/heif` or `image/avif`.
  final String mimeType;

  /// The stored pixel width, before the orientation; null when unknown.
  final int? width;

  /// The stored pixel height, before the orientation; null when unknown.
  final int? height;

  /// The EXIF orientation, 1 to 8; 1 (upright) when there is none.
  final int orientation;

  /// Whether the orientation turns the photo a quarter (5 to 8), so it
  /// shows [height] wide.
  bool get swapsAxes => orientation >= 5;

  /// The width the photo shows at, upright.
  int? get displayWidth => swapsAxes ? height : width;

  /// The height the photo shows at, upright.
  int? get displayHeight => swapsAxes ? width : height;

  /// The meta of the image whose first bytes are [header] (give it
  /// [headerLength] of them when the file has that many), or null when they
  /// are no known image.
  static ImageMeta? read(List<int> header) {
    final b = _Bytes(header is Uint8List ? header : Uint8List.fromList(header));
    if (b.startsWith(0, const [0xFF, 0xD8, 0xFF])) return _jpeg(b);
    if (b.startsWith(0, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return _png(b);
    }
    if (b.ascii(0, 'GIF87a') || b.ascii(0, 'GIF89a')) {
      return ImageMeta(
        mimeType: 'image/gif',
        width: b.u16le(6),
        height: b.u16le(8),
      );
    }
    if (b.ascii(0, 'RIFF') && b.ascii(8, 'WEBP')) return _webp(b);
    if (b.ascii(4, 'ftyp')) return _isoBrand(b);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ImageMeta &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(mimeType, width, height, orientation);

  @override
  String toString() =>
      'ImageMeta($mimeType, ${width}x$height, orientation $orientation)';
}

const _jpegMime = 'image/jpeg';

/// Walks the JPEG's segments to its first frame header (SOF), reading the
/// orientation from an APP1 Exif segment on the way; stops at the scan.
ImageMeta _jpeg(_Bytes b) {
  var orientation = 1;
  var at = 2;
  while (true) {
    // Fill bytes (0xFF) may pad a marker.
    while (b.u8(at) == 0xFF && b.u8(at + 1) == 0xFF) {
      at++;
    }
    if (b.u8(at) != 0xFF) break;
    final marker = b.u8(at + 1);
    if (marker == null) break;
    // Markers without a length: TEM and the restart markers.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      at += 2;
      continue;
    }
    // End of image, or the start of the scan: no frame header follows.
    if (marker == 0xD9 || marker == 0xDA) break;
    final length = b.u16be(at + 2);
    if (length == null || length < 2) break;
    final body = at + 4;
    if (_isSof(marker)) {
      final height = b.u16be(body + 1);
      final width = b.u16be(body + 3);
      if (width == null || height == null) break;
      return ImageMeta(
        mimeType: _jpegMime,
        width: width,
        height: height,
        orientation: orientation,
      );
    }
    if (marker == 0xE1 && b.ascii(body, 'Exif\x00\x00')) {
      final end = at + 2 + length;
      orientation = _exifOrientation(b, body + 6, end) ?? orientation;
    }
    at += 2 + length;
  }
  return ImageMeta(mimeType: _jpegMime, orientation: orientation);
}

/// Baseline, progressive, lossless and arithmetic frame headers; not DHT
/// (C4), JPG (C8) or DAC (CC).
bool _isSof(int marker) =>
    marker >= 0xC0 &&
    marker <= 0xCF &&
    marker != 0xC4 &&
    marker != 0xC8 &&
    marker != 0xCC;

/// The orientation (tag 0x0112, one SHORT, 1 to 8) in IFD0 of the TIFF
/// block from [start] to [end], or null when it is absent or malformed.
int? _exifOrientation(_Bytes b, int start, int end) {
  final little = b.ascii(start, 'II');
  if (!little && !b.ascii(start, 'MM')) return null;
  int? u16(int offset) => offset + 2 > end
      ? null
      : (little ? b.u16le(start + offset) : b.u16be(start + offset));
  int? u32(int offset) => offset + 4 > end
      ? null
      : (little ? b.u32le(start + offset) : b.u32be(start + offset));
  if (u16(2) != 42) return null;
  final ifd = u32(4);
  if (ifd == null || start + ifd >= end) return null;
  final count = u16(ifd);
  if (count == null) return null;
  for (var i = 0; i < count; i++) {
    final entry = ifd + 2 + 12 * i;
    if (start + entry + 12 > end) return null;
    if (u16(entry) != 0x0112) continue;
    if (u16(entry + 2) != 3 || u32(entry + 4) != 1) return null;
    final value = u16(entry + 8);
    return value != null && value >= 1 && value <= 8 ? value : null;
  }
  return null;
}

ImageMeta _png(_Bytes b) {
  final ihdr = b.ascii(12, 'IHDR');
  return ImageMeta(
    mimeType: 'image/png',
    width: ihdr ? b.u32be(16) : null,
    height: ihdr ? b.u32be(20) : null,
  );
}

const _webpMime = 'image/webp';

/// The size from the first image chunk (VP8, VP8L) or the extended header
/// (VP8X), and an extended file's EXIF orientation.
ImageMeta _webp(_Bytes b) {
  const data = 20;
  if (b.ascii(12, 'VP8 ')) {
    // A key frame: 3 tag bytes, the start code, then 14-bit sizes.
    if (!b.startsWith(data + 3, const [0x9D, 0x01, 0x2A])) {
      return const ImageMeta(mimeType: _webpMime);
    }
    final w = b.u16le(data + 6);
    final h = b.u16le(data + 8);
    return ImageMeta(
      mimeType: _webpMime,
      width: w == null ? null : w & 0x3FFF,
      height: h == null ? null : h & 0x3FFF,
    );
  }
  if (b.ascii(12, 'VP8L')) {
    final bits = b.u32le(data + 1);
    if (b.u8(data) != 0x2F || bits == null) {
      return const ImageMeta(mimeType: _webpMime);
    }
    return ImageMeta(
      mimeType: _webpMime,
      width: (bits & 0x3FFF) + 1,
      height: ((bits >> 14) & 0x3FFF) + 1,
    );
  }
  if (b.ascii(12, 'VP8X')) {
    final w = b.u24le(data + 4);
    final h = b.u24le(data + 7);
    final hasExif = ((b.u8(data) ?? 0) & 0x08) != 0;
    return ImageMeta(
      mimeType: _webpMime,
      width: w == null ? null : w + 1,
      height: h == null ? null : h + 1,
      orientation: (hasExif ? _webpExif(b) : null) ?? 1,
    );
  }
  return const ImageMeta(mimeType: _webpMime);
}

/// The orientation in an extended WebP's EXIF chunk, which holds the TIFF
/// block, sometimes behind an `Exif\0\0` prefix.
int? _webpExif(_Bytes b) {
  var at = 12;
  while (true) {
    final size = b.u32le(at + 4);
    if (size == null) return null;
    if (b.ascii(at, 'EXIF')) {
      var start = at + 8;
      if (b.ascii(start, 'Exif\x00\x00')) start += 6;
      return _exifOrientation(b, start, at + 8 + size);
    }
    // Chunks are padded to an even size.
    at += 8 + size + (size & 1);
  }
}

/// HEIF-family files by their major brand; their size sits in boxes this
/// reader does not walk.
ImageMeta? _isoBrand(_Bytes b) {
  final brand = b.text(8, 4);
  return switch (brand) {
    'heic' ||
    'heix' ||
    'heim' ||
    'heis' => const ImageMeta(mimeType: 'image/heic'),
    'mif1' || 'msf1' || 'heif' => const ImageMeta(mimeType: 'image/heif'),
    'avif' || 'avis' => const ImageMeta(mimeType: 'image/avif'),
    _ => null,
  };
}

/// Bounds-checked reads: past the end gives null, never an error.
extension type const _Bytes(Uint8List bytes) {
  int? u8(int at) => at >= 0 && at < bytes.length ? bytes[at] : null;

  bool _has(int at, int n) => at >= 0 && at + n <= bytes.length;

  int? u16be(int at) => _has(at, 2) ? bytes[at] << 8 | bytes[at + 1] : null;

  int? u16le(int at) => _has(at, 2) ? bytes[at + 1] << 8 | bytes[at] : null;

  int? u24le(int at) =>
      _has(at, 3) ? bytes[at + 2] << 16 | bytes[at + 1] << 8 | bytes[at] : null;

  int? u32be(int at) => _has(at, 4)
      ? bytes[at] << 24 |
            bytes[at + 1] << 16 |
            bytes[at + 2] << 8 |
            bytes[at + 3]
      : null;

  int? u32le(int at) => _has(at, 4)
      ? bytes[at + 3] << 24 |
            bytes[at + 2] << 16 |
            bytes[at + 1] << 8 |
            bytes[at]
      : null;

  bool startsWith(int at, List<int> prefix) {
    if (!_has(at, prefix.length)) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[at + i] != prefix[i]) return false;
    }
    return true;
  }

  bool ascii(int at, String text) => startsWith(at, text.codeUnits);

  String? text(int at, int n) =>
      _has(at, n) ? String.fromCharCodes(bytes, at, at + n) : null;
}
