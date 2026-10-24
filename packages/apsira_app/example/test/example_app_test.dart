// The example's smoke test: at start it reads the device zone through the
// zone channel's read (a stub here; ZoneChannel.zoneId on a device) into
// SystemClock and shows it.
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_app_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(SystemClock.forgetZone);

  testWidgets('reads the zone once at start and shows it', (tester) async {
    var reads = 0;
    Future<String> read() async {
      reads++;
      return 'Europe/Madrid';
    }

    await tester.pumpWidget(ExampleApp(readZone: read));
    await tester.pump();

    expect(reads, 1);
    expect(const SystemClock().timeZoneName(), 'Europe/Madrid');
    expect(find.text('Zone Europe/Madrid'), findsOneWidget);
  });
}
