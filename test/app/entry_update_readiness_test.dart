import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image image;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.orange);
    final picture = recorder.endRecording();
    image = await picture.toImage(8, 8);
    picture.dispose();
  });
  tearDownAll(() => image.dispose());

  for (final skip in [false, true]) {
    testWidgets('normal entry and skip announce visible local app once $skip', (
      tester,
    ) async {
      var revealed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HoopitoEntryGate(
            playbackSession: EntryPlaybackSession(),
            motionPreferenceLoader: () async => MotionPreference.standard,
            rendererReadyLoader: () async {},
            presentationReadyLoader: () async {},
            imageLoader: () async => image.clone(),
            onRevealed: () => revealed++,
            child: const Scaffold(body: Text('local app')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(revealed, 0);
      if (skip) await tester.tap(find.byKey(hoopitoEntryOverlayKey));
      await tester.pumpAndSettle();
      expect(revealed, 1);
      expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(revealed, 1);
    });
  }

  testWidgets('entry announces ready once after reduced playback', (
    tester,
  ) async {
    var revealed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HoopitoEntryGate(
          playbackSession: EntryPlaybackSession(),
          motionPreferenceLoader: () async => MotionPreference.reduced,
          rendererReadyLoader: () async {},
          presentationReadyLoader: () async {},
          imageLoader: () async => throw StateError('no image'),
          onRevealed: () => revealed++,
          child: const Scaffold(body: Text('local app')),
        ),
      ),
    );
    expect(revealed, 0);
    await tester.pumpAndSettle();
    expect(revealed, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(revealed, 1);
  });

  for (final suppressed in [false, true]) {
    testWidgets('settled hidden entry waits for local readiness $suppressed', (
      tester,
    ) async {
      final session = EntryPlaybackSession();
      if (suppressed) session.claim();
      var revealed = 0;
      Widget app(EntryStartupStatus status) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: !suppressed),
          child: HoopitoEntryGate(
            startupStatus: status,
            playbackSession: session,
            onRevealed: () => revealed++,
            child: const Scaffold(body: Text('local app')),
          ),
        ),
      );
      await tester.pumpWidget(app(EntryStartupStatus.loading));
      await tester.pump();
      expect(revealed, 0);
      await tester.pumpWidget(app(EntryStartupStatus.ready));
      await tester.pump();
      expect(revealed, 1);
      await tester.pumpWidget(app(EntryStartupStatus.ready));
      await tester.pump();
      expect(revealed, 1);
    });
  }
}
