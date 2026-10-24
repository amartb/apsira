// From lyceum test/data/platform/saf_backup_target_test.dart @ 9f4ff27
// (group 'ChannelStorageSpace.appFreeBytes'), with viaticum
// lib/data/platform/free_space_channel.dart @ 78d38e0's folderFreeBytes as
// freeBytes: both methods over `apsira_storage/storage`, null when the
// module cannot measure, errs or is missing, never a throw (D-APK-015).
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(ChannelStorageSpace.channelName);
  const space = ChannelStorageSpace();
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'appFreeBytes' ? 9876543210 : 123456789012;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('appFreeBytes asks the module for app storage, with no '
      'arguments', () async {
    expect(await space.appFreeBytes(), 9876543210);
    expect(calls.single.method, 'appFreeBytes');
    expect(calls.single.arguments, isNull);
  });

  test('freeBytes asks the module for the tree URI\'s volume', () async {
    expect(await space.freeBytes('content://tree/backups'), 123456789012);
    expect(calls.single.method, 'freeBytes');
    expect(calls.single.arguments, {'uri': 'content://tree/backups'});
  });

  for (final (name, ask) in <(String, Future<int?> Function())>[
    ('appFreeBytes', space.appFreeBytes),
    ('freeBytes', () => space.freeBytes('content://tree/backups')),
  ]) {
    test('$name is null when the module cannot measure, errs or is '
        'missing, never throwing', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await ask(), isNull);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'boom'),
      );
      expect(await ask(), isNull);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );
      expect(await ask(), isNull);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await ask(), isNull);
    });
  }

  test('the channel is apsira_storage/storage', () {
    expect(ChannelStorageSpace.channelName, 'apsira_storage/storage');
  });
}
