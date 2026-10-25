// From relay test/fakes/fake_authenticator.dart @ 09b28810
import '../src/authenticator.dart';

/// Scripted pass and fail: each [authenticate] takes the
/// next outcome from [script], then repeats the last one.
final class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({
    List<AuthOutcome> script = const [AuthOutcome.passed],
    this.available = true,
  }) : _script = List.of(script);

  final List<AuthOutcome> _script;
  bool available;

  /// How many prompts were shown.
  int prompts = 0;

  /// The text of the last prompt shown.
  AuthPrompt? lastPrompt;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) async {
    prompts++;
    lastPrompt = prompt;
    if (!available) return AuthOutcome.unavailable;
    return _script.length > 1 ? _script.removeAt(0) : _script.single;
  }
}
