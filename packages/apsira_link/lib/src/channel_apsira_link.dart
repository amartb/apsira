// The ApsiraLink adapter over the package's own Kotlin (D-APK-026). The
// Kotlin resolves APSIRA and checks its certificate before any call
// (contract §3.2); Dart never selects a trust mode (ruling R-2). The channel
// itself is LinkChannel's (K2-02a).
import 'package:apsira_core/apsira_core.dart';

import 'apsira_link.dart';
import 'link_channel.dart';
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
  static const channelName = LinkChannel.name;

  @override
  Future<Result<LinkHello, LinkFailure>> hello() async {
    final reply = await const LinkChannel().call('hello', const {});
    return switch (reply) {
      Ok(value: (:final fields, :final devUnverified)) => LinkHello.fromReply(
        fields,
        devUnverified: devUnverified,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
