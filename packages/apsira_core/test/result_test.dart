// From relay test/core/result_test.dart @ 5f606e9
import 'package:apsira_core/apsira_core.dart';
import 'package:test/test.dart';

// Architecture §9.1 and §9.2: expected failures are values, never thrown;
// each carries a stable code that keys its localised message.
void main() {
  const notFound = Failure('noteNotFound');
  const unavailable = Failure(
    'backupFolderUnavailable',
    nextStep: 'chooseBackupFolder',
  );

  group('Failure', () {
    test('is identified by its stable code and next step', () {
      expect(const Failure('noteNotFound'), notFound);
      expect(const Failure('noteNotFound').hashCode, notFound.hashCode);
      expect(notFound, isNot(const Failure('nameConflict')));
      expect(
        unavailable,
        isNot(const Failure('backupFolderUnavailable')),
        reason: 'the next step is part of the value',
      );
      expect(unavailable.nextStep, 'chooseBackupFolder');
      expect(notFound.nextStep, isNull);
    });

    test('prints only its codes, never free text (D-050)', () {
      expect(notFound.toString(), 'Failure(noteNotFound)');
      expect(
        unavailable.toString(),
        'Failure(backupFolderUnavailable → chooseBackupFolder)',
      );
    });

    test('accepts only identifier-shaped codes usable as message keys', () {
      expect(Failure.isValidCode('backupFolderUnavailable'), isTrue);
      expect(Failure.isValidCode('diskFull2'), isTrue);
      expect(Failure.isValidCode(''), isFalse);
      expect(Failure.isValidCode('Backup'), isFalse);
      expect(Failure.isValidCode('disk full'), isFalse);
      expect(Failure.isValidCode('disk-full'), isFalse);
    });
  });

  group('Result', () {
    const Result<int, Failure> ok = Ok(2);
    const Result<int, Failure> err = Err(notFound);

    test('Ok and Err report their side', () {
      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(err.isOk, isFalse);
      expect(err.isErr, isTrue);
      expect(ok.valueOrNull, 2);
      expect(ok.failureOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, notFound);
    });

    test('the named constructors build the same values', () {
      expect(const Result<int, Failure>.ok(2), ok);
      expect(const Result<int, Failure>.err(notFound), err);
    });

    test('is exhaustive under pattern matching', () {
      String describe(Result<int, Failure> r) => switch (r) {
        Ok(:final value) => 'ok $value',
        Err(:final failure) => 'err ${failure.code}',
      };
      expect(describe(ok), 'ok 2');
      expect(describe(err), 'err noteNotFound');
    });

    test('fold and getOrElse pick the matching branch', () {
      expect(ok.fold((v) => v * 10, (f) => -1), 20);
      expect(err.fold((v) => v * 10, (f) => -1), -1);
      expect(ok.getOrElse((f) => 0), 2);
      expect(err.getOrElse((f) => 0), 0);
    });

    test('map and andThen transform Ok and pass Err through', () {
      expect(ok.map((v) => '$v'), const Ok<String, Failure>('2'));
      expect(err.map((v) => '$v'), const Err<String, Failure>(notFound));
      expect(
        ok.andThen((v) => Err<int, Failure>(unavailable)),
        const Err<int, Failure>(unavailable),
      );
      expect(
        ok.andThen((v) => Ok<int, Failure>(v + 1)),
        const Ok<int, Failure>(3),
      );
      var called = false;
      final r = err.andThen((v) {
        called = true;
        return Ok<int, Failure>(v);
      });
      expect(called, isFalse, reason: 'an Err short-circuits');
      expect(r, const Err<int, Failure>(notFound));
    });

    test('mapFailure transforms Err and passes Ok through', () {
      Failure wrap(Failure f) => Failure('wrapped${f.code}');
      expect(
        err.mapFailure(wrap),
        const Err<int, Failure>(Failure('wrappednoteNotFound')),
      );
      expect(ok.mapFailure(wrap), const Ok<int, Failure>(2));
    });

    test('values compare by content and print without payload text', () {
      expect(const Ok<int, Failure>(2), const Ok<int, Failure>(2));
      expect(
        const Ok<int, Failure>(2).hashCode,
        const Ok<int, Failure>(2).hashCode,
      );
      expect(const Ok<int, Failure>(2), isNot(const Ok<int, Failure>(3)));
      expect(err.toString(), 'Err(Failure(noteNotFound))');
      expect(
        ok.toString(),
        'Ok(int)',
        reason: 'the value may be note content (D-050)',
      );
    });
  });
}
