// The start gate's redirect: RELAY's (lib/app/router.dart `_redirect` @
// 09b28810) and LYCEUM's (lib/app/router.dart `startRedirect` @ 9f4ff27) in
// one pure function whose targets are the app's routes.
import 'package:apsira_app/apsira_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Paths no app uses, so nothing here is a RELAY route.
  const routes = StartRoutes(
    home: '/h',
    pending: '/wait',
    firstOpen: '/hello',
    locked: '/unlock',
    safeMode: '/safe',
  );
  const deepLink = '/notes/42';

  group('5 phases × 2 locations', () {
    final table = <(StartPhase, String, String?)>[
      (StartPhase.pending, '/', '/wait'),
      (StartPhase.pending, deepLink, '/wait'),
      (StartPhase.firstOpen, '/', '/hello'),
      (StartPhase.firstOpen, deepLink, '/hello'),
      (StartPhase.locked, '/', '/unlock'),
      (StartPhase.locked, deepLink, '/unlock'),
      (StartPhase.safeMode, '/', '/safe'),
      (StartPhase.safeMode, deepLink, '/safe'),
      (StartPhase.ready, '/', null),
      (StartPhase.ready, deepLink, null),
    ];
    for (final (phase, location, expected) in table) {
      test('$phase at $location → $expected', () {
        expect(startRedirect(phase, location, routes: routes), expected);
      });
    }
  });

  test('each phase lets its own screen through', () {
    expect(startRedirect(StartPhase.pending, '/wait', routes: routes), isNull);
    expect(
      startRedirect(StartPhase.firstOpen, '/hello', routes: routes),
      isNull,
    );
    expect(startRedirect(StartPhase.locked, '/unlock', routes: routes), isNull);
    expect(
      startRedirect(StartPhase.locked, '/unlock/pin', routes: routes),
      isNull,
      reason: 'the unlock screen\'s own sub-paths (LYCEUM)',
    );
    expect(startRedirect(StartPhase.safeMode, '/safe', routes: routes), isNull);
  });

  test('once ready, every start screen leads home', () {
    for (final start in [
      '/wait',
      '/hello',
      '/unlock',
      '/unlock/pin',
      '/safe',
    ]) {
      expect(
        startRedirect(StartPhase.ready, start, routes: routes),
        '/h',
        reason: start,
      );
    }
    expect(
      startRedirect(StartPhase.ready, '/hello/again', routes: routes),
      isNull,
      reason: 'first open and safe mode match exactly (RELAY)',
    );
  });

  test('without a pending route nothing moves while the gate waits '
      '(RELAY)', () {
    const relay = StartRoutes(
      home: '/',
      firstOpen: '/first-open',
      safeMode: '/safe-mode',
    );
    expect(startRedirect(StartPhase.pending, '/', routes: relay), isNull);
    expect(startRedirect(StartPhase.pending, deepLink, routes: relay), isNull);
    expect(
      startRedirect(StartPhase.firstOpen, deepLink, routes: relay),
      '/first-open',
    );
    expect(startRedirect(StartPhase.ready, '/safe-mode', routes: relay), '/');
  });

  test('a phase without a route never redirects', () {
    const bare = StartRoutes(home: '/');
    for (final phase in StartPhase.values) {
      expect(startRedirect(phase, deepLink, routes: bare), isNull);
    }
  });
}
