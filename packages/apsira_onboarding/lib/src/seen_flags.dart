// From relay lib/domain/settings/one_time_tips.dart @ 09b28810 (a tip seen,
// by its id), kept per install through apsira_app's InstallFlag (D-APK-010
// C1, D-APK-017) instead of RELAY's `tips_dismissed` setting.
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';

/// Which one-time tips and tours this install has seen: one [InstallFlag]
/// file per id under app storage, never in the database or a backup. A
/// restore therefore neither sets nor clears a tip, and a reinstall shows
/// every tip again.
///
/// The file of an id is [pathOf]'s, `seen/<id>.json` by default; an app
/// passes its own layout to keep the files its installs already have.
final class SeenFlags {
  /// [directory] is app storage: the app's private support directory.
  SeenFlags(this.directory, {String Function(String id)? pathOf})
    : pathOf = pathOf ?? defaultPathOf;

  /// App storage.
  final Directory directory;

  /// The flag file of an id, relative to [directory].
  final String Function(String id) pathOf;

  /// `seen/<id>.json`.
  static String defaultPathOf(String id) => 'seen/$id.json';

  static final _plainId = RegExp(r'^[A-Za-z0-9_-]+$');

  /// The flag of [id]. Throws an [ArgumentError] unless [id] is a plain
  /// name (letters, digits, `_` and `-`), so an id is never a path.
  InstallFlag flagOf(String id) {
    if (!_plainId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'letters, digits, _ and - only');
    }
    return InstallFlag(directory: () async => directory, path: pathOf(id));
  }

  /// Whether [id] was seen: its flag file exists. A leftover `.tmp` alone
  /// reads unseen.
  Future<bool> isSeen(String id) => flagOf(id).isSet();

  /// Marks [id] seen, for good on this install: a `.tmp` flushed and
  /// renamed into place ([InstallFlag.set]).
  Future<void> markSeen(String id) => flagOf(id).set();
}
