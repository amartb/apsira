// From lyceum test/critical/layout_check_controls_test.dart @ 9f4ff27, with
// viaticum test/critical/layout_large_text_test.dart @ 78d38e0's controls
// (text past the edge, a sideways scroll view, its scaler table tests).
//
// The controls that keep the large-text layout check honest: every
// `LayoutIssueKind` has a fixture that plants its defect and must be caught
// with that kind, and a fixture without it that must pass every case. A
// change to lib/src/layout_check.dart that stops catching a control, or
// starts failing a sound fixture, turns this file red.
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the matrix is 4 scales x 2 languages x 2 surfaces x 2 themes', () {
    expect(layoutScales, [1.0, 1.3, 1.5, 2.0]);
    expect(layoutLocales, const [Locale('en'), Locale('es')]);
    expect(layoutSurfaces, const [Size(390, 844), Size(360, 780)]);
    expect(layoutCases(), hasLength(32));
    expect(layoutCases(brightnesses: const [Brightness.dark]), hasLength(16));
  });

  testWidgets('the check lays text out in the bundled fonts', (tester) async {
    await loadBundledFontsOnce(tester);
    // The test font draws every glyph one em wide; apsira_ui's body font
    // draws a narrow "i".
    final style = const LayoutHost()
        .theme(Brightness.dark)
        .textTheme
        .bodyMedium!
        .copyWith(fontSize: 14);
    final painter = TextPainter(
      text: TextSpan(text: 'iiii', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThan(4 * 14 * 0.5));
    painter.dispose();
  });

  testWidgets('control: a sound column passes every case', (tester) async {
    await expectLayoutSound(tester, () => const _SoundColumn());
  });

  group('exception', () {
    testWidgets('control: an overflowing Row fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: Row(
            children: [
              Text('Character', softWrap: false),
              Text('Isabel de Bobadilla, governor of Cuba', softWrap: false),
            ],
          ),
        ),
        LayoutIssueKind.exception,
      );
    });

    testWidgets('control: the same Row with a wrapping second text passes', (
      tester,
    ) async {
      await expectLayoutSound(
        tester,
        () => const _Planted(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Character '),
              Expanded(child: Text('Isabel de Bobadilla, governor of Cuba')),
            ],
          ),
        ),
      );
    });
  });

  group('clipped', () {
    testWidgets('control: a single-line clamp fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: Text(
            'The governor sails from Sanlúcar with the fleet of the Indies',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        LayoutIssueKind.clipped,
      );
    });

    testWidgets(
      'control: a list cut by its scroll views inside another clip passes',
      (tester) async {
        // A row half scrolled out of a vertical list, and a chip scrolled out
        // of a horizontal one, are cut by their scroll views, not by the clip
        // (a navigator, a page view) around them.
        await expectLayoutSound(
          tester,
          () => Scaffold(
            body: SafeArea(
              child: ClipRect(
                child: Column(
                  children: [
                    SizedBox(
                      height: 96,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final tab in _tabs)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(tab),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _List([
                        for (var i = 0; i < 40; i++) 'Chapter $i, the archive',
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    testWidgets(
      'control: the hidden children of an IndexedStack are not text',
      (tester) async {
        // A dropdown keeps every item in an IndexedStack to size itself; only
        // the selected one is painted.
        await expectLayoutSound(
          tester,
          () => const _Planted(
            child: IndexedStack(
              index: 1,
              children: [
                Text('Protagonist'),
                Text('Secondary'),
                Text('Mentioned only'),
              ],
            ),
          ),
        );
      },
    );
  });

  group('outsideBox', () {
    testWidgets('control: a fixed-height pill fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: Wrap(children: [_Pill('Awaiting reply', fixedHeight: 24)]),
        ),
        LayoutIssueKind.outsideBox,
      );
    });

    testWidgets('control: a pill whose height is a minimum passes', (
      tester,
    ) async {
      await expectLayoutSound(
        tester,
        () => const _Planted(child: Wrap(children: [_Pill('Awaiting reply')])),
      );
    });
  });

  group('outsideScreen', () {
    testWidgets('control: text past the edge fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: Text(
            'Archivo Histórico Provincial, sección de protocolos notariales',
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        LayoutIssueKind.outsideScreen,
      );
    });

    testWidgets('control: the same text wrapping passes', (tester) async {
      await expectLayoutSound(
        tester,
        () => const _Planted(
          child: Text(
            'Archivo Histórico Provincial, sección de protocolos notariales',
          ),
        ),
      );
    });
  });

  group('overlap', () {
    testWidgets('control: an overlapping Stack fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: Stack(
            children: [
              Text('Chapter 12'),
              Positioned(left: 8, top: 4, child: Text('Draft')),
            ],
          ),
        ),
        LayoutIssueKind.overlap,
      );
    });

    testWidgets('control: an overlap below the fold fails', (tester) async {
      // Text is cut to its scroll view before it is measured: only stepping
      // the scroll view through its extent sees this one.
      await _expectCaught(
        tester,
        () => _Planted(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1400),
              const Text('Timeline'),
              Transform.translate(
                offset: const Offset(0, -16),
                child: const Text('The fleet reaches Havana'),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
        LayoutIssueKind.overlap,
      );
    });

    testWidgets(
      'control: a floating button over a list that cannot scroll clear fails',
      (tester) async {
        // A short list with its row at the bottom, under the button: no
        // scrolling carries it out from under.
        await _expectCaught(
          tester,
          () => const _FloatingOver(planted: true),
          LayoutIssueKind.overlap,
        );
      },
    );

    testWidgets('control: a count badge over its icon passes', (tester) async {
      // A Badge draws its label over its child on purpose (a drawer's Inbox
      // count); text beside it still counts.
      await expectLayoutSound(
        tester,
        () => const _Planted(
          child: Row(
            children: [
              Badge(label: Text('3'), child: Icon(Icons.inbox_outlined)),
              SizedBox(width: 24),
              Expanded(child: Text('Inbox')),
            ],
          ),
        ),
      );
    });

    testWidgets(
      'control: a button floating over a list it can scroll clear passes',
      (tester) async {
        await expectLayoutSound(tester, () => const _FloatingOver());
      },
    );
  });

  group('squeezed', () {
    testWidgets('control: a squeezed list fails', (tester) async {
      await _expectCaught(
        tester,
        () => const _Planted(
          child: SizedBox(
            height: 4,
            child: _List(['Havana', 'Sanlúcar de Barrameda', 'Seville']),
          ),
        ),
        LayoutIssueKind.squeezed,
      );
    });

    testWidgets('control: a list taller than its line passes', (tester) async {
      await expectLayoutSound(
        tester,
        () => const _Planted(
          child: SizedBox(
            height: 160,
            child: _List(['Havana', 'Sanlúcar de Barrameda', 'Seville']),
          ),
        ),
      );
    });
  });

  group('sideways', () {
    Widget sideways() => const _Planted(
      child: SizedBox(height: 120, child: _Row(['Must see', 'If time'])),
    );

    testWidgets('control: a sideways scroll view fails where the app forbids '
        'one', (tester) async {
      await _expectCaught(
        tester,
        sideways,
        LayoutIssueKind.sideways,
        host: const LayoutHost(forbidSideways: true),
      );
    });

    testWidgets('control: a sideways scroll view passes by default', (
      tester,
    ) async {
      await expectLayoutSound(tester, sideways);
    });
  });
}

