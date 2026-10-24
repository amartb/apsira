// From lyceum test/support/layout/layout_check.dart @ 9f4ff27 (the superset),
// with viaticum test/support/layout/layout_check.dart @ 78d38e0's `sideways`
// check, behind LayoutHost.forbidSideways.

/// The large-text layout check: `expectLayoutSound` renders a screen over
/// the matrix of text scales, languages, surfaces and themes and fails on
/// what breaks under large text. VIATICUM's harness (its D-047 and addenda),
/// as LYCEUM refined it. See the package README, "Layout check".
library;

import 'dart:math' as math;

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_font_scale.dart';
import 'bundled_fonts.dart';

/// What a [LayoutIssue] found.
enum LayoutIssueKind {
  /// A layout or build exception: a `RenderFlex` overflow and the like.
  exception,

  /// Text cut: by an ellipsis or line limit, by its own box, or by an
  /// ancestor that clips (a scroll view only across its scroll direction).
  clipped,

  /// Visible text outside the decorated box that draws it: a pill, button,
  /// card or tile.
  outsideBox,

  /// Visible text outside the screen.
  outsideScreen,

  /// Two pieces of visible text over each other on the same route.
  overlap,

  /// A scroll view smaller than one line of its content.
  squeezed,

  /// A scroll view that scrolls sideways, where the app forbids one
  /// ([LayoutHost.forbidSideways]; VIATICUM's `08` §3 rule 7).
  sideways,
}

/// One defect, found in one [LayoutCase].
@immutable
class LayoutIssue {
  const LayoutIssue(this.kind, this.detail);

  final LayoutIssueKind kind;

  /// What and where, naming the text by its first characters.
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is LayoutIssue && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => '[${kind.name}] $detail';
}

/// The system font scales measured: Android 14 allows up to 200 %.
const List<double> layoutScales = [1.0, 1.3, 1.5, 2.0];

/// Both UI languages.
const List<Locale> layoutLocales = [Locale('en'), Locale('es')];

/// A common phone and a small one, in logical pixels.
const List<Size> layoutSurfaces = [Size(390, 844), Size(360, 780)];

/// Both themes; dark is the apps' default.
const List<Brightness> layoutBrightnesses = [Brightness.dark, Brightness.light];

/// One render of the matrix.
@immutable
class LayoutCase {
  const LayoutCase(this.scale, this.locale, this.surface, this.brightness);

  /// The system font scale ([AndroidFontScaler]).
  final double scale;
  final Locale locale;
  final Size surface;
  final Brightness brightness;

  @override
  bool operator ==(Object other) =>
      other is LayoutCase &&
      other.scale == scale &&
      other.locale == locale &&
      other.surface == surface &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(scale, locale, surface, brightness);

  @override
  String toString() =>
      '${brightness.name} · ${locale.languageCode} · $scale× · '
      '${surface.width.round()}×${surface.height.round()}';
}

/// The matrix: every scale × language × surface in each of [brightnesses]
/// (32 cases with both themes).
List<LayoutCase> layoutCases({
  List<Brightness> brightnesses = layoutBrightnesses,
}) => [
  for (final brightness in brightnesses)
    for (final scale in layoutScales)
      for (final locale in layoutLocales)
        for (final surface in layoutSurfaces)
          LayoutCase(scale, locale, surface, brightness),
];

/// The app around a screen: its theme for a brightness, the localisations a
/// language is rendered with, and the app's own layout rules. The layout
/// check, the golden matrix and `pumpApsira` all render through one.
///
/// Flutter's defaults render every language in English: a suite of real
/// screens passes the app's delegates and locales, so the Spanish cases
/// lay Spanish out. The default theme is apsira_ui's.
@immutable
class LayoutHost {
  const LayoutHost({
    this.theme = _apsiraTheme,
    this.localizationsDelegates = const [],
    this.supportedLocales = const [Locale('en', 'US')],
    this.forbidSideways = false,
  });

