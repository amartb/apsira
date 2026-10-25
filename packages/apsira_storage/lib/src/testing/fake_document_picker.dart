// From relay test/fakes/fake_document_picker.dart @ 09b28810 (pickOne) and
// viaticum test/fakes/fake_document_picker.dart @ 78d38e0 (pick, readAll),
// in one fake (D-APK-015).
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';

import '../document_picker.dart';

/// A document picker over scripted documents.
///
/// [pickOne] picks [next]: a fixture document, `null` for a cancel, or one
/// over the cap, answered `documentTooLarge` as the port says; [caps]
/// records the `maxBytes` of every call. [pick] returns what [offerFile] or
/// [offerBytes] offered, in order (with nothing offered, a cancel), and
/// [readAll] reads it; [requestedMimeTypes] records each pick's types.
final class FakeDocumentPicker implements DocumentPicker {
  FakeDocumentPicker({this.next});

  /// The file the next [pickOne] returns; null cancels.
  PickedDocument? next;

  /// The `maxBytes` of each [pickOne] call, in order.
  final List<int> caps = [];

  /// The MIME types each [pick] asked for, in order.
  final List<List<String>> requestedMimeTypes = [];

  final List<DocumentRef> _offered = [];
  final Map<String, File> _files = {};
  final Map<String, Uint8List> _bytes = {};

  /// Offers [file] to the next [pick].
  void offerFile(File file) {
    final doc = DocumentRef(
      uri: file.uri.toString(),
      name: file.uri.pathSegments.last,
      sizeBytes: file.lengthSync(),
    );
    _files[doc.uri] = file;
    _offered.add(doc);
  }

  /// Offers a document named [name] holding [bytes] to the next [pick]
  /// (for widget tests, where file I/O does not complete).
  void offerBytes(String name, List<int> bytes) {
    final doc = DocumentRef(
      uri: 'memory://${_offered.length + _bytes.length}/$name',
      name: name,
      sizeBytes: bytes.length,
    );
    _bytes[doc.uri] = Uint8List.fromList(bytes);
    _offered.add(doc);
  }

  @override
  Future<Result<PickedDocument?, Failure>> pickOne({
    required int maxBytes,
  }) async {
    caps.add(maxBytes);
    final picked = next;
    if (picked != null && picked.bytes.length > maxBytes) {
      return const Result.err(DocumentPicker.tooLarge);
    }
    return Result.ok(picked);
  }

  @override
  Future<Result<DocumentRef?, Failure>> pick({
    List<String> mimeTypes = const [],
  }) async {
    requestedMimeTypes.add(mimeTypes);
    return Ok(_offered.isEmpty ? null : _offered.removeAt(0));
  }

  @override
  Future<Result<Uint8List, Failure>> readAll(
    DocumentRef doc, {
    required int maxBytes,
  }) async {
    if (_bytes[doc.uri] case final bytes?) {
      return bytes.length > maxBytes
          ? const Err(DocumentPicker.tooLarge)
          : Ok(bytes);
    }
    final file = _files[doc.uri];
    if (file == null || !file.existsSync()) {
      return const Err(DocumentPicker.documentUnreadable);
    }
    if (file.lengthSync() > maxBytes) {
      return const Err(DocumentPicker.tooLarge);
    }
    return Ok(await file.readAsBytes());
  }
}