/// Runs [screen] through `expectLayoutSound` and expects it to fail with an
/// issue of [kind] in at least one case.
Future<void> _expectCaught(
  WidgetTester tester,
  Widget Function() screen,
  LayoutIssueKind kind, {
  LayoutHost host = const LayoutHost(),
}) async {
  TestFailure? failure;
  try {
    await expectLayoutSound(tester, screen, host: host);
  } on TestFailure catch (e) {
    failure = e;
  }
  expect(failure, isNotNull, reason: 'the planted defect was not caught');
  expect(failure!.message, contains('[${kind.name}]'));
}

/// A control's screen: the planted [child] inside a scrolling column, so
/// that only the defect itself is wrong.
class _Planted extends StatelessWidget {
  const _Planted({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const Text('Control'), child],
        ),
      ),
    ),
  );
}

const _tabs = [
  'Outline of the novel',
  'Characters and groups',
  'Locations and settings',
  'Advanced tools',
];

/// A vertical list of [items].
class _List extends StatelessWidget {
  const _List(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(item),
        ),
    ],
  );
}

/// A horizontal list of pills.
class _Row extends StatelessWidget {
  const _Row(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => ListView(
    scrollDirection: Axis.horizontal,
    children: [for (final item in items) _Pill(item)],
  );
}

/// A long list of right-aligned rows under a floating button, with room
/// below the last row; [planted]: one row at the bottom of a list too short
/// to scroll, under the button.
class _FloatingOver extends StatelessWidget {
  const _FloatingOver({this.planted = false});

  final bool planted;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      label: const Text('Capture'),
    ),
    body: planted
        ? ListView(
            reverse: true,
            children: const [
              Text(
                'The fleet reaches Havana. The fleet reaches Havana. The '
                'fleet reaches Havana. The fleet reaches Havana.',
                textAlign: TextAlign.end,
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (var i = 0; i < 40; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Chapter $i, the archive',
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
  );
}

/// A pill: grows with its text unless [fixedHeight] plants the defect.
class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.fixedHeight});

  final String label;
  final double? fixedHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: fixedHeight,
      constraints: fixedHeight == null
          ? const BoxConstraints(minHeight: 28)
          : null,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// A screen that follows the large-text rules: a title that wraps, a
/// bordered card of rows whose height is a minimum, pills that wrap, a
/// button that grows, and long text, in one list that scrolls as a whole.
class _SoundColumn extends StatelessWidget {
  const _SoundColumn();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const note =
        'Synthetic note for the layout test: a long character description '
        'that wraps over several lines at every text scale and in both '
        'languages, as notes and summaries do.';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('CHARACTERS', style: theme.textTheme.labelSmall),
            Text(
              'Isabel de Bobadilla, governor of Cuba',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  ListTile(
                    title: Text('Role'),
                    subtitle: Text('Protagonist, regent of the island'),
                  ),
                  ListTile(
                    title: Text('First appearance'),
                    subtitle: Text('Chapter 3, The fleet of the Indies'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill('Awaiting reply'),
                _Pill('Accepted'),
                _Pill('Revise and resubmit'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {},
              child: const Text('Add a relationship to another character'),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(note, style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
