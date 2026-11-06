import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/practice/practice_coach.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';

void main() {
  Widget scene({
    bool enabled = true,
    VoidCallback? tapped,
    ScrollController? scroll,
    bool target = true,
    double scale = 1,
    EdgeInsets insets = EdgeInsets.zero,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        textScaler: TextScaler.linear(scale),
        viewInsets: insets,
      ),
      child: Scaffold(
        body: PracticeCoachHost(
          presentation: PracticePresentation(
            step: PracticeStep.scoreBlueTwo,
            onExit: () {},
          ),
          enabled: enabled,
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 210),
                if (target)
                  PracticeTarget(
                    id: PracticeTargetId.blueTwo,
                    active: true,
                    child: SizedBox(
                      width: 120,
                      height: 60,
                      child: FilledButton(
                        key: const Key('real-target'),
                        onPressed: tapped ?? () {},
                        child: const Text('+2'),
                      ),
                    ),
                  ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('coach preserves child geometry and spotlight passes real taps', (
    tester,
  ) async {
    await tester.pumpWidget(scene(enabled: false));
    await tester.pumpAndSettle();
    final ordinary = tester.getRect(find.byKey(const Key('real-target')));
    var taps = 0;
    await tester.pumpWidget(scene(tapped: () => taps++));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('real-target'))), ordinary);
    expect(find.byKey(const Key('practice-coach-mask')), findsOneWidget);
    expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const Key('practice-coach')))
          .overlaps(ordinary),
      isFalse,
    );
    await tester.tap(find.byKey(const Key('real-target')));
    expect(taps, 1);
  });

  testWidgets('arrow follows scrolling and disappears when target is absent', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(scene(scroll: scroll));
    await tester.pumpAndSettle();
    final before = tester.getRect(
      find.byKey(const Key('practice-coach-arrow')),
    );
    scroll.jumpTo(scroll.offset + 60);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('practice-coach-arrow'))),
      isNot(before),
    );
    scroll.jumpTo(700);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-arrow')), findsNothing);
    await tester.pumpWidget(scene(target: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-arrow')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text coach stays above keyboard with reachable exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      scene(scale: 2.5, insets: const EdgeInsets.only(bottom: 190)),
    );
    await tester.pumpAndSettle();
    final bubble = tester.getRect(find.byKey(const Key('practice-coach')));
    expect(bubble.top, greaterThanOrEqualTo(0));
    expect(bubble.bottom, lessThanOrEqualTo(410));
    final exit = tester.getRect(find.byKey(const Key('practice-exit')));
    expect(exit.width, greaterThanOrEqualTo(48));
    expect(exit.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const Key('practice-coach-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-hint')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('practice-coach'))).bottom,
      lessThanOrEqualTo(410),
    );
    await tester.tap(find.byKey(const Key('practice-coach-toggle')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('target touching a scroll viewport edge retains its arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeCoachHost(
            presentation: PracticePresentation(
              step: PracticeStep.scoreBlueTwo,
              onExit: () {},
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 300,
                height: 240,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      PracticeTarget(
                        id: PracticeTargetId.blueTwo,
                        active: true,
                        child: SizedBox(
                          width: 300,
                          height: 48,
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('+2'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
  });

  testWidgets(
    'crowded real targets offer expandable guidance and a reachable exit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PracticeCoachHost(
              presentation: PracticePresentation(
                step: PracticeStep.scoreBlueTwo,
                onExit: () {},
              ),
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 260,
                    child: PracticeAvoid(child: ColoredBox(color: Colors.grey)),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 340,
                    bottom: 0,
                    child: PracticeAvoid(child: ColoredBox(color: Colors.grey)),
                  ),
                  Positioned(
                    left: 376,
                    top: 276,
                    width: 48,
                    height: 48,
                    child: PracticeTarget(
                      id: PracticeTargetId.blueTwo,
                      active: true,
                      child: FilledButton(
                        key: const Key('crowded-target'),
                        onPressed: () {},
                        child: const Text('2'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = tester.getRect(find.byKey(const Key('crowded-target')));
      final bubble = tester.getRect(find.byKey(const Key('practice-coach')));
      expect(bubble.overlaps(target), isFalse);
      expect(bubble.top, greaterThanOrEqualTo(260));
      expect(bubble.bottom, lessThanOrEqualTo(340));
      expect(find.byKey(const Key('practice-coach-toggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-coach-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('practice-coach-hint')), findsOneWidget);
      expect(find.byKey(const Key('practice-exit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-coach-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const Key('practice-coach')))
            .overlaps(target),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'already visible target does not change scroll offset on activation',
    (tester) async {
      final scroll = ScrollController(initialScrollOffset: 40);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(scene(enabled: false, scroll: scroll));
      await tester.pumpAndSettle();
      final before = scroll.offset;
      await tester.pumpWidget(scene(scroll: scroll));
      await tester.pumpAndSettle();
      expect(scroll.offset, before);
      expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
    },
  );

  testWidgets('geometry movement keeps one stable live announcement node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(scene(scroll: scroll));
      await tester.pumpAndSettle();
      final live = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(live, findsOneWidget);
      final before = tester.element(live);
      scroll.jumpTo(60);
      await tester.pumpAndSettle();
      expect(live, findsOneWidget);
      expect(identical(tester.element(live), before), isTrue);
      expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('offstage target clears the spotlight', (tester) async {
    var hidden = false;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return PracticeCoachHost(
                presentation: PracticePresentation(
                  step: PracticeStep.scoreBlueTwo,
                  onExit: () {},
                ),
                child: SizedBox.expand(
                  child: Center(
                    child: Offstage(
                      offstage: hidden,
                      child: PracticeTarget(
                        id: PracticeTargetId.blueTwo,
                        active: true,
                        child: SizedBox(
                          width: 120,
                          height: 60,
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('+2'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
    change(() => hidden = true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-coach-arrow')), findsNothing);
    expect(find.byKey(const Key('practice-coach-mask')), findsNothing);
  });
  for (final width in [320.0, 120.0]) {
    testWidgets(
      'short keyboard viewport keeps expanded controls reachable at width $width',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 600),
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 484),
              ),
              child: Scaffold(
                body: PracticeCoachHost(
                  presentation: PracticePresentation(
                    step: PracticeStep.scoreBlueTwo,
                    onExit: () {},
                  ),
                  child: SizedBox(
                    width: width,
                    height: 600,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: PracticeTarget(
                        active: true,
                        id: PracticeTargetId.blueTwo,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('2'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('practice-coach-toggle'));
        expect(toggle.hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('practice-coach-hint')), findsOneWidget);
        for (final key in ['practice-coach-toggle', 'practice-exit']) {
          final control = find.byKey(Key(key));
          expect(control.hitTestable(), findsOneWidget);
          final rect = tester.getRect(control);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.bottom, lessThanOrEqualTo(116));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
