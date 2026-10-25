// FakeInstallFlag (package:apsira_app/testing.dart): an InstallFlag in
// memory, so an app's widget tests settle without real file I/O (RELAY's
// late-card and notification-asked flags, R3's finding).
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_app/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget reading an [InstallFlag], as an app's screen does.
class _Shows extends StatefulWidget {
  const _Shows(this.flag);

  final InstallFlag flag;

  @override
  State<_Shows> createState() => _ShowsState();
}

class _ShowsState extends State<_Shows> {
  bool? _set;

  @override
  void initState() {
    super.initState();
    widget.flag.isSet().then((set) => setState(() => _set = set));
  }

  @override
  Widget build(BuildContext context) => Text(switch (_set) {
    null => 'reading',
    true => 'set',
    false => 'unset',
  }, textDirection: TextDirection.ltr);
}

void main() {
  test('starts unset unless told, and set() sets it', () async {
    final flag = FakeInstallFlag();
    expect(await flag.isSet(), isFalse);
    await flag.set();
    expect(await flag.isSet(), isTrue);
    expect(flag.value, isTrue);
    expect(await FakeInstallFlag(set: true).isSet(), isTrue);
  });

  test('keeps the path it is given', () {
    expect(
      FakeInstallFlag(path: 'late_card/shown.json').path,
      'late_card/shown.json',
    );
  });

  testWidgets('a widget reading it settles in fake time, no runAsync', (
    tester,
  ) async {
    final flag = FakeInstallFlag(set: true);
    await tester.pumpWidget(_Shows(flag));
    await tester.pumpAndSettle();
    expect(find.text('set'), findsOneWidget);
  });
}
