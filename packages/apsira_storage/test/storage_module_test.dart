// From relay test/data/platform/storage_module_test.dart @ 09b28810: the
// storage module (`StorageModule.kt`, VIATICUM's body on the package's
// channel) answers `freeBytes` and `appFreeBytes` on the channel the Dart
// side calls, and `ApsiraStoragePlugin` registers it on the UI engine only,
// where each app's MainActivity did (D-APK-015). The Kotlin runs on a phone
// only; here its source is held to the names the Dart side uses, and
// example/'s debug build compiles it.
import 'dart:io';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _kotlin = 'android/src/main/kotlin/com/apsiralabs/apsira_storage';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('StorageModule.kt answers freeBytes and appFreeBytes on the channel '
      'ChannelStorageSpace calls, for the external storage provider\'s '
      'trees only, in under 100 lines', () {
    final source = _read('$_kotlin/StorageModule.kt');
    expect(source.split('\n').length, lessThan(100));
    expect(source, contains('package com.apsiralabs.apsira_storage'));
    expect(source, contains('"${ChannelStorageSpace.channelName}"'));
    expect(source, contains('"freeBytes" ->'));
    expect(source, contains('call.argument<String>("uri")'));
    expect(
      source,
      contains(
        '"appFreeBytes" -> '
        'result.success(StatFs(context.filesDir.path).availableBytes)',
      ),
    );
    expect(source, contains('"com.android.externalstorage.documents"'));
    expect(
      source,
      contains('if (tree.authority != EXTERNAL_STORAGE) return null'),
    );
    expect(source, contains('DocumentsContract.getTreeDocumentId(tree)'));
    expect(source, contains('StatFs(it.path).availableBytes'));
    expect(source, contains('volume == "primary"'));
    expect(source, contains('storageVolumes'));
  });

  test('ApsiraStoragePlugin registers the module when an activity '
      'attaches, so only the UI engine has it', () {
    final source = _read('$_kotlin/ApsiraStoragePlugin.kt');
    expect(
      source,
      contains('class ApsiraStoragePlugin : FlutterPlugin, ActivityAware'),
    );
    expect(
      RegExp(
        r'override fun onAttachedToActivity\(binding: ActivityPluginBinding\) '
        r'\{\s*register\(\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('StorageModule.register(it, context)'));
    expect(
      source,
      isNot(
        contains(
          'onAttachedToEngine(binding: FlutterPlugin'
          '.FlutterPluginBinding) {\n        StorageModule',
        ),
      ),
    );
  });

  test('the pubspec names the plugin class', () {
    expect(
      _read('pubspec.yaml'),
      allOf(
        contains('package: com.apsiralabs.apsira_storage'),
        contains('pluginClass: ApsiraStoragePlugin'),
      ),
    );
  });
}