  final ThemeData Function(Brightness brightness) theme;
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;
  final List<Locale> supportedLocales;

  /// Whether a scroll view that scrolls sideways is an issue
  /// ([LayoutIssueKind.sideways]): VIATICUM forbids one, RELAY and LYCEUM
  /// do not.
  final bool forbidSideways;
}

ThemeData _apsiraTheme(Brightness brightness) => switch (brightness) {
  Brightness.dark => ApsiraThemeData.dark,
  Brightness.light => ApsiraThemeData.light,
};

/// Renders [screen] (built fresh for each case) in every [layoutCases] case
/// and fails, naming each case and issue, unless none has a [LayoutIssue].
Future<void> expectLayoutSound(
  WidgetTester tester,
  Widget Function() screen, {
  List<Brightness> brightnesses = layoutBrightnesses,
  LayoutHost host = const LayoutHost(),
}) async {
  final cases = layoutCases(brightnesses: brightnesses);
  final failed = <String>[];
  for (final c in cases) {
    final issues = await layoutIssues(tester, screen, c, host: host);
    if (issues.isNotEmpty) {
      failed.add('$c\n${issues.map((i) => '  $i').join('\n')}');
    }
  }
  await unmountAndFlush(tester);
  if (failed.isNotEmpty) {
    fail(
      'Layout not sound in ${failed.length} of ${cases.length} cases '
      '(apsira_test README, "Layout check"):\n${failed.join('\n')}',
    );
  }
}

/// Renders [screen] in case [c] and returns every issue found, stepping
/// each vertical scroll view through its whole extent and measuring at each
/// stop: text is clipped to its scroll view, so one measurement sees only
/// the first screenful.
Future<List<LayoutIssue>> layoutIssues(
  WidgetTester tester,
  Widget Function() screen,
  LayoutCase c, {
  LayoutHost host = const LayoutHost(),
}) async {
  await loadBundledFontsOnce(tester);
  final issues = <LayoutIssue>{};
  final errors = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    tester.view
      ..devicePixelRatio = _pixelRatio
      ..physicalSize = c.surface * _pixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(c, screen, host));
    await tester.pumpAndSettle();
    issues.addAll(_measure(c.surface, host));
    var stops = 1;
    while (_step()) {
      await tester.pump();
      issues.addAll(_measure(c.surface, host));
      if (++stops > _maxStops) {
        issues.add(
          const LayoutIssue(
            LayoutIssueKind.exception,
            'scroll stepping did not reach the end',
          ),
        );
        break;
      }
    }
  } finally {
    FlutterError.onError = original;
  }
  return [
    for (final e in errors)
      LayoutIssue(
        LayoutIssueKind.exception,
        e.exceptionAsString().split('\n').first,
      ),
    ...issues,
  ];
}

const double _pixelRatio = 3;
const int _maxStops = 400;

/// Tolerance for the screen and clip edges, and for drawn boxes.
const double _edge = 0.5;
const double _boxEdge = 1;

Widget _app(LayoutCase c, Widget Function() screen, LayoutHost host) =>
    MaterialApp(
      key: ValueKey(c),
      debugShowCheckedModeBanner: false,
      theme: host.theme(c.brightness),
      locale: c.locale,
      localizationsDelegates: host.localizationsDelegates,
      supportedLocales: host.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: AndroidFontScaler(c.scale)),
        child: child!,
      ),
      home: screen(),
    );

/// Every scroll view in the tree, by its viewport render object.
Map<RenderBox, ScrollableState> _scrollViews() => {
  for (final e in find.byType(Scrollable, skipOffstage: false).evaluate())
    ?_viewportOf(e.renderObject):
        (e as StatefulElement).state as ScrollableState,
};

