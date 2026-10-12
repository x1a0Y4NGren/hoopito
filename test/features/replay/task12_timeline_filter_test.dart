import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/replay/widgets/replay_timeline.dart';

void main() {
  testWidgets(
    'full compact ReplayPage keeps the first event inside its real viewport',
    (tester) async {
      const insets = EdgeInsets.fromLTRB(8, 16, 12, 18);
      await _pumpCompactReplayPage(
        tester,
        locale: const Locale('en'),
        viewPadding: insets,
      );

      final pane = tester.getRect(
        find.byKey(const Key('replay-timeline-pane')),
      );
      final viewport = tester.getRect(
        find.byKey(const Key('replay-timeline-scroll')),
      );
      final first = tester.getRect(find.byKey(const Key('replay-event-first')));
      expect(pane.contains(viewport.topLeft), isTrue);
      expect(pane.contains(viewport.bottomRight), isTrue);
      expect(first.left, greaterThanOrEqualTo(viewport.left));
      expect(first.top, greaterThanOrEqualTo(viewport.top));
      expect(first.right, lessThanOrEqualTo(viewport.right));
      expect(first.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(
        first.height,
        greaterThanOrEqualTo(48),
        reason: 'the visible first event must retain a usable minimum target',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final testCase in const [
    (locale: Locale('en'), label: 'Replay filters'),
    (locale: Locale('zh'), label: '筛选'),
  ]) {
    testWidgets(
      'compact ReplayPage exposes a localized 48dp ${testCase.locale.languageCode} filter action',
      (tester) async {
        const insets = EdgeInsets.fromLTRB(8, 16, 12, 18);
        await _pumpCompactReplayPage(
          tester,
          locale: testCase.locale,
          viewPadding: insets,
        );

        final filter = find.byKey(const Key('replay-compact-filter-action'));
        final rect = tester.getRect(filter);
        final safeViewport = Rect.fromLTRB(
          insets.left,
          insets.top,
          731 - insets.right,
          411 - insets.bottom,
        );
        expect(filter.hitTestable(), findsOneWidget);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(safeViewport.contains(rect.center), isTrue);
        expect(tester.getSemantics(filter).label, testCase.label);
      },
    );
  }

  testWidgets('compact filter action names the filter control, not All', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHoopitoTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: ReplayTimelinePanel(
              controller: _compactController(),
              onEventTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(const Key('replay-compact-filter-action'));
    expect(tester.getSemantics(filter).label, 'Replay filters');
    expect(tester.getSize(filter).shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('outcome and point chips can be tapped again to clear filters', (
    tester,
  ) async {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'filter-clear',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 2,
        blueScore: 0,
        duration: Duration.zero,
        events: [
          ReplayEventData(
            id: 'event',
            side: TeamSide.red,
            kind: ReplayEventKind.score,
            points: 2,
            outcome: ShotOutcome.made,
            elapsed: Duration.zero,
            occurredAt: DateTime.utc(2026, 8, 1),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReplayTimelinePanel(
              controller: controller,
              embedded: true,
              onEventTap: (_) {},
            ),
          ),
        ),
      ),
    );

    final madeChip = find.widgetWithText(ChoiceChip, '命中');
    await tester.tap(madeChip);
    expect(controller.eventFilter.outcomes, {ShotOutcome.made});
    await tester.tap(madeChip);
    expect(controller.eventFilter.outcomes, isEmpty);

    final pointChip = find.widgetWithText(ChoiceChip, '分值 2');
    await tester.tap(pointChip);
    expect(controller.eventFilter.points, {2});
    await tester.tap(pointChip);
    expect(controller.eventFilter.points, isEmpty);
  });

  testWidgets('other chip includes every non shot score or foul event', (
    tester,
  ) async {
    final events = <ReplayEventData>[
      for (final kind in const [
        EventKind.reward,
        EventKind.pause,
        EventKind.interruption,
        EventKind.note,
        EventKind.custom,
        EventKind.possession,
      ])
        ReplayEventData(
          id: kind.name,
          side: null,
          kind: ReplayEventKind.other,
          rawKind: kind,
          elapsed: Duration.zero,
          occurredAt: DateTime.utc(2026, 8, 1),
        ),
      ReplayEventData(
        id: 'score',
        side: TeamSide.red,
        kind: ReplayEventKind.score,
        rawKind: EventKind.fieldGoal,
        points: 2,
        outcome: ShotOutcome.made,
        elapsed: Duration.zero,
        occurredAt: DateTime.utc(2026, 8, 1),
      ),
    ];
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'filter-other',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 2,
        blueScore: 0,
        duration: Duration.zero,
        events: events,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReplayTimelinePanel(
              controller: controller,
              embedded: true,
              onEventTap: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('replay-kind-other')));
    await tester.pump();

    expect(controller.visibleEvents.map((event) => event.id), [
      'reward',
      'pause',
      'interruption',
      'note',
      'custom',
      'possession',
    ]);
  });
}

Future<void> _pumpCompactReplayPage(
  WidgetTester tester, {
  required Locale locale,
  required EdgeInsets viewPadding,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(731, 411);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHoopitoTheme(brightness: Brightness.dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          padding: viewPadding,
          viewPadding: viewPadding,
        ),
        child: child!,
      ),
      home: ReplayPage(controller: _compactController()),
    ),
  );
  await tester.pumpAndSettle();
}

ReplayController _compactController() => ReplayController(
  data: ReplayMatchData(
    matchId: 'compact-first-event',
    redName: 'Red',
    blueName: 'Blue',
    redScore: 2,
    blueScore: 0,
    duration: const Duration(minutes: 1),
    events: [
      ReplayEventData(
        id: 'first',
        side: TeamSide.red,
        kind: ReplayEventKind.score,
        points: 2,
        outcome: ShotOutcome.made,
        elapsed: Duration.zero,
        occurredAt: DateTime.utc(2026, 8, 1),
      ),
    ],
  ),
);
