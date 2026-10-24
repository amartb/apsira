// From relay test/features/first_open/first_open_flow_test.dart @ 09b28810,
// generic over the app's own steps (D-APK-017): the flow is a value; every
// move returns a new one; Next and Back stop at the ends; a skip jumps to a
// named step.
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Step { intro, language, tour, backup }

void main() {
  FirstOpenFlow<_Step> fresh() => FirstOpenFlow(_Step.values);

  test('starts on the first step', () {
    final flow = fresh();
    expect(flow.current, _Step.intro);
    expect(flow.index, 0);
    expect(flow.isFirst, isTrue);
    expect(flow.isLast, isFalse);
    expect(flow.steps, _Step.values);
  });

  test('runs the steps in order; Next on the last stays there', () {
    var flow = fresh();
    for (final step in _Step.values.skip(1)) {
      flow = flow.next();
      expect(flow.current, step);
    }
    expect(flow.isLast, isTrue);
    expect(flow.next(), flow);
  });

  test('Back walks back; Back on the first stays there', () {
    var flow = fresh().next().next();
    expect(flow.back().current, _Step.language);
    flow = flow.back().back();
    expect(flow.current, _Step.intro);
    expect(flow.back(), flow);
  });

  test('a skip lands on the step it names, from any step', () {
    for (final from in _Step.values) {
      expect(fresh().goTo(from).goTo(_Step.backup).current, _Step.backup);
    }
    expect(fresh().goTo(_Step.backup).back().current, _Step.tour);
  });

  test('a value: every move returns a new flow, equal by its place', () {
    final flow = fresh();
    final moved = flow.next();
    expect(flow.current, _Step.intro, reason: 'unchanged');
    expect(moved, fresh().next());
    expect(moved.hashCode, fresh().next().hashCode);
    expect(moved, isNot(flow));
  });

  test('starts at a given step', () {
    expect(FirstOpenFlow(_Step.values, current: _Step.tour).index, 2);
  });

  test('refuses no steps, a repeated step, or a step it does not have', () {
    expect(() => FirstOpenFlow<_Step>(const []), throwsArgumentError);
    expect(
      () => FirstOpenFlow([_Step.intro, _Step.intro]),
      throwsArgumentError,
    );
    final short = FirstOpenFlow([_Step.intro, _Step.tour]);
    expect(() => short.goTo(_Step.backup), throwsArgumentError);
    expect(
      () => FirstOpenFlow([_Step.intro], current: _Step.tour),
      throwsArgumentError,
    );
  });

  test('its steps cannot be changed from outside', () {
    final steps = [_Step.intro, _Step.tour];
    final flow = FirstOpenFlow(steps);
    steps.add(_Step.backup);
    expect(flow.steps, [_Step.intro, _Step.tour]);
    expect(() => flow.steps.add(_Step.backup), throwsUnsupportedError);
  });
}