/// The viewport a [Scrollable] scrolls; null for a text field's own
/// scrolling, which is not a viewport of content.
RenderBox? _viewportOf(RenderObject? root) {
  if (root == null || root is RenderEditable) return null;
  if (root is RenderBox && root is RenderAbstractViewport) return root;
  RenderBox? found;
  root.visitChildren((child) => found ??= _viewportOf(child));
  return found;
}

/// Moves every vertical scroll view not yet at its end down by most of a
/// screenful; false when all are at their end.
bool _step() {
  var moved = false;
  for (final s in _scrollViews().values) {
    final p = s.position;
    if (p.axis != Axis.vertical || !p.hasContentDimensions || !p.hasPixels) {
      continue;
    }
    if (p.pixels < p.maxScrollExtent - _edge) {
      final step = math.max(p.viewportDimension * 0.75, 1);
      p.jumpTo(math.min(p.pixels + step, p.maxScrollExtent));
      moved = true;
    }
  }
  return moved;
}

/// One piece of visible text.
class _Text {
  _Text(
    this.element,
    this.paragraph,
    this.label,
    this.lines,
    this.route,
    this.scroll,
  );

  final Element element;
  final RenderParagraph paragraph;
  final String label;

  /// Its line boxes on screen, cut to what is visible.
  final List<Rect> lines;
  final ModalRoute<Object?>? route;

  /// The nearest vertical scroll view it scrolls in, if any.
  final (RenderBox, ScrollPosition)? scroll;
}

