// The failures of the app link (contract app-link.md §8, D-APK-026): every
// reason APSIRA is unavailable and every call error, as values, never thrown.
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';

/// Why APSIRA cannot be used right now. The app behaves as it does without
/// APSIRA (contract §1): APSIRA missing, untrusted or slow is unavailable.
///
/// `not_authorised` and `unsupported_version` are contract §8 codes; the
/// others are the client's own (ruling A-5).
enum LinkUnavailableReason {
  /// No APSIRA build this app may talk to is installed.
  notInstalled('not_installed', 'linkNotInstalled'),

  /// APSIRA is installed but its certificate is not the recorded one.
  notTrusted('not_trusted', 'linkNotTrusted'),

  /// APSIRA refused this app (contract §3.2).
  notAuthorised('not_authorised', 'linkNotAuthorised'),

  /// No common version (contract §9).
  unsupportedVersion('unsupported_version', 'linkUnsupportedVersion'),

  /// APSIRA did not answer within the deadline, or the call failed.
  noAnswer('no_answer', 'linkNoAnswer'),

  /// APSIRA answered with something this client does not understand.
  unknownError('unknown_error', 'linkUnknownError');

  const LinkUnavailableReason(this.wire, this.code);

  /// The name on the channel and in the contract.
  final String wire;

  /// The [Failure.code] of a [LinkUnavailable] with this reason.
  final String code;

  /// The reason named [wire]; an unknown name is [unknownError].
  static LinkUnavailableReason fromWire(String wire) {
    for (final reason in values) {
      if (reason.wire == wire) return reason;
    }
    return unknownError;
  }
}

/// A call APSIRA answered with an error (contract §8): APSIRA is there, the
/// call did not succeed.
enum LinkErrorCode {
  /// APSIRA is migrating or restoring; retry later.
  busy('busy', 'linkBusy'),

  /// The call needs the hub and it is not reachable.
  away('away', 'linkAway'),

  /// The device queue cannot take the backup.
  storageFull('storage_full', 'linkStorageFull'),

  /// An unknown name, snapshot, source or held id.
  notFound('not_found', 'linkNotFound'),

  /// A gateway source the caller is not allowed.
  notAllowed('not_allowed', 'linkNotAllowed'),

  /// A payload's SHA-256 did not match.
  checksumMismatch('checksum_mismatch', 'linkChecksumMismatch');

  const LinkErrorCode(this.wire, this.code);

  /// The `error` value on the channel and in the contract.
  final String wire;

  /// The [Failure.code] of a [LinkCallFailed] with this error.
  final String code;
}

/// A failure of the app link: [LinkUnavailable] or [LinkCallFailed].
sealed class LinkFailure extends Failure {
  LinkFailure(super.code);

  /// The name of this failure on the channel and in the contract.
  String get wire;
}

/// APSIRA cannot be used: the app works alone (contract §1).
final class LinkUnavailable extends LinkFailure {
  /// [theirs] and [ours] name both version lists when [reason] is
  /// [LinkUnavailableReason.unsupportedVersion]; empty otherwise.
  LinkUnavailable(this.reason, {this.theirs = const [], this.ours = const []})
    : super(reason.code);

  final LinkUnavailableReason reason;

  /// The versions APSIRA offered.
  final List<String> theirs;

  /// The versions this client speaks.
  final List<String> ours;

  @override
  String get wire => reason.wire;

  @override
  bool operator ==(Object other) =>
      other is LinkUnavailable &&
      other.reason == reason &&
      listEquals(other.theirs, theirs) &&
      listEquals(other.ours, ours);

  @override
  int get hashCode =>
      Object.hash(reason, Object.hashAll(theirs), Object.hashAll(ours));

  @override
  String toString() => theirs.isEmpty && ours.isEmpty
      ? 'LinkUnavailable(${reason.wire})'
      : 'LinkUnavailable(${reason.wire}, theirs: $theirs, ours: $ours)';
}

/// APSIRA answered the call with one of contract §8's errors.
final class LinkCallFailed extends LinkFailure {
  LinkCallFailed(this.error) : super(error.code);

  final LinkErrorCode error;

  @override
  String get wire => error.wire;

  @override
  String toString() => 'LinkCallFailed(${error.wire})';
}

/// The failure for an `error` value APSIRA returned (contract §8):
/// `not_authorised` and `unsupported_version` are [LinkUnavailable], the six
/// call errors are [LinkCallFailed], and an unknown code is
/// [LinkUnavailableReason.unknownError] ("treated as unavailable").
LinkFailure linkFailureFromWire(String code) {
  if (code == LinkUnavailableReason.notAuthorised.wire) {
    return LinkUnavailable(LinkUnavailableReason.notAuthorised);
  }
  if (code == LinkUnavailableReason.unsupportedVersion.wire) {
    return LinkUnavailable(LinkUnavailableReason.unsupportedVersion);
  }
  for (final error in LinkErrorCode.values) {
    if (error.wire == code) return LinkCallFailed(error);
  }
  return LinkUnavailable(LinkUnavailableReason.unknownError);
}
