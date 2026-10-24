// From relay test/fakes/fake_sharer.dart @ 09b28810, with viaticum
// test/fakes/fake_sharer.dart @ 78d38e0's contents (D-APK-015).
import 'dart:io';

import '../sharer.dart';

/// Records what the app shared and answers with [outcome]: [texts] and
/// [files] hold every call in order, and [contents] the bytes of each shared
/// file as it was at the call (null when no file is at the path). With
/// [error] set, both throw it, as a platform with no share sheet would.
final class FakeSharer implements Sharer {
  FakeSharer({this.outcome = ShareOutcome.shared, this.error});

  /// What every share returns.
  ShareOutcome outcome;

  /// What every share throws, when set.
  Object? error;

  /// Each [shareText] call: the text and its subject.
  final List<({String text, String? subject})> texts = [];

  /// Each [shareFile] call: the path, its MIME type and the subject.
  final List<({String path, String mimeType, String? subject})> files = [];

  /// The bytes of each [shareFile]'s file when it was shared.
  final List<List<int>?> contents = [];

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    texts.add((text: text, subject: subject));
    if (error case final error?) throw error;
    return outcome;
  }

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  }) async {
    files.add((path: path, mimeType: mimeType, subject: subject));
    final file = File(path);
    contents.add(file.existsSync() ? file.readAsBytesSync() : null);
    if (error case final error?) throw error;
    return outcome;
  }
}