/// Measures the tree as it is painted now.
List<LayoutIssue> _measure(Size surface, LayoutHost host) {
  final out = <LayoutIssue>[];
  final screen = Offset.zero & surface;
  final scrollViews = _scrollViews();

  for (final MapEntry(key: viewport, value: state) in scrollViews.entries) {
    if (!_painted(viewport)) continue;
    final label = _label(_paragraphsUnder(viewport).firstOrNull);
    if (host.forbidSideways && state.position.axis == Axis.horizontal) {
      out.add(
        LayoutIssue(
          LayoutIssueKind.sideways,
          'a scroll view scrolls sideways ("$label")',
        ),
      );
    }
    final line = _paragraphsUnder(viewport)
        .expand(_lineRects)
        .fold(0.0, (m, r) => math.max(m, r.height));
    if (viewport.size.height + _edge < line) {
      out.add(
        LayoutIssue(
          LayoutIssueKind.squeezed,
          'a scroll view is shorter than one line of its content ("$label")',
        ),
      );
    }
  }

  final texts = <_Text>[];
  for (final element in find.byType(RichText, skipOffstage: false).evaluate()) {
    final p = element.renderObject;
    if (p is! RenderParagraph || !p.attached || !p.hasSize) continue;
    final label = _label(p);
    if (label.isEmpty || !_painted(p)) continue;
    final local = _lineRects(p).toList();
    if (local.isEmpty) continue;
    final ownBox = local.reduce((a, b) => a.expandToInclude(b));

    if (p.didExceedMaxLines) {
      out.add(
        LayoutIssue(LayoutIssueKind.clipped, '"$label" cut by a line limit'),
      );
    } else if (p.overflow != TextOverflow.visible &&
        // The paragraph's own test for clipping its text (visual overflow).
        (p.textSize.width > p.size.width + _edge ||
            p.textSize.height > p.size.height + _edge)) {
      out.add(
        LayoutIssue(LayoutIssueKind.clipped, '"$label" cut by its own box'),
      );
    }

    final toScreen = p.getTransformTo(null);
    final full = MatrixUtils.transformRect(toScreen, ownBox);
    var visible = full;
    var cut = false;
    RenderObject child = p;
    for (var parent = p.parent; parent != null; parent = parent.parent) {
      final clip = parent.describeApproximatePaintClip(child);
      child = parent;
      if (clip == null) continue;
      final g = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
      final axis = scrollViews[parent]?.position.axis;
      // Measured against what the clips below left visible: a scroll view
      // cuts its text along its axis on purpose, and a clip around the
      // scroll view (a navigator, a page view) does not cut it again.
      final escapes = switch (axis) {
        null => !_inside(visible, g, _edge),
        Axis.vertical =>
          visible.left < g.left - _edge || visible.right > g.right + _edge,
        Axis.horizontal =>
          visible.top < g.top - _edge || visible.bottom > g.bottom + _edge,
      };
      if (escapes && !cut) {
        cut = true;
        out.add(
          LayoutIssue(
            LayoutIssueKind.clipped,
            '"$label" cut by ${parent.runtimeType}',
          ),
        );
      }
      visible = visible.intersect(g);
    }
    if (visible.width <= 1 || visible.height <= 1) continue;

    if (!_inside(visible, screen, _edge)) {
      out.add(
        LayoutIssue(
          LayoutIssueKind.outsideScreen,
          '"$label" leaves the screen',
        ),
      );
    }
    final box = _drawnBox(p);
    if (box != null) {
      final b = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (!_inside(visible, b, _boxEdge)) {
        out.add(
          LayoutIssue(
            LayoutIssueKind.outsideBox,
            '"$label" leaves its ${box.runtimeType}',
          ),
        );
      }
    }
    texts.add(
      _Text(
        element,
        p,
        label,
        [
          for (final r in local)
            if (MatrixUtils.transformRect(toScreen, r).intersect(visible)
                case final v when v.width > 0 && v.height > 0)
              v,
        ],
        ModalRoute.of(element),
        _verticalScroll(p, scrollViews),
      ),
    );
  }

  for (var i = 0; i < texts.length; i++) {
    for (var j = i + 1; j < texts.length; j++) {
      final a = texts[i];
      final b = texts[j];
      // A sheet or dialog is drawn over its route on purpose; text inside
      // text (a WidgetSpan) is one piece.
      if (a.route != b.route) continue;
      if (_isAncestor(a.paragraph, b.paragraph) ||
          _isAncestor(b.paragraph, a.paragraph)) {
        continue;
      }
      // A Badge draws its label over its child on purpose (a count on an
      // icon).
      final badge = a.element.findAncestorWidgetOfExactType<Badge>();
      if (badge != null &&
          identical(badge, b.element.findAncestorWidgetOfExactType<Badge>())) {
        continue;
      }
      final hit = a.lines.any(
        (ra) => b.lines.any((rb) {
          final o = ra.intersect(rb);
          return o.width > 1 &&
              o.height > 2 &&
              !_scrollsClear(a, ra, b, rb) &&
              !_scrollsClear(b, rb, a, ra);
        }),
      );
      if (hit) {
        out.add(
          LayoutIssue(
            LayoutIssueKind.overlap,
            '"${a.label}" and "${b.label}" overlap',
          ),
        );
      }
    }
  }
  return out;
}

/// The vertical scroll view nearest above [p], with its position.
(RenderBox, ScrollPosition)? _verticalScroll(
  RenderParagraph p,
  Map<RenderBox, ScrollableState> scrollViews,
) {
  for (RenderObject? a = p.parent; a != null; a = a.parent) {
    final position = scrollViews[a]?.position;
    if (position != null && position.axis == Axis.vertical) {
      return (a as RenderBox, position);
    }
  }
  return null;
}

/// Whether [moving]'s line [rm] scrolls out from under [fixed]'s line [rf]:
/// [fixed] floats over [moving]'s scroll view (a floating button over a
/// list), and that scroll view has room left to carry the line clear, up or
/// down, while it stays inside the scroll view. At the end of the list there
/// is no room, and the overlap counts.
bool _scrollsClear(_Text moving, Rect rm, _Text fixed, Rect rf) {
  final scroll = moving.scroll;
  if (scroll == null) return false;
  final (viewport, p) = scroll;
  if (_isAncestor(viewport, fixed.paragraph)) return false;
  if (!p.hasContentDimensions || !p.hasPixels) return false;
  final view = MatrixUtils.transformRect(
    viewport.getTransformTo(null),
    Offset.zero & viewport.size,
  );
  final up = rm.bottom - rf.top;
  final down = rf.bottom - rm.top;
  return (up <= p.maxScrollExtent - p.pixels + _edge &&
          rm.top - up >= view.top - _edge) ||
      (down <= p.pixels - p.minScrollExtent + _edge &&
          rm.bottom + down <= view.bottom + _edge);
}

