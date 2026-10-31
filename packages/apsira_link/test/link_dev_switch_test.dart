import 'package:apsira_link/apsira_link.dart' as link;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the dev switch is the package-named meta-data (R-2)', () {
    expect(link.linkDevSwitch, 'com.apsiralabs.apsira_link.DEV_LINK');
  });
}
