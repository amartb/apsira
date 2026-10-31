// The Dart half of the app-side provider (contract app-link.md §5.4, D-034;
// K2-02d), written from the contract. APSIRA calls the app's AppLinkProvider
// (android/…/AppLinkProvider.kt); a whole restore offer waits in the inbox
// (AppLinkInbox.kt) until the app takes it, and Kotlin says `offer` on the
// requests channel to every attached engine. Taking reads and clears, so an
// offer reaches the app once: through [AppLinkRequests.takePendingOffer] at
// start and on resume, or through [AppLinkRequests.offers] while the app
// listens. No method throws; nothing names the backup in a log or toString.
import 'dart:async';

import 'package:flutter/services.dart';

/// The names an adopting app's manifest and apsira_jobs share with the
/// provider's Kotlin (test/provider_names_test.dart).
abstract final class AppLinkNames {
  /// The provider each app declares: exported, no permission attributes,
  /// `grantUriPermissions="false"`, authority `${applicationId}` +
  /// [authoritySuffix] (contract §2).
  static const providerClass = 'com.apsiralabs.apsira_link.AppLinkProvider';

  /// The provider's authority is the app's id + this.
  static const authoritySuffix = '.apsira';

  /// APSIRA's call for the central schedule (§5.3).
  static const backupNow = 'backup_now';

  /// APSIRA's restore offer (§5.4).
  static const restoreOffer = 'restore_offer';

  /// The `<meta-data>` naming the app's Dart backup job: declared, the app
  /// is on the central schedule and `backup_now` queues that job through
  /// apsira_jobs; absent, `backup_now` answers `accepted = false`.
  static const backupJobMetaData = 'com.apsiralabs.apsira_link.BACKUP_JOB';

  /// apsira_jobs' non-exported receiver `backup_now` sends the job to.
  static const runJobReceiver = 'com.apsiralabs.apsira_jobs.RunJobReceiver';

  /// The extra naming the job.
  static const runJobExtra = 'job';
}

/// Why APSIRA offers a restore (§5.4).
enum RestoreReason {
  /// The user asked for it in APSIRA.
  user('user'),

  /// "New phone in one go" (D-009): the app's latest snapshot.
  newDevice('new_device');

  const RestoreReason(this.wire);

  /// The contract's value.
  final String wire;
}

/// A restore APSIRA offers. The app shows its own confirmation and, on yes,
/// reads [snapshot] through its `BackupTarget` and restores through its own
/// path, exactly as from its own folder.
final class RestoreOffer {
  const RestoreOffer({
    required this.name,
    required this.snapshot,
    required this.madeUtc,
    required this.sizeBytes,
    required this.reason,
  });

  /// The backup's name, for the app's confirmation.
  final String name;

  /// The snapshot `restore_open` reads.
  final String snapshot;

  /// When the backup was made, in UTC.
  final DateTime madeUtc;

  /// The backup's size in bytes.
  final int sizeBytes;

  final RestoreReason reason;

  /// The offer in Kotlin's map; null unless every field is whole: non-empty
  /// [name] and [snapshot], a UTC `made_utc`, a `size` of at least 0 and a
  /// known `reason`.
  static RestoreOffer? fromWire(Object? wire) {
    if (wire is! Map<Object?, Object?>) return null;
    final name = wire['name'];
    final snapshot = wire['snapshot'];
    final made = wire['made_utc'];
    final size = wire['size'];
    final reason = wire['reason'];
    if (name is! String || name.isEmpty) return null;
    if (snapshot is! String || snapshot.isEmpty) return null;
    final madeUtc = made is String ? DateTime.tryParse(made) : null;
    if (madeUtc == null || !madeUtc.isUtc) return null;
    if (size is! int || size < 0) return null;
    final known = RestoreReason.values.where((r) => r.wire == reason);
    if (known.isEmpty) return null;
    return RestoreOffer(
      name: name,
      snapshot: snapshot,
      madeUtc: madeUtc,
      sizeBytes: size,
      reason: known.single,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RestoreOffer &&
      other.name == name &&
      other.snapshot == snapshot &&
      other.madeUtc == madeUtc &&
      other.sizeBytes == sizeBytes &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(name, snapshot, madeUtc, sizeBytes, reason);

  /// Names no backup: content stays out of logs.
  @override
  String toString() => 'RestoreOffer(${reason.wire})';
}

/// Requests APSIRA made of the app.
abstract interface class AppLinkRequests {
  /// Offers arriving while listened to, each already taken from the inbox.
  Stream<RestoreOffer> get offers;

  /// The waiting offer, cleared; null when there is none. Call at start and
  /// on resume.
  Future<RestoreOffer?> takePendingOffer();
}

/// [AppLinkRequests] over the plugin's requests channel. One per app.
final class ChannelAppLinkRequests implements AppLinkRequests {
  ChannelAppLinkRequests() {
    _offers = StreamController<RestoreOffer>.broadcast(
      onListen: () => _channel.setMethodCallHandler(_pushed),
      onCancel: () => _channel.setMethodCallHandler(null),
    );
  }

  /// The channel the Kotlin plugin registers (REQUESTS_CHANNEL).
  static const channelName = 'apsira_link/requests';

  /// Dart → Kotlin: `{}` → the offer's map or null; the inbox is cleared.
  static const takeMethod = 'takePendingOffer';

  /// Kotlin → Dart, no arguments: an offer is waiting.
  static const offerMethod = 'offer';

  static const _channel = MethodChannel(channelName);

  late final StreamController<RestoreOffer> _offers;

  @override
  Stream<RestoreOffer> get offers => _offers.stream;

  @override
  Future<RestoreOffer?> takePendingOffer() async {
    try {
      return RestoreOffer.fromWire(
        await _channel.invokeMethod<Object?>(takeMethod),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // Taken only while someone listens; otherwise it waits in the inbox.
  Future<Object?> _pushed(MethodCall call) async {
    if (call.method != offerMethod || !_offers.hasListener) return null;
    final offer = await takePendingOffer();
    if (offer != null) _offers.add(offer);
    return null;
  }
}
