// From relay lib/data/platform/zone_channel.dart @ 09b28810, on the channel
// apsira_app/zone.
import 'package:flutter/services.dart';

/// The device's IANA time-zone name from the zone module
/// (`android/src/main/kotlin/com/apsiralabs/apsira_app/ZoneModule.kt`):
/// `TimeZone.getDefault().id` over the method channel [name].
///
/// `ApsiraAppPlugin` sets the channel's handler on the UI engine only, when
/// an activity attaches, so only the UI isolate calls it; background entry
/// points take the zone from their job's input (`SystemClock.useZone`).
final class ZoneChannel {
  const ZoneChannel([this._channel = const MethodChannel(name)]);

  /// The channel's name, as `ZoneModule.kt` registers it.
  static const name = 'apsira_app/zone';

  final MethodChannel _channel;

  /// The zone ID, such as `Europe/Madrid`. Throws when the engine has no
  /// zone module (`MissingPluginException`) or it answers no ID
  /// ([StateError]).
  Future<String> zoneId() async {
    final id = await _channel.invokeMethod<String>('zoneId');
    if (id == null || id.isEmpty) {
      throw StateError('$name answered no zone ID');
    }
    return id;
  }
}
