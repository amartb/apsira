// From relay test/core/ports_inventory_test.dart @ 09b28810 (the stub
// message names the port and its task) and viaticum
// test/core/pending_ports_test.dart @ 78d38e0 (Err(portPending) for a
// Result member; a throwing member's message starts with portPending).
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter_test/flutter_test.dart';

abstract interface class _Scanner {
  Future<Result<String?, Failure>> scan();

  int pages();
}

final class _PendingScanner extends PendingPort implements _Scanner {
  const _PendingScanner() : super('DocScanner', 'P0-13');

  @override
  Future<Result<String?, Failure>> scan() => pendingResult();

  @override
  int pages() => pending();
}

void main() {
  const stub = _PendingScanner();

  test('portPending is a valid failure code', () {
    expect(Failure.isValidCode(PendingPort.portPending.code), isTrue);
    expect(PendingPort.portPending.code, 'portPending');
  });

  test('a Result member answers Err(portPending)', () async {
    final result = await stub.scan();
    expect(
      result,
      isA<Err<String?, Failure>>().having(
        (e) => e.failure,
        'failure',
        PendingPort.portPending,
      ),
    );
  });

  test('a member that cannot carry a failure throws an UnimplementedError '
      'naming the port and where it lands', () {
    expect(stub.landsWith, 'P0-13');
    expect(
      stub.pages,
      throwsA(
        isA<UnimplementedError>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith('portPending'),
            contains('DocScanner'),
            contains('P0-13'),
          ),
        ),
      ),
    );
  });
}
