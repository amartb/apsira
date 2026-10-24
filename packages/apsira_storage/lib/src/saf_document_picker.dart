// From relay lib/data/platform/saf_document_picker.dart @ 09b28810, with
// viaticum lib/data/platform/saf_document_picker.dart @ 78d38e0's pick and
// readAll on the same seam and read (D-APK-015).
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart' show SafDocumentFile;

import 'document_picker.dart';

/// The [DocumentPicker] on the Storage Access Framework (RELAY K-101; VIATICUM
/// P1-04): `saf_util` shows the system's document picker
/// (`ACTION_OPEN_DOCUMENT`, one openable file, of the types asked for, any
/// type when none) and answers its
/// name and size; `saf_stream` reads its bytes a chunk at a time. A one-off read
/// grant only: nothing is persisted and nothing is kept but the bytes
/// returned.
///
/// The size is checked before a byte is read; a provider that reports no
/// size, or too small a one, is caught while reading, which stops at the
/// first chunk past the cap. A picker that cannot open (no activity, one
/// already open) answers as a cancel, as `SafBackupTarget.pickFolder` does:
/// the port has no failure for a pick. A read that fails is
/// [documentUnreadable]; nothing here throws. [pickOne], and [pick] with
/// [readAll], share the one read.
final class SafDocumentPicker implements DocumentPicker {
  /// [plugins] are `saf_util`'s and `saf_stream`'s unless a test scripts
  /// them.
  SafDocumentPicker([PickSafPlugins? plugins])
    : _saf = plugins ?? PluginPickSaf();

  final PickSafPlugins _saf;

  /// The failure of a picked document that could not be read whole (gone,
  /// or its provider failed midway): the port's.
  static const documentUnreadable = DocumentPicker.documentUnreadable;

  static const _tooLarge = DocumentPicker.tooLarge;

  @override
  Future<Result<PickedDocument?, Failure>> pickOne({
    required int maxBytes,
  }) async {
    final picked = await _pickFile(null);
    if (picked == null) return const Result.ok(null);
    final read = await _read(picked.uri, picked.length, maxBytes);
    return switch (read) {
      Ok(:final value) => Result.ok(
        PickedDocument(name: picked.name, bytes: value),
      ),
      Err(:final failure) => Result.err(failure),
    };
  }

  @override
  Future<Result<DocumentRef?, Failure>> pick({
    List<String> mimeTypes = const [],
  }) async {
    final picked = await _pickFile(mimeTypes.isEmpty ? null : mimeTypes);
    if (picked == null) return const Result.ok(null);
    return Result.ok(
      DocumentRef(uri: picked.uri, name: picked.name, sizeBytes: picked.length),
    );
  }

  @override
  Future<Result<Uint8List, Failure>> readAll(
    DocumentRef doc, {
    required int maxBytes,
  }) => _read(doc.uri, doc.sizeBytes, maxBytes);

  /// The picked file; null on a cancel and when the picker cannot open.
  Future<SafDocumentFile?> _pickFile(List<String>? mimeTypes) async {
    try {
      return await _saf.pickFile(mimeTypes: mimeTypes);
    } catch (_) {
      return null;
    }
  }

  /// The document at [uri] whole, refused before a byte is read when its
  /// reported [length] is over [maxBytes], and at the first chunk past it.
  Future<Result<Uint8List, Failure>> _read(
    String uri,
    int length,
    int maxBytes,
  ) async {
    if (length > maxBytes) return const Result.err(_tooLarge);
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in _saf.read(uri)) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) return const Result.err(_tooLarge);
      }
    } catch (_) {
      return const Result.err(documentUnreadable);
    }
    return Result.ok(bytes.takeBytes());
  }
}

/// The plugin calls [SafDocumentPicker] makes, one member each, so a host
/// test can script them without a device.
abstract interface class PickSafPlugins {
  /// The system's picker for one openable document of [mimeTypes] (any type
  /// when null); null when he cancels.
  Future<SafDocumentFile?> pickFile({List<String>? mimeTypes});

  /// The document at [uri], one chunk per pull; cancelling stops the read
  /// and closes the document.
  Stream<Uint8List> read(String uri);
}

/// [PickSafPlugins] on `saf_util` 3.1 and `saf_stream` 4.0.
final class PluginPickSaf implements PickSafPlugins {
  PluginPickSaf();

  /// The size of one read: a document over the cap is read no further
  /// than one chunk past it.
  static const chunkBytes = 64 * 1024;

  final _util = SafUtil();
  final _stream = SafStream();

  @override
  Future<SafDocumentFile?> pickFile({List<String>? mimeTypes}) =>
      _util.pickFile(mimeTypes: mimeTypes);

  /// A custom read session, pulled a chunk at a time: `readFileStream`
  /// reads the whole document into its stream before a listener can
  /// cancel, so it cannot stop at the cap.
  @override
  Stream<Uint8List> read(String uri) async* {
    final session = await _stream.startReadCustomFileStream(
      uri,
      bufferSize: chunkBytes,
    );
    try {
      while (true) {
        final chunk = await _stream.readCustomFileStreamChunk(session);
        if (chunk == null || chunk.isEmpty) return;
        yield chunk;
      }
    } finally {
      await _stream.endReadCustomFileStream(session);
    }
  }
}
