import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/match_view_data_mapper.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_event_filter.dart';
import 'package:hoopito/features/replay/replay_page.dart';

void main() {
  testWidgets('overview includes missed field goals without analytics', (
    tester,
  ) async {
    final controller = ReplayController(
      data: _projectData(
        [_event('made'), _event('missed', made: false)],
        locations: [_location('made')],
      ),
    );

    await _pumpReplay(tester, controller);

    _expectCoverage('50% · 1/2');
  });

  testWidgets('overview agrees with the canonical one-of-eight sample', (
    tester,
  ) async {
    final controller = ReplayController(data: _oneOfEightData());

    await _pumpReplay(tester, controller);

    _expectCoverage('13% · 1/8');
  });

  testWidgets('overview prefers canonical analytics over projected markers', (
    tester,
  ) async {
    final completeData = _oneOfEightData();
    final controller = ReplayController(
      data: _replayData(
        completeData,
        events: [completeData.events.first],
        withAnalytics: true,
      ),
    );

    await _pumpReplay(tester, controller);

    _expectCoverage('13% · 1/8');
  });

  testWidgets(
    'fallback excludes free throws, tombstones and unconfirmed locations',
    (tester) async {
      final controller = ReplayController(
        data: _projectData(
          [
            _event('made'),
            _event('missed', made: false),
            _event('unconfirmed'),
            _event('free-throw-made', type: EventKind.freeThrow, points: 1),
            _event('free-throw-missed', type: EventKind.freeThrow, made: false),
            _event('deleted-made', isDeleted: true),
            _event('deleted-missed', made: false, isDeleted: true),
            _event('reward', type: EventKind.reward),
          ],
          locations: [
            _location('made'),
            _location('unconfirmed', confirmed: false),
            _location('free-throw-made'),
            _location('free-throw-missed'),
            _location('deleted-made'),
            _location('deleted-missed'),
            _location('reward'),
          ],
        ),
      );

      await _pumpReplay(tester, controller);

      _expectCoverage('33% · 1/3');
    },
  );

  testWidgets('fallback supports legacy scores and misses without raw kinds', (
    tester,
  ) async {
    final data = _projectData(const []);
    final controller = ReplayController(
      data: _replayData(
        data,
        events: [
          ReplayEventData(
            id: 'legacy-made',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 2,
            elapsed: Duration.zero,
            shotPoint: CourtPoint(x: .3, y: .7),
          ),
          const ReplayEventData(
            id: 'legacy-missed',
            kind: ReplayEventKind.miss,
            side: TeamSide.blue,
            elapsed: Duration.zero,
          ),
        ],
      ),
    );

    await _pumpReplay(tester, controller);

    _expectCoverage('50% · 1/2');
  });

  testWidgets('fallback coverage stays on the full match when filters change', (
    tester,
  ) async {
    final controller = ReplayController(
      data: _projectData(
        [_event('made'), _event('missed', made: false, side: TeamSide.blue)],
        locations: [_location('made')],
      ),
    );
    await _pumpReplay(tester, controller);
    _expectCoverage('50% · 1/2');

    controller.setEventFilter(const ReplayEventFilter(sides: {TeamSide.blue}));
    await tester.pump();

    expect(find.byKey(const Key('replay-court-marker-made')), findsNothing);
    _expectCoverage('50% · 1/2');
  });

  for (final withAnalytics in [false, true]) {
    testWidgets('zero field goals show no data with analytics=$withAnalytics', (
      tester,
    ) async {
      final controller = ReplayController(
        data: _projectData(
          [
            _event('free-throw', type: EventKind.freeThrow, points: 1),
            _event('deleted', isDeleted: true),
          ],
          locations: [_location('free-throw'), _location('deleted')],
          withAnalytics: withAnalytics,
        ),
      );

      await _pumpReplay(tester, controller);

      _expectCoverage(AppLocalizationsZh().replayNoData);
    });
  }

  testWidgets('unconfirmed field goal locations show a zero confirmed sample', (
    tester,
  ) async {
    final controller = ReplayController(
      data: _projectData(
        [_event('unconfirmed')],
        locations: [_location('unconfirmed', confirmed: false)],
      ),
    );

    await _pumpReplay(tester, controller);

    _expectCoverage('0% · 0/1');
  });

  testWidgets('empty fallback shows no data', (tester) async {
    final controller = ReplayController(data: _projectData(const []));

    await _pumpReplay(tester, controller);

    _expectCoverage(AppLocalizationsZh().replayNoData);
  });

  testWidgets('English 200% portrait keeps the overview above the timeline', (
    tester,
  ) async {
    final controller = ReplayController(data: _oneOfEightData());
    await _pumpReplay(
      tester,
      controller,
      locale: const Locale('en'),
      textScale: 2,
      size: const Size(390, 740),
      theme: buildHoopitoTheme(brightness: Brightness.dark),
    );

    final court = tester.getRect(find.byKey(const Key('replay-court-pane')));
    final timeline = tester.getRect(
      find.byKey(const Key('replay-timeline-pane')),
    );
    expect(court.width, greaterThan(300));
    expect(timeline.top, greaterThan(court.bottom));
    _expectCoverage('13% · 1/8');
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('full replay analytics remains usable at 200% in $locale', (
      tester,
    ) async {
      final controller = ReplayController(data: _oneOfEightData());
      await _pumpReplay(tester, controller, locale: locale, textScale: 2);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReplayPage)),
      )!;

      final scope = find.byKey(const Key('replay-location-coverage-scope'));
      await tester.ensureVisible(scope);
      await tester.pumpAndSettle();

      _expectCoverage('13% · 1/8');
      expect(tester.widget<Text>(scope).data, l10n.v2LocationScope);
      expect(find.byKey(const Key('replay-analytics-summary')), findsOneWidget);

      final flow = find.byKey(const Key('replay-scoring-flow'));
      await tester.ensureVisible(flow);
      await tester.drag(flow, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      final finalFlowScore = find.descendant(
        of: flow,
        matching: find.text('11 : 8'),
      );
      expect(
        tester.getRect(flow).overlaps(tester.getRect(finalFlowScore)),
        isTrue,
      );

      final keyPossession = find.text(
        'Blue · ${l10n.replayAnalyticsScoringRun}',
      );
      await tester.ensureVisible(keyPossession);
      await tester.pumpAndSettle();
      expect(keyPossession, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpReplay(
  WidgetTester tester,
  ReplayController controller, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
  Size size = const Size(390, 844),
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ReplayPage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCoverage(String value) {
  final metric = find.byKey(const Key('replay-location-coverage'));
  expect(
    find.descendant(of: metric, matching: find.text(value)),
    findsOneWidget,
  );
}

ReplayMatchData _oneOfEightData() => _projectData(
  [
    _event('red-2'),
    _event('red-3a', points: 3),
    _event('red-3b', points: 3),
    _event('red-3c', points: 3),
    _event('blue-2', side: TeamSide.blue),
    _event('blue-3a', side: TeamSide.blue, points: 3),
    _event('blue-3b', side: TeamSide.blue, points: 3),
    _event('blue-missed', side: TeamSide.blue, made: false),
  ],
  locations: [_location('red-2')],
  withAnalytics: true,
);

MatchEvent _event(
  String id, {
  EventKind type = EventKind.fieldGoal,
  TeamSide side = TeamSide.red,
  bool made = true,
  int points = 2,
  bool isDeleted = false,
}) => MatchEvent(
  id: id,
  matchId: 'coverage-match',
  type: type,
  side: side,
  points: made ? points : 0,
  outcome: made ? ShotOutcome.made : ShotOutcome.missed,
  occurredAt: DateTime.utc(2026, 10, 3),
  isDeleted: isDeleted,
);

ShotLocation _location(String eventId, {bool confirmed = true}) => ShotLocation(
  id: 'location-$eventId',
  matchId: 'coverage-match',
  eventId: eventId,
  point: CourtPoint(x: .3, y: .7),
  isConfirmed: confirmed,
);

ReplayMatchData _projectData(
  List<MatchEvent> events, {
  List<ShotLocation> locations = const [],
  bool withAnalytics = false,
}) {
  final data = replayDataFromDetail(
    MatchDetail(
      match: Match(
        id: 'coverage-match',
        createdAt: DateTime.utc(2026, 10, 3),
        startedAt: DateTime.utc(2026, 10, 3),
        endedAt: DateTime.utc(2026, 10, 3, 0, 5),
        status: MatchStatus.finished,
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplateSnapshot: const RuleTemplate(
          id: 'free',
          name: 'Free scoring',
          scoreButtons: [1, 2, 3],
        ),
      ),
      events: events,
      shotLocations: locations,
      redScore: 11,
      blueScore: 8,
      redFouls: 0,
      blueFouls: 0,
      shotAttemptCount: 0,
      locatedShotCount: 0,
    ),
  );
  return _replayData(data, withAnalytics: withAnalytics);
}

ReplayMatchData _replayData(
  ReplayMatchData data, {
  List<ReplayEventData>? events,
  bool withAnalytics = false,
}) => ReplayMatchData(
  matchId: data.matchId,
  redName: data.redName,
  blueName: data.blueName,
  redScore: data.redScore,
  blueScore: data.blueScore,
  duration: data.duration,
  events: events ?? data.events,
  analytics: withAnalytics ? data.analytics : null,
);
