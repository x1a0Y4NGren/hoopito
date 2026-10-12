import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

void main() {
  const preset = MatchSetupPreset(
    red: SetupParticipantPreset(nameSnapshot: 'Saved red', playerId: 'profile'),
    blue: SetupParticipantPreset(nameSnapshot: 'Saved blue'),
    rules: RuleTemplate(
      id: 'saved-rule',
      name: 'Saved rules',
      scoreButtons: [1, 2],
      targetScore: 15,
      winByTwo: true,
    ),
  );
  final player = Player(
    id: 'profile',
    nickname: 'New nickname',
    createdAt: DateTime(2026),
  );

  testWidgets('pending match start accepts only one confirmation', (
    tester,
  ) async {
    final pending = Completer<void>();
    final starts = <MatchSetup>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          onStartMatch: (setup) async {
            starts.add(setup);
            await pending.future;
          },
        ),
      ),
    );

    final start = find.byKey(const Key('pregame-start-match'));
    await tester.tap(start);
    await tester.tap(start);
    await tester.pump();

    expect(starts, hasLength(1));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    pending.complete();
    await tester.pump();
  });

  testWidgets('preset can be swapped and shot scope changed before start', (
    tester,
  ) async {
    MatchSetup? setup;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          initialPreset: preset,
          players: [player],
          onStartMatch: (value) => setup = value,
        ),
      ),
    );
    expect(_name(tester, 'pregame-red-name'), 'Saved red');
    expect(_name(tester, 'pregame-blue-name'), 'Saved blue');
    expect(setup, isNull);

    await tester.ensureVisible(find.byKey(const Key('pregame-swap-sides')));
    await tester.tap(find.byKey(const Key('pregame-swap-sides')));
    await tester.pump();
    expect(_name(tester, 'pregame-red-name'), 'Saved blue');
    expect(_name(tester, 'pregame-blue-name'), 'Saved red');
    await tester.ensureVisible(find.byKey(const Key('pregame-coverage-shots')));
    await tester.tap(find.byKey(const Key('pregame-coverage-shots')));
    await tester.tap(find.byKey(const Key('pregame-start-match')));

    expect(setup?.redPlayerProfileId, isNull);
    expect(setup?.bluePlayerProfileId, 'profile');
    expect(setup?.scoreButtons, [1, 2]);
    expect(setup?.targetScore, 15);
    expect(setup?.trackingCoverage, TrackingCoverage.shotAttempts);
    expect(setup?.recordingMode, RecordingMode.simple);
  });

  testWidgets('cancel preset leaves the start callback untouched', (
    tester,
  ) async {
    var starts = 0;
    var cancels = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          initialPreset: preset,
          onStartMatch: (_) => starts++,
          onCancel: () => cancels++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pregame-cancel')));
    expect(cancels, 1);
    expect(starts, 0);
  });

  testWidgets('failed start gives retry and accepts another confirmation', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          onStartMatch: (_) async {
            if (++attempts == 1) throw StateError('storage failed');
          },
        ),
      ),
    );
    final start = find.byKey(const Key('pregame-start-match'));
    await tester.tap(start);
    await tester.pump();
    expect(attempts, 1);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(find.text('比赛未能开始，请重试。'), findsOneWidget);

    await tester.tap(start);
    await tester.pump();
    expect(attempts, 2);
  });

  testWidgets('inline player cancellation never calls create or start', (
    tester,
  ) async {
    var creates = 0;
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          onCreatePlayer: (nickname) async {
            creates++;
            return player;
          },
          onStartMatch: (_) => starts++,
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('pregame-red-create-player')),
    );
    await tester.tap(find.byKey(const Key('pregame-red-create-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pregame-create-player-cancel')));
    await tester.pumpAndSettle();

    expect(creates, 0);
    expect(starts, 0);
    expect(_name(tester, 'pregame-red-name'), '红方');
  });

  testWidgets('inline create associates the saved player without starting', (
    tester,
  ) async {
    final pending = Completer<Player>();
    final names = <String>[];
    MatchSetup? setup;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          onCreatePlayer: (nickname) {
            names.add(nickname);
            return pending.future;
          },
          onStartMatch: (value) => setup = value,
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('pregame-red-create-player')),
    );
    await tester.tap(find.byKey(const Key('pregame-red-create-player')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pregame-create-player-name')),
      '  New nickname  ',
    );
    final save = find.byKey(const Key('pregame-create-player-save'));
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(names, ['New nickname']);
    expect(setup, isNull);
    pending.complete(player);
    await tester.pumpAndSettle();

    expect(_name(tester, 'pregame-red-name'), 'New nickname');
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    expect(setup?.redPlayerProfileId, 'profile');
  });

  testWidgets('inline save failure keeps the draft name for retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          onCreatePlayer: (nickname) async {
            if (++attempts == 1) throw StateError('storage failed');
            return player;
          },
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('pregame-red-create-player')),
    );
    await tester.tap(find.byKey(const Key('pregame-red-create-player')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pregame-create-player-name')),
      'New nickname',
    );
    await tester.tap(find.byKey(const Key('pregame-create-player-save')));
    await tester.pump();
    expect(find.text('保存失败，请重试。'), findsOneWidget);
    expect(find.text('New nickname'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregame-create-player-save')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(_name(tester, 'pregame-red-name'), 'New nickname');
  });
}

String _name(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
