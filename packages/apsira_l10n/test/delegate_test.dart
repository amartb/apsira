import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [Localizations] for [locale] and returns what `of()` finds there.
Future<ApsiraL10n> _load(WidgetTester tester, Locale locale) async {
  late ApsiraL10n found;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [
        ApsiraL10n.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Builder(
        builder: (context) {
          found = ApsiraL10n.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return found;
}

void main() {
  test('supportedLocales are en and es', () {
    expect(ApsiraL10n.supportedLocales, const [Locale('en'), Locale('es')]);
  });

  testWidgets('the delegate loads Spanish', (tester) async {
    final l10n = await _load(tester, const Locale('es'));
    expect(l10n, isA<ApsiraL10nEs>());
    expect(l10n.commonDelete, 'Eliminar');
  });

  testWidgets('the delegate loads English', (tester) async {
    final l10n = await _load(tester, const Locale('en', 'GB'));
    expect(l10n, isA<ApsiraL10nEn>());
    expect(l10n.commonDelete, 'Delete');
  });

  testWidgets('a regional Spanish loads Spanish', (tester) async {
    final l10n = await _load(tester, const Locale('es', 'MX'));
    expect(l10n.commonAdd, 'Añadir');
  });

  test('any other language loads English', () async {
    expect(ApsiraL10n.delegate.isSupported(const Locale('fr')), isTrue);
    expect(ApsiraL10n.delegate.isSupported(const Locale('es')), isTrue);
    final l10n = await ApsiraL10n.delegate.load(const Locale('fr'));
    expect(l10n, isA<ApsiraL10nEn>());
  });

  testWidgets('a French locale gets English', (tester) async {
    final l10n = await _load(tester, const Locale('fr'));
    expect(l10n, isA<ApsiraL10nEn>());
    expect(l10n.commonCancel, 'Cancel');
  });

  testWidgets('of() without the delegate throws naming ApsiraL10n.delegate', (
    tester,
  ) async {
    Object? error;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            try {
              ApsiraL10n.of(context);
            } on Object catch (e) {
              error = e;
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('ApsiraL10n.delegate'));
  });

  test('the delegate never reloads', () {
    expect(ApsiraL10n.delegate.shouldReload(ApsiraL10n.delegate), isFalse);
  });
}
