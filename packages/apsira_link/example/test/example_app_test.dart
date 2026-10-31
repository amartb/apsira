import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/testing.dart';
import 'package:apsira_link_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('APSIRA missing is unavailable: not_installed', (tester) async {
    final link = FakeApsiraLink();
    await tester.pumpWidget(ExampleApp(link: link));
    await tester.pump();
    expect(find.text('unavailable: not_installed'), findsOneWidget);
    expect(link.helloCalls, 1);
  });

  testWidgets('a call error says error, not unavailable', (tester) async {
    final link = FakeApsiraLink(hello: Err(LinkCallFailed(LinkErrorCode.busy)));
    await tester.pumpWidget(ExampleApp(link: link));
    await tester.pump();
    expect(find.text('error: busy'), findsOneWidget);
  });

  testWidgets('a hello shows its line', (tester) async {
    final link = FakeApsiraLink(
      hello: const Ok(
        LinkHello(
          version: '1.0',
          versions: ['1.0'],
          appVersion: '0.1.0',
          locked: true,
        ),
      ),
    );
    await tester.pumpWidget(ExampleApp(link: link));
    await tester.pump();
    expect(find.text('hello: 1.0 · app 0.1.0 · locked true'), findsOneWidget);
    expect(find.text('dev link: unverified'), findsNothing);
  });

  testWidgets('a dev link says it is unverified', (tester) async {
    final link = FakeApsiraLink(
      hello: const Ok(
        LinkHello(
          version: '1.0',
          versions: ['1.0'],
          appVersion: '0.1.0',
          locked: false,
          devUnverified: true,
        ),
      ),
    );
    await tester.pumpWidget(ExampleApp(link: link));
    await tester.pump();
    expect(find.text('hello: 1.0 · app 0.1.0 · locked false'), findsOneWidget);
    expect(find.text('dev link: unverified'), findsOneWidget);
  });
}
