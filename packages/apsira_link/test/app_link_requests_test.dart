import 'package:apsira_link/requests.dart';
import 'package:apsira_link/testing/fake_app_link_requests.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// requests.dart (contract app-link.md §5.4, D-034; K2-02d): the restore
// offer APSIRA leaves in the app's inbox, taken once, at start, on resume or
// when Kotlin says one is waiting; never a throw, never the backup's name in
// a toString.
const _channel = MethodChannel(ChannelAppLinkRequests.channelName);

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

/// Kotlin's push: `offer`, no arguments.
Future<void> _push() async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        ChannelAppLinkRequests.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(ChannelAppLinkRequests.offerMethod),
        ),
        (_) {},
      );
}

Map<Object?, Object?> _wire({
  Object? name = 'relay-2026-10-31T120000Z.bak',
  Object? snapshot = 's-41',
  Object? madeUtc = '2026-10-31T12:00:00Z',
  Object? size = 4096,
  Object? reason = 'new_device',
}) => {
  'name': name,
  'snapshot': snapshot,
  'made_utc': madeUtc,
  'size': size,
  'reason': reason,
};

final _offer = RestoreOffer(
  name: 'relay-2026-10-31T120000Z.bak',
  snapshot: 's-41',
  madeUtc: DateTime.utc(2026, 10, 31, 12),
  sizeBytes: 4096,
  reason: RestoreReason.newDevice,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _answer(null));

  group('RestoreOffer.fromWire', () {
    test('reads a whole offer', () {
      expect(RestoreOffer.fromWire(_wire()), _offer);
      expect(
        RestoreOffer.fromWire(_wire(reason: 'user'))?.reason,
        RestoreReason.user,
      );
    });

    test('anything malformed is no offer', () {
      for (final wire in <Object?>[
        null,
        'offer',
        _wire(name: null),
        _wire(name: ''),
        _wire(snapshot: 7),
        _wire(snapshot: ''),
        _wire(madeUtc: 'yesterday'),
        _wire(madeUtc: '2026-10-31T12:00:00'),
        _wire(size: -1),
        _wire(size: '4096'),
        _wire(reason: 'schedule'),
        _wire(reason: null),
      ]) {
        expect(RestoreOffer.fromWire(wire), isNull, reason: '$wire');
      }
    });

    test('toString never names the backup', () {
      expect(_offer.toString(), isNot(contains('relay-2026')));
      expect(_offer.toString(), isNot(contains('s-41')));
    });
  });

  group('ChannelAppLinkRequests', () {
    test('takePendingOffer asks Kotlin once and reads its answer', () async {
      final calls = <MethodCall>[];
      _answer((call) async {
        calls.add(call);
        return _wire();
      });
      expect(await ChannelAppLinkRequests().takePendingOffer(), _offer);
      expect(calls.single.method, ChannelAppLinkRequests.takeMethod);
    });

    test('no offer, a malformed one or a platform failure is null', () async {
      _answer((_) async => null);
      expect(await ChannelAppLinkRequests().takePendingOffer(), isNull);
      _answer((_) async => _wire(size: -1));
      expect(await ChannelAppLinkRequests().takePendingOffer(), isNull);
      _answer((_) async => throw PlatformException(code: 'x'));
      expect(await ChannelAppLinkRequests().takePendingOffer(), isNull);
      _answer(null);
      expect(await ChannelAppLinkRequests().takePendingOffer(), isNull);
    });

    test('a push is taken and reaches the listener', () async {
      final requests = ChannelAppLinkRequests();
      var takes = 0;
      _answer((call) async {
        takes++;
        return takes == 1 ? _wire() : null;
      });
      final seen = <RestoreOffer>[];
      final subscription = requests.offers.listen(seen.add);
      await _push();
      await pumpEventQueue();
      expect(seen, [_offer]);
      // A second push with the inbox empty emits nothing.
      await _push();
      await pumpEventQueue();
      expect(seen, [_offer]);
      expect(takes, 2);
      await subscription.cancel();
    });

    test('a push with no listener leaves the offer in the inbox', () async {
      final requests = ChannelAppLinkRequests();
      var takes = 0;
      _answer((call) async {
        takes++;
        return _wire();
      });
      final subscription = requests.offers.listen((_) {});
      await subscription.cancel();
      await _push();
      await pumpEventQueue();
      expect(takes, 0);
    });
  });

  group('FakeAppLinkRequests', () {
    test('an offer reaches a listener, else waits to be taken once', () async {
      final fake = FakeAppLinkRequests();
      expect(await fake.takePendingOffer(), isNull);
      fake.offer(_offer);
      expect(await fake.takePendingOffer(), _offer);
      expect(await fake.takePendingOffer(), isNull);

      final seen = <RestoreOffer>[];
      final subscription = fake.offers.listen(seen.add);
      fake.offer(_offer);
      await pumpEventQueue();
      expect(seen, [_offer]);
      expect(await fake.takePendingOffer(), isNull);
      await subscription.cancel();
      await fake.close();
    });
  });
}
