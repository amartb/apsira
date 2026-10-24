// The example's smoke test: at start it asks the StorageSpace port (the
// fake here; ChannelStorageSpace on a device) for app storage's free bytes
// once and shows them, or that they are unknown.
import 'package:apsira_storage/testing.dart';
import 'package:apsira_storage_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('asks for app storage\'s free bytes once at start and shows '
      'them', (tester) async {
    final space = FakeStorageSpace(free: 4096);

    await tester.pumpWidget(ExampleApp(space: space));
    await tester.pump();

    expect(space.calls, 1);
    expect(find.text('4096 bytes free'), findsOneWidget);
  });

  testWidgets('shows an unmeasurable space as unknown', (tester) async {
    await tester.pumpWidget(ExampleApp(space: FakeStorageSpace()));
    await tester.pump();

    expect(find.text('Free space unknown'), findsOneWidget);
  });
}
