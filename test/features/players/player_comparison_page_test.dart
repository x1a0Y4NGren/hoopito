import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_comparison_controller.dart';
import 'package:hoopito/features/players/player_comparison_page.dart';

void main() {
  testWidgets('comparison selects, swaps and changes modes', (tester) async {
    final requests = <PlayerComparisonRequest>[];
    final controller = _controller(
      compare: (request) async {
        requests.add(request);
        return _report(
          request is MatchPairComparisonRequest
              ? PlayerComparisonMode.matchPair
              : PlayerComparisonMode.adjacentWindow,
        );
      },
    );
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller: controller);

    expect(find.text('球员比较'), findsOneWidget);
    expect(
      find.byKey(const Key('comparison-baseline-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('comparison-current-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('comparison-metric-points')), findsOneWidget);
    expect(controller.baselineMatchId, 'older');
    expect(controller.currentMatchId, 'newest');

    await tester.tap(find.byKey(const Key('comparison-baseline-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('南风'));
    await tester.pumpAndSettle();
    expect(controller.baselineMatchId, 'oldest');

    await tester.tap(find.byKey(const Key('comparison-swap')));
    await tester.pumpAndSettle();
    expect(controller.baselineMatchId, 'newest');
    expect(controller.currentMatchId, 'oldest');

    await tester.tap(find.byKey(const Key('comparison-mode-adjacentWindow')));
    await tester.pumpAndSettle();
    expect(controller.mode, PlayerComparisonMode.adjacentWindow);
    expect(find.text('近 30 天'), findsOneWidget);
    expect(requests.last, isA<AdjacentWindowComparisonRequest>());
    await tester.tap(find.byKey(const Key('comparison-window-ninetyDays')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('comparison-opponent-opponent-1')));
    await tester.pumpAndSettle();
    final windowRequest = requests.last as AdjacentWindowComparisonRequest;
    expect(windowRequest.window, PlayerComparisonWindow.ninetyDays);
    expect(windowRequest.opponentPlayerId, 'opponent-1');
  });

  testWidgets('comparison states explain insufficient and one-sided samples', (
    tester,
  ) async {
    final controller = PlayerComparisonController(
      playerId: 'player-1',
      asOfUtc: DateTime.utc(2026, 8, 29),
      listMatches: (_) async => [_matches.first],
      compare: (request) async =>
          _report(PlayerComparisonMode.adjacentWindow, emptyBaseline: true),
    );
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller: controller);

    expect(find.text('至少需要两场比赛'), findsOneWidget);
    await tester.tap(find.byKey(const Key('comparison-mode-adjacentWindow')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('comparison-single-side-empty')),
      findsOneWidget,
    );
    expect(find.text('参照时段没有比赛。'), findsOneWidget);
  });

  testWidgets('comparison remains usable in locale theme and size matrix', (
    tester,
  ) async {
    final controller = _controller(
      compare: (request) async => _report(
        request is MatchPairComparisonRequest
            ? PlayerComparisonMode.matchPair
            : PlayerComparisonMode.adjacentWindow,
      ),
    );
    addTearDown(controller.dispose);
    const sizes = [Size(360, 760), Size(731, 411), Size(1095, 616)];
    for (final locale in const [Locale('zh'), Locale('en')]) {
      for (final brightness in Brightness.values) {
        for (final size in sizes) {
          await tester.binding.setSurfaceSize(size);
          await _pumpPage(
            tester,
            controller: controller,
            locale: locale,
            brightness: brightness,
            textScaler: const TextScaler.linear(2),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale $brightness $size at 200% text',
          );
          expect(
            tester
                .getSize(find.byKey(const Key('comparison-mode-matchPair')))
                .height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('comparison error offers a working retry action', (tester) async {
    var attempt = 0;
    final controller = PlayerComparisonController(
      playerId: 'player-1',
      asOfUtc: DateTime.utc(2026, 8, 29),
      listMatches: (_) async {
        attempt++;
        if (attempt == 1) throw StateError('broken local snapshot');
        return _matches;
      },
      compare: (request) async => _report(PlayerComparisonMode.matchPair),
    );
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller: controller);

    expect(find.text('无法读取比较数据'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('comparison-baseline-selector')),
      findsOneWidget,
    );
  });

  testWidgets('comparison explains the no-match state', (tester) async {
    final controller = PlayerComparisonController(
      playerId: 'player-1',
      asOfUtc: DateTime.utc(2026, 8, 29),
      listMatches: (_) async => const [],
      compare: (request) async => _report(PlayerComparisonMode.matchPair),
    );
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller: controller);

    expect(find.text('暂无可比较比赛'), findsOneWidget);
    expect(find.text('先用该球员档案完成一场比赛，再来比较。'), findsOneWidget);
  });

  testWidgets('comparison meets tap label and contrast guidelines', (
    tester,
  ) async {
    final controller = _controller(
      compare: (request) async => _report(PlayerComparisonMode.matchPair),
    );
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(
      tester,
      controller: controller,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
  });
}

PlayerComparisonController _controller({
  required PlayerComparisonLoader compare,
}) => PlayerComparisonController(
  playerId: 'player-1',
  asOfUtc: DateTime.utc(2026, 8, 29),
  listMatches: (_) async => _matches,
  compare: compare,
);

final _matches = [
  PlayerComparisonMatch(
    matchId: 'newest',
    playedAtUtc: DateTime.utc(2026, 8, 28),
    opponentPlayerId: 'opponent-1',
    opponentNameSnapshot: '北辰',
    playerScore: 11,
    opponentScore: 8,
  ),
  PlayerComparisonMatch(
    matchId: 'older',
    playedAtUtc: DateTime.utc(2026, 8, 20),
    opponentPlayerId: 'opponent-2',
    opponentNameSnapshot: '阿岚',
    playerScore: 8,
    opponentScore: 11,
  ),
  PlayerComparisonMatch(
    matchId: 'oldest',
    playedAtUtc: DateTime.utc(2026, 8, 10),
    opponentPlayerId: 'opponent-3',
    opponentNameSnapshot: '南风',
    playerScore: 9,
    opponentScore: 11,
  ),
];

PlayerComparisonReport _report(
  PlayerComparisonMode mode, {
  bool emptyBaseline = false,
}) {
  final baseline = emptyBaseline
      ? PlayerComparisonSample.empty(
          startUtc: DateTime.utc(2026, 7, 1),
          endUtc: DateTime.utc(2026, 7, 31),
        )
      : _sample('baseline', 8, 11, 3, 8);
  return PlayerComparisonReportBuilder().build(
    mode: mode,
    baseline: baseline,
    current: _sample('current', 11, 8, 5, 10),
  );
}

PlayerComparisonSample _sample(
  String id,
  int pointsFor,
  int pointsAgainst,
  int made,
  int attempts,
) => PlayerComparisonSample(
  startUtc: DateTime.utc(2026, 8, 1),
  endUtc: DateTime.utc(2026, 8, 29),
  matchIds: [id],
  wins: pointsFor > pointsAgainst ? 1 : 0,
  pointsFor: pointsFor,
  pointsAgainst: pointsAgainst,
  fieldGoalMade: made,
  fieldGoalAttempts: attempts,
  freeThrowMade: 2,
  freeThrowAttempts: 2,
  trustworthyAttemptMatchCount: 1,
  confirmedLocationCount: 4,
  locatableAttemptCount: 6,
  zoneDistribution: const {},
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required PlayerComparisonController controller,
  Locale locale = const Locale('zh'),
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MaterialApp(
        theme: buildHoopitoTheme(brightness: brightness),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerComparisonPage(
          controller: controller,
          player: Player(
            id: 'player-1',
            nickname: '飞鱼 Flight',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
