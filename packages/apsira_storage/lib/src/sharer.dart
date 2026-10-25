// From relay lib/core/ports/sharer.dart @ 09b28810 (VIATICUM's is the same).
/// The system share sheet: text (a note, a request list) and files (a log,
/// a CSV, a PDF). What is shared leaves the app only where the user sends
/// it; nothing here logs it (RELAY D-050).
library;

/// What the user did with the share sheet.
enum ShareOutcome {
  /// A target was chosen.
  shared,

  /// The sheet was dismissed without a choice.
  dismissed,

  /// The sheet was shown, but the platform does not say what was chosen.
  unavailable,
}

/// Opens the system share sheet.
abstract interface class Sharer {
  /// Shares [text], with [subject] for targets that take one (an email).
  Future<ShareOutcome> shareText(String text, {String? subject});

  /// Shares the file at [path] (app-private storage) as [mimeType], with
  /// [subject] for targets that take one.
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  });
}
