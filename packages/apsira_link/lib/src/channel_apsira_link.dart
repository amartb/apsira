// The ApsiraLink adapter over the package's own Kotlin (D-APK-026). The
// Kotlin resolves APSIRA and checks its certificate before any call
// (contract §3.2); Dart never selects a trust mode (ruling R-2).
import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/services.dart';

import 'apsira_link.dart';
import 'link_failure.dart';
import 'link_hello.dart';

/// [ApsiraLink] over the `apsira_link/link` method channel.
///
/// One method, `call`, with exactly `method`, `version` and `extras`. The
/// reply is `{unavailable: <reason>}`, `{error: <§8 code>}` or
/// `{fields: <map>, devUnverified: <bool>}`. A platform error, a missing
/// plugin or no reply within [linkControlDeadline] is
/// [LinkUnavailableReason.noAnswer]; a reply of any other shape is
/// [LinkUnavailableReason.unknownError].
final class ChannelApsiraLink implements ApsiraLink {
  const ChannelApsiraLink();

  /// The channel the Kotlin plugin registers.
  static const channelName = 'apsira_link/link';

  static const _channel = MethodChannel(channelName);

  @override
  Future<Result<LinkHello, LinkFailure>> hello() async {
    final reply = await _call('hello', linkVersions.last, const {});
    return switch (reply) {
      Ok(value: (:final fields, :final devUnverified)) => LinkHello.fromReply(
        fields,
        devUnverified: devUnverified,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<_Fields, LinkFailure>> _call(
    String method,
    String version,
    Map<String, Object?> extras,
  ) async {
    final Object? reply;
    try {
      reply = await _channel
          .invokeMethod<Object?>('call', {
            'method': method,
            'version': version,
            'extras': extras,
          })
          .timeout(linkControlDeadline);
    } on PlatformException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    } on MissingPluginException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    } on TimeoutException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    }
    return _read(reply);
  }

  static Result<_Fields, LinkFailure> _read(Object? reply) {
    if (reply is! Map<Object?, Object?>) return _unknown();
    final unavailable = reply['unavailable'];
    if (unavailable != null) {
      return unavailable is String
          ? Err(LinkUnavailable(LinkUnavailableReason.fromWire(unavailable)))
          : _unknown();
    }
    final error = reply['error'];
    if (error != null) {
      return error is String ? Err(linkFailureFromWire(error)) : _unknown();
    }
    final fields = reply['fields'];
    final devUnverified = reply['devUnverified'];
    if (fields is! Map<Object?, Object?> || devUnverified is! bool) {
      return _unknown();
    }
    return Ok((fields: fields, devUnverified: devUnverified));
  }

  static Result<_Fields, LinkFailure> _unknown() =>
      Err(LinkUnavailable(LinkUnavailableReason.unknownError));
}

typedef _Fields = ({Map<Object?, Object?> fields, bool devUnverified});
