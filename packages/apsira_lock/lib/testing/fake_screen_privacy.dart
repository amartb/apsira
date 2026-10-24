// From relay test/fakes/fake_screen_privacy.dart @ 09b28810
import '../src/screen_privacy.dart';

/// Records what the app asked for: [hidden] is the last
/// state set, [calls] every one in order. With [error] set, [setHidden]
/// throws it, as a platform that cannot apply the flag would.
final class FakeScreenPrivacy implements ScreenPrivacy {
  FakeScreenPrivacy({this.error});

  /// What [setHidden] throws, when set.
  Object? error;

  /// The last state set; false until the app sets one.
  bool hidden = false;

  /// Every [setHidden] argument, in order.
  final List<bool> calls = [];

  @override
  Future<void> setHidden(bool hidden) async {
    calls.add(hidden);
    if (error case final error?) throw error;
    this.hidden = hidden;
  }
}
