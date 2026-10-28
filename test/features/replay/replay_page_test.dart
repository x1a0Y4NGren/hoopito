import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';

void main() {
  ReplayController buildController() {
    return ReplayController(
      data: ReplayMatchData(
        matchId: 'match-1',
        redName: '赤焰',
        blueName: '海浪',
        redScore: 11,
        blueScore: 9,
        duration: const Duration(minutes: 13, seconds: 5),
        events: [
          ReplayEventData(
            id: 'event-1',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 2,
            elapsed: const Duration(seconds: 15),
            shotPoint: CourtPoint(x: 0.3, y: 0.7),
          ),
          const ReplayEventData(
            id: 'event-2',
            kind: ReplayEventKind.foul,
            side: TeamSide.blue,
            elapsed: Duration(minutes: 1, seconds: 2),
            note: '防守犯规',
          ),
        ],
      ),
    );
  }

  testWidgets('renders score, locked court, overview and filterable timeline', (
    tester,
  ) async {
    final controller = buildController();
    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    expect(find.text('赤焰'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('海浪'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('比赛记录'), findsOneWidget);
    expect(find.byKey(const Key('replay-event-event-1')), findsOneWidget);
    expect(find.byKey(const Key('replay-event-event-2')), findsOneWidget);

    final court = tester.widget<CourtView>(find.byType(CourtView));
    expect(court.mode, CourtViewMode.readOnly);
    expect(court.pendingLocation, isNull);
    expect(court.onPendingLocationChanged, isNull);

    await tester.tap(find.byKey(const Key('replay-compact-filter-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replay-kind-fouls')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('replay-event-event-1')), findsNothing);
    expect(find.byKey(const Key('replay-event-event-2')), findsOneWidget);
  });

  testWidgets('replay exit tooltip comes from its destination', (tester) async {
    final controller = buildController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayPage(
          controller: controller,
          onExit: () {},
          exitTooltip: 'Back to scoring',
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byKey(const Key('replay-exit'))).tooltip,
      'Back to scoring',
    );
  });

  testWidgets(
    'shows manual and suggested possession segments with current and end boundaries',
    (tester) async {
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'possession-page',
          redName: '红方',
          blueName: '蓝方',
          redScore: 3,
          blueScore: 2,
          duration: const Duration(seconds: 20),
          isFinished: false,
          events: const [],
          possessionSegments: [
            ReplayPossessionSegmentData(
              id: 'manual-segment',
              side: TeamSide.red,
              startedAtEventId: 'manual-start',
              startedAt: Duration.zero,
              endedAtEventId: 'suggested-start',
              endedAt: Duration(seconds: 12),
              reason: '裁判指定',
              source: PossessionSource.manual,
            ),
            ReplayPossessionSegmentData(
              id: 'suggested-segment',
              side: TeamSide.blue,
              startedAtEventId: 'suggested-start',
              startedAt: Duration(seconds: 12),
              reason: 'made:switchAfterMade;event:suggested-start',
              source: PossessionSource.suggested,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );

      expect(
        find.byKey(const Key('replay-possession-segments')),
        findsOneWidget,
      );
      expect(find.text('球权记录'), findsOneWidget);
      expect(find.textContaining('· 人工'), findsOneWidget);
      expect(find.textContaining('· 建议'), findsOneWidget);
      expect(find.textContaining('结束 00:12'), findsOneWidget);
      expect(find.textContaining('未记录结束时间'), findsOneWidget);
    },
  );

  testWidgets('labels a closed possession segment at the final boundary', (
    tester,
  ) async {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'finished-possession-page',
        redName: '红方',
        blueName: '蓝方',
        redScore: 5,
        blueScore: 4,
        duration: const Duration(seconds: 20),
        isFinished: true,
        events: const [],
        possessionSegments: [
          ReplayPossessionSegmentData(
            id: 'finished-segment',
            side: TeamSide.red,
            startedAtEventId: 'start',
            startedAt: Duration.zero,
            endedAtEventId: 'finish',
            endedAt: Duration(seconds: 20),
            source: PossessionSource.manual,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    expect(find.text('比赛已结束'), findsOneWidget);
    expect(find.textContaining('结束 00:20'), findsOneWidget);
    expect(find.textContaining('未记录结束时间'), findsNothing);
  });

  testWidgets('shows finish action only when callback is provided', (
    tester,
  ) async {
    var finishCalls = 0;
    var confirmedRedScore = -1;
    var confirmedBlueScore = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayPage(
          controller: buildController(),
          onFinishMatch: (redScore, blueScore) async {
            finishCalls++;
            confirmedRedScore = redScore;
            confirmedBlueScore = blueScore;
          },
        ),
      ),
    );

    final finishButton = find.byKey(const Key('replay-finish-match'));
    expect(finishButton, findsOneWidget);
    expect(tester.getSize(finishButton).height, greaterThanOrEqualTo(48));
    await tester.tap(finishButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('赤焰 11 : 9 海浪'), findsOneWidget);
    expect(finishCalls, 0);
    await tester.tap(find.byKey(const Key('replay-finish-cancel')));
    await tester.pumpAndSettle();
    expect(finishCalls, 0);

    await tester.tap(finishButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replay-finish-confirm')));
    await tester.pumpAndSettle();
    expect(finishCalls, 1);
    expect(confirmedRedScore, 11);
    expect(confirmedBlueScore, 9);

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: buildController())),
    );
    expect(find.byKey(const Key('replay-finish-match')), findsNothing);
  });

  testWidgets(
    'failed replay finish remains retryable and never double submits',
    (tester) async {
      final completion = Completer<void>();
      var finishCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ReplayPage(
            controller: buildController(),
            onFinishMatch: (_, _) {
              finishCalls++;
              return completion.future;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('replay-finish-match')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay-finish-confirm')));
      await tester.pump();
      expect(finishCalls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('replay-finish-match')))
            .onPressed,
        isNull,
      );
      completion.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('操作失败，请重试。'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('replay-finish-match')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('previews and exports a dedicated replay summary image', (
    tester,
  ) async {
    Uint8List? sharedBytes;
    String? sharedMatchId;
    final imageBytes = Uint8List.fromList([137, 80, 78, 71]);
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ReplayPage(
          controller: buildController(),
          captureBoundary: (_) async => imageBytes,
          onShareSummary: (bytes, matchId) async {
            sharedBytes = bytes;
            sharedMatchId = matchId;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('replay-export-image')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('replay-export-summary')), findsOneWidget);
    expect(find.text('复盘分享图'), findsOneWidget);
    expect(find.text('将落点图和比赛分析合成一张本地图片'), findsOneWidget);

    await tester.tap(find.byKey(const Key('replay-export-confirm')));
    await tester.pumpAndSettle();
    expect(sharedBytes, imageBytes);
    expect(sharedMatchId, 'match-1');
  });

  testWidgets('adapts to portrait and landscape without overflow', (
    tester,
  ) async {
    for (final size in [
      const Size(390, 844),
      const Size(640, 360),
      const Size(1000, 700),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: buildController())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final compactFilter = find.byKey(
        const Key('replay-compact-filter-action'),
      );
      final inlineFilter = find.byKey(const Key('replay-kind-all'));
      final filter = compactFilter.evaluate().isNotEmpty
          ? compactFilter
          : inlineFilter;
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));
    }
    await tester.binding.setSurfaceSize(null);
  });
}
