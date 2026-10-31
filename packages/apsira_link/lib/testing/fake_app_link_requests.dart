// The AppLinkRequests fake for app and package tests (K2-02d).
import 'dart:async';

import '../src/app_link_requests.dart';

/// An [AppLinkRequests] a test drives: [offer] reaches a listener of
/// [offers] at once, else waits for [takePendingOffer], as the channel does.
final class FakeAppLinkRequests implements AppLinkRequests {
  final StreamController<RestoreOffer> _offers =
      StreamController<RestoreOffer>.broadcast();

  /// The offer waiting to be taken.
  RestoreOffer? pending;

  /// APSIRA offers [restore]; the newest replaces a waiting one.
  void offer(RestoreOffer restore) {
    if (_offers.hasListener) {
      pending = null;
      _offers.add(restore);
    } else {
      pending = restore;
    }
  }

  @override
  Stream<RestoreOffer> get offers => _offers.stream;

  @override
  Future<RestoreOffer?> takePendingOffer() async {
    final taken = pending;
    pending = null;
    return taken;
  }

  /// Closes [offers].
  Future<void> close() => _offers.close();
}
