// SharePlusSharer (D-APK-015; relay lib/data/platform/share_plus_sharer.dart
// @ 09b28810, which VIATICUM's equals): text and files go to share_plus's
// share sheet with their subject and MIME type, and its result is the
// port's outcome. share_plus's method channel is scripted.
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  late List<MethodCall> calls;
  String? answer;

  setUp(() {
    calls = [];
    answer = 'com.example.mail';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const sharer = SharePlusSharer();

  test('shareText sends the text and its subject', () async {
    expect(
      await sharer.shareText('Buy milk', subject: 'List'),
      ShareOutcome.shared,
    );
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(calls.single.method, 'share');
    expect(args['text'], 'Buy milk');
    expect(args['subject'], 'List');
    expect(args.containsKey('paths'), isFalse);
  });

  test('shareFile sends the path with its MIME type and subject', () async {
    expect(
      await sharer.shareFile(
        '/data/app/log.txt',
        mimeType: 'text/plain',
        subject: 'Log',
      ),
      ShareOutcome.shared,
    );
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['paths'], ['/data/app/log.txt']);
    expect(args['mimeTypes'], ['text/plain']);
    expect(args['subject'], 'Log');
    expect(args.containsKey('text'), isFalse);
  });

  test('a dismissed sheet is dismissed, a platform without results is '
      'unavailable', () async {
    answer = '';
    expect(await sharer.shareText('x'), ShareOutcome.dismissed);
    answer = null;
    expect(await sharer.shareText('x'), ShareOutcome.unavailable);
  });

  test('a platform error reaches the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'no_sheet'),
    );
    await expectLater(sharer.shareText('x'), throwsA(isA<PlatformException>()));
  });
}
