import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/testing/link_release_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

String _manifest(String application) =>
    '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="x">
$application
    </application>
</manifest>
''';

void main() {
  group('declaresLinkDevSwitch (rulings R-2, R-5)', () {
    test('an uncommented DEV_LINK with value true is declared', () {
      expect(
        declaresLinkDevSwitch(
          _manifest(
            '<meta-data android:name="$linkDevSwitch" android:value="true" />',
          ),
        ),
        isTrue,
      );
    });

    test('attribute order, quotes and line breaks do not matter', () {
      expect(
        declaresLinkDevSwitch(
          _manifest(
            "<meta-data\n  android:value='true'\n  android:name='$linkDevSwitch'/>",
          ),
        ),
        isTrue,
      );
    });

    test('a commented-out switch is not declared', () {
      expect(
        declaresLinkDevSwitch(
          _manifest(
            '<!-- <meta-data android:name="$linkDevSwitch" '
            'android:value="true" /> -->',
          ),
        ),
        isFalse,
      );
    });

    test('a manifest without it, or naming it in prose only, is not', () {
      expect(declaresLinkDevSwitch(_manifest('')), isFalse);
      expect(
        declaresLinkDevSwitch(
          _manifest('<!-- no $linkDevSwitch here: dev source set only -->'),
        ),
        isFalse,
      );
    });

    test('a switch with value false, or another name, is not', () {
      expect(
        declaresLinkDevSwitch(
          _manifest(
            '<meta-data android:name="$linkDevSwitch" android:value="false" />',
          ),
        ),
        isFalse,
      );
      expect(
        declaresLinkDevSwitch(
          _manifest(
            '<meta-data android:name="$linkDevSwitch.x" android:value="true" />',
          ),
        ),
        isFalse,
      );
    });
  });
}
