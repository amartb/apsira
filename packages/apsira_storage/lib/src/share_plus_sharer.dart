// From relay lib/data/platform/share_plus_sharer.dart @ 09b28810 (VIATICUM's
// is the same).
import 'package:share_plus/share_plus.dart';

import 'sharer.dart';

/// The [Sharer] on `share_plus`: an `ACTION_SEND`
/// chooser on Android, with a `FileProvider` grant for a shared file.
final class SharePlusSharer implements Sharer {
  const SharePlusSharer();

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) =>
      _share(ShareParams(text: text, subject: subject));

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  }) => _share(
    ShareParams(
      files: [XFile(path, mimeType: mimeType)],
      subject: subject,
    ),
  );

  static Future<ShareOutcome> _share(ShareParams params) async {
    final result = await SharePlus.instance.share(params);
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}
