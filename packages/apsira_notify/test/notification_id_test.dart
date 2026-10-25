// notificationIdFor (D-APK-021): RELAY's FNV-1a over UTF-16 code units,
// 31 bits; from viaticum test/data/platform/local_notifier_test.dart @
// 78d38e0's id case, and its UTF-8 notificationIntId reproduced here to show
// both give every ASCII key the same id.
import 'dart:convert';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter_test/flutter_test.dart';

/// viaticum lib/data/platform/local_notifier.dart @ 78d38e0.
int _viaticumIntId(String notificationId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(notificationId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

void main() {
  test('notification IDs are stable, positive and 31-bit', () {
    for (final id in ['', 'r-1', '0190a5f2-7c3e-7b1a-9f00-5c2d1e8a4b6f']) {
      final n = notificationIdFor(id);
      expect(n, notificationIdFor(id));
      expect(n, inInclusiveRange(0, 0x7fffffff));
    }
    expect(notificationIdFor('r-1'), isNot(notificationIdFor('r-2')));
  });

  test('the FNV-1a offset basis for the empty key, as RELAY computes it', () {
    expect(notificationIdFor(''), 0x811c9dc5 & 0x7fffffff);
  });

  test('VIATICUM\'s ASCII ids keep their notification id', () {
    for (final id in [
      'r-1',
      'order_deadline:orders:o1:2026-11-03',
      'reminder:credential_expiry:c-1',
      'calendar:k-7:2026-10-24',
    ]) {
      expect(notificationIdFor(id), _viaticumIntId(id), reason: id);
    }
  });
}
