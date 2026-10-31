// The ApsiraLink fake for app and package tests (D-APK-026).
import 'package:apsira_core/apsira_core.dart';

import '../src/apsira_link.dart';
import '../src/link_failure.dart';
import '../src/link_hello.dart';

/// An [ApsiraLink] that answers [hello] with a fixed result; by default
/// APSIRA is not installed, the state of every app on most phones.
final class FakeApsiraLink implements ApsiraLink {
  FakeApsiraLink({Result<LinkHello, LinkFailure>? hello})
    : helloResult =
          hello ?? Err(LinkUnavailable(LinkUnavailableReason.notInstalled));

  /// What [hello] answers; a test may change it between calls.
  Result<LinkHello, LinkFailure> helloResult;

  /// How many times [hello] was called.
  int helloCalls = 0;

  @override
  Future<Result<LinkHello, LinkFailure>> hello() async {
    helloCalls++;
    return helloResult;
  }
}
