// `hello` and the version negotiation of the app link (contract app-link.md
// §4, §9, D-APK-026).
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';

import 'link_failure.dart';

/// The `contract` extra every call carries (contract §4).
const linkContract = 'apsira.app_link';

/// The versions this client speaks, lowest first (contract §9).
const linkVersions = ['1.0'];

final _versionShape = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$');

(int, int)? _parse(String version) {
  final match = _versionShape.firstMatch(version);
  if (match == null) return null;
  return (int.parse(match[1]!), int.parse(match[2]!));
}

/// The highest `MAJOR.MINOR` in both [theirs] and [ours], compared
/// numerically; malformed versions are ignored; `null` when there is none.
String? chooseLinkVersion(
  List<String> theirs, {
  List<String> ours = linkVersions,
}) {
  final shared = ours.toSet().intersection(theirs.toSet());
  String? best;
  (int, int)? bestParsed;
  for (final version in shared) {
    final parsed = _parse(version);
    if (parsed == null) continue;
    if (bestParsed == null ||
        parsed.$1 > bestParsed.$1 ||
        (parsed.$1 == bestParsed.$1 && parsed.$2 > bestParsed.$2)) {
      best = version;
      bestParsed = parsed;
    }
  }
  return best;
}

/// APSIRA's answer to `hello` (contract §4).
@immutable
final class LinkHello {
  const LinkHello({
    required this.version,
    required this.versions,
    required this.appVersion,
    required this.locked,
    this.devUnverified = false,
  });

  /// The version chosen for every later call.
  final String version;

  /// The versions APSIRA offered.
  final List<String> versions;

  /// APSIRA's own version (`app_version`).
  final String appVersion;

  /// Whether APSIRA's UI is locked; calls still work.
  final bool locked;

  /// Whether the link was trusted by package name only: a development build
  /// talking to a development APSIRA (contract §3.3).
  final bool devUnverified;

  /// The hello for APSIRA's reply [fields]: a missing or mistyped field is
  /// [LinkUnavailableReason.unknownError]; no common version is
  /// [LinkUnavailableReason.unsupportedVersion] naming both lists.
  static Result<LinkHello, LinkFailure> fromReply(
    Map<Object?, Object?> fields, {
    bool devUnverified = false,
  }) {
    final versions = fields['versions'];
    final appVersion = fields['app_version'];
    final locked = fields['locked'];
    if (versions is! List<Object?> ||
        !versions.every((v) => v is String) ||
        appVersion is! String ||
        locked is! bool) {
      return Err(LinkUnavailable(LinkUnavailableReason.unknownError));
    }
    final theirs = List<String>.unmodifiable(versions.cast<String>());
    final version = chooseLinkVersion(theirs);
    if (version == null) {
      return Err(
        LinkUnavailable(
          LinkUnavailableReason.unsupportedVersion,
          theirs: theirs,
          ours: linkVersions,
        ),
      );
    }
    return Ok(
      LinkHello(
        version: version,
        versions: theirs,
        appVersion: appVersion,
        locked: locked,
        devUnverified: devUnverified,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkHello &&
      other.version == version &&
      listEquals(other.versions, versions) &&
      other.appVersion == appVersion &&
      other.locked == locked &&
      other.devUnverified == devUnverified;

  @override
  int get hashCode => Object.hash(
    version,
    Object.hashAll(versions),
    appVersion,
    locked,
    devUnverified,
  );

  @override
  String toString() =>
      'LinkHello($version of $versions, app $appVersion, locked $locked'
      '${devUnverified ? ', dev unverified' : ''})';
}
