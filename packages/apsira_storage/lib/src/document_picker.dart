// From relay lib/core/ports/document_picker.dart @ 09b28810 (pickOne,
// PickedDocument) and viaticum lib/core/ports/document_picker.dart @ 78d38e0
// (pick, readAll; its PickedDocument as DocumentRef), RELAY's names where
// both have one (D-APK-015).
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';

/// The system's document picker, one file at a time. Nothing is kept beyond
/// the bytes returned; the caller validates them.
///
/// Two ways to use it: [pickOne] picks and reads in one call, capped
/// (RELAY's holiday-pack import); [pick] then [readAll] lets the caller look
/// at the name and size before reading (VIATICUM's package and seed import).
abstract interface class DocumentPicker {
  /// The failure code of a picked file larger than the caller's limit.
  static const documentTooLarge = 'documentTooLarge';

  /// Failure: the document is larger than the caller's limit.
  static const tooLarge = Failure(documentTooLarge);

  /// Failure: the document could not be read whole (gone, or its provider
  /// failed midway).
  static const documentUnreadable = Failure('documentUnreadable');

  /// Shows the picker and reads the chosen file whole. `Ok(null)` when he
  /// cancels; `Err(documentTooLarge)` when the file has more than
  /// [maxBytes] bytes, read no further than that.
  Future<Result<PickedDocument?, Failure>> pickOne({required int maxBytes});

  /// Asks the user for one file, offering [mimeTypes] (all types when
  /// empty). `Ok(null)` when the user cancels.
  Future<Result<DocumentRef?, Failure>> pick({
    List<String> mimeTypes = const [],
  });

  /// Reads [doc] fully, refusing anything larger than [maxBytes] with
  /// [tooLarge].
  Future<Result<Uint8List, Failure>> readAll(
    DocumentRef doc, {
    required int maxBytes,
  });
}

/// A picked file: its display [name] and its [bytes].
final class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// A file the user picked, not yet read; [uri] is opaque to everything but
/// the picker. [sizeBytes] is what the provider reports, -1 when it reports
/// none.
final class DocumentRef {
  const DocumentRef({
    required this.uri,
    required this.name,
    required this.sizeBytes,
  });

  final String uri;
  final String name;
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      other is DocumentRef &&
      other.uri == uri &&
      other.name == name &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(uri, name, sizeBytes);

  /// Prints the size only: the name may carry content.
  @override
  String toString() => 'DocumentRef($sizeBytes bytes)';
}
