import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';

void main() {
  testWidgets(
    'replay remains read-only until edit mode is explicitly enabled',
    (tester) async {
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'match-1',
          redName: '红方',
          blueName: '蓝方',
          redScore: 2,
          blueScore: 0,
          duration: const Duration(minutes: 1),
          events: [
            ReplayEventData(
              id: 'event-1',
              locationId: 'location-1',
              kind: ReplayEventKind.score,
              side: TeamSide.red,
              points: 2,
              elapsed: Duration(seconds: 3),
              shotPoint: CourtPoint(x: 0.4, y: 0.6),
            ),
          ],
        ),
        onMoveShotLocation: (_, _, _) async {},
      );
      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );

      expect(controller.isEditing, isFalse);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).mode,
        CourtViewMode.readOnly,
      );
      expect(find.text('只读模式'), findsOneWidget);

      await tester.tap(find.byKey(const Key('replay-edit-toggle')));
      await tester.pump();

      expect(controller.isEditing, isTrue);
      expect(find.text('编辑模式'), findsOneWidget);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).mode,
        CourtViewMode.editable,
      );
    },
  );

  testWidgets(
    'saving an event note keeps controllers alive through dismissal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late ReplayController controller;
      var savedNote = '';
      controller = ReplayController(
        data: _editableMatch(),
        onUpdateEventNote: (_, note, _) async {
          savedNote = note;
          controller.replaceData(_editableMatch(note: note));
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('replay-edit-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('replay-event-event-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'visual-check');
      await tester.tap(find.text('保存备注'));
      await tester.pumpAndSettle();

      expect(savedNote, 'visual-check');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving a moved shot keeps reason controller alive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late ReplayController controller;
    var savedReason = '';
    controller = ReplayController(
      data: _editableMatch(withLocation: true),
      onMoveShotLocation: (_, _, reason) async {
        savedReason = reason ?? '';
        controller.replaceData(_editableMatch(withLocation: true));
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('replay-edit-toggle')));
    await tester.pump();
    controller.selectEvent('event-1');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('replay-save-location')));
    await tester.tap(find.byKey(const Key('replay-save-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'location-check');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedReason, 'location-check');
    expect(tester.takeException(), isNull);
  });
}

ReplayMatchData _editableMatch({String? note, bool withLocation = false}) {
  return ReplayMatchData(
    matchId: 'match-edit',
    redName: '红方',
    blueName: '蓝方',
    redScore: 2,
    blueScore: 0,
    duration: const Duration(minutes: 1),
    events: [
      ReplayEventData(
        id: 'event-1',
        kind: ReplayEventKind.score,
        side: TeamSide.red,
        points: 2,
        elapsed: const Duration(seconds: 3),
        note: note,
        locationId: withLocation ? 'location-1' : null,
        shotPoint: withLocation ? CourtPoint(x: 0.4, y: 0.6) : null,
      ),
    ],
  );
}