/// The paragraph's glyph boxes in its own coordinates, word by word: the
/// whitespace a soft line break leaves hanging past the width is not text
/// on screen.
Iterable<Rect> _lineRects(RenderParagraph p) {
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  return [
    for (final word in RegExp(r'\S+').allMatches(text))
      ...p.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      ),
  ].map((b) => b.toRect()).where((r) => r.width >= 1 && r.height >= 1);
}

List<RenderParagraph> _paragraphsUnder(RenderObject root) {
  final out = <RenderParagraph>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize) out.add(o);
    o.visitChildren(visit);
  }

  root.visitChildren(visit);
  return out;
}

String _label(RenderParagraph? p) {
  if (p == null) return '';
  final text = p.text
      .toPlainText(includeSemanticsLabels: false)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length > 40 ? text.substring(0, 40) : text;
}

/// Whether every ancestor paints [o] (not offstage, not fully transparent,
/// not a sliver child outside the viewport, not a hidden child of an
/// `IndexedStack`, which does not say so through `paintsChild`).
bool _painted(RenderObject o) {
  RenderObject child = o;
  for (var parent = o.parent; parent != null; parent = parent.parent) {
    if (!parent.paintsChild(child)) return false;
    if (parent is RenderIndexedStack) {
      final children = parent.getChildrenAsList();
      final index = parent.index;
      if (index == null ||
          index >= children.length ||
          !identical(children[index], child)) {
        return false;
      }
    }
    child = parent;
  }
  return true;
}

bool _isAncestor(RenderObject ancestor, RenderObject o) {
  for (var p = o.parent; p != null; p = p.parent) {
    if (identical(p, ancestor)) return true;
  }
  return false;
}

bool _inside(Rect inner, Rect outer, double tolerance) =>
    inner.left >= outer.left - tolerance &&
    inner.top >= outer.top - tolerance &&
    inner.right <= outer.right + tolerance &&
    inner.bottom <= outer.bottom + tolerance;

/// The nearest ancestor that visibly draws a box behind [o]: a decoration
/// with a fill or an edge, or a Material surface with a colour or a side.
RenderBox? _drawnBox(RenderObject o) {
  for (var a = o.parent; a != null; a = a.parent) {
    if (a is RenderDecoratedBox &&
        a.position == DecorationPosition.background &&
        _draws(a.decoration)) {
      return a;
    }
    if (a is RenderPhysicalShape &&
        (a.color.a > 0 ||
            switch (a.clipper) {
              ShapeBorderClipper(shape: OutlinedBorder(:final side)) =>
                side.style != BorderStyle.none,
              _ => false,
            })) {
      return a;
    }
    if (a is RenderPhysicalModel && a.color.a > 0) return a;
  }
  return null;
}

bool _draws(Decoration d) => switch (d) {
  BoxDecoration(:final color, :final border, :final gradient, :final image) =>
    (color?.a ?? 0) > 0 || border != null || gradient != null || image != null,
  ShapeDecoration(:final color, :final shape, :final gradient) =>
    (color?.a ?? 0) > 0 ||
        gradient != null ||
        (shape is OutlinedBorder && shape.side.style != BorderStyle.none),
  _ => false,
};

/// Unmounts the screen inside the test and runs what its disposal leaves: a
/// screen's providers close their database streams on zero-length timers,
/// which only a pump that elapses time runs, so none is pending when the test
/// ends.
Future<void> unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
