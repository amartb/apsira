// From lyceum test/app/restartable_root_test.dart @ 9f4ff27. The provider
// that records its life is a State here, since the package has no Riverpod:
// a restart disposes the child's subtree before anything runs on the
// stopped app, then mounts a new one.
import 'dart:async';

import 'package:apsira_app/apsira_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _events = <String>[];

/// A widget that records its life, as a provider scope built on the
/// database would.
class _Connection extends StatefulWidget {
  const _Connection();

  @override
  State<_Connection> createState() => _ConnectionState();
}

class _ConnectionState extends State<_Connection> {
  @override
  void initState() {
    super.initState();
    _events.add('built');
  }

  @override
  void dispose() {
    _events.add('disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Text('live', textDirection: TextDirection.ltr);
}

Widget _app() => const _Connection();

/// Pumps until [future] completes.
Future<void> _settle(WidgetTester tester, Future<void> future) async {
  var done = false;
  Object? error;
  unawaited(
    future.then<void>(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 20 && !done; i++) {
    await tester.pump();
  }
  expect(done, isTrue);
  if (error != null) throw error!;
}

void main() {
  setUp(_events.clear);

  testWidgets('a restart disposes the child before the app is stopped, '
      'then mounts a new one', (tester) async {
    final controller = RestartController();
    await tester.pumpWidget(
      RestartableRoot(controller: controller, child: _app()),
    );
    expect(find.text('live'), findsOneWidget);
    expect(_events, ['built']);

    await _settle(
      tester,
      controller.restart(
        whileStopped: () async {
          // Nothing of the old app is on screen any more.
          final gone = find.text('live').evaluate().isEmpty;
          _events.add(gone ? 'stopped' : 'stopped while shown');
        },
        open: () async {
          _events.add('open');
          return _app();
        },
      ),
    );
    await tester.pump();

    expect(_events, ['built', 'disposed', 'stopped', 'open', 'built']);
    expect(find.text('live'), findsOneWidget);
  });

  testWidgets('a failure while stopped still reopens the app', (tester) async {
    final controller = RestartController();
    await tester.pumpWidget(
      RestartableRoot(controller: controller, child: _app()),
    );
    Object? failure;
    try {
      await _settle(
        tester,
        controller.restart(
          whileStopped: () async => throw StateError('swap failed'),
          open: () async => _app(),
        ),
      );
    } on StateError catch (e) {
      failure = e;
    }
    expect(failure, isA<StateError>());
    await tester.pump();
    expect(find.text('live'), findsOneWidget);
    expect(_events, ['built', 'disposed', 'built']);
  });

  testWidgets('a restart needs a mounted root, one at a time', (tester) async {
    final controller = RestartController();
    expect(
      () => controller.restart(open: () async => _app()),
      throwsStateError,
    );
    await tester.pumpWidget(
      RestartableRoot(controller: controller, child: _app()),
    );
    final first = controller.restart(open: () async => _app());
    expect(
      () => controller.restart(open: () async => _app()),
      throwsStateError,
    );
    await _settle(tester, first);
  });
}
