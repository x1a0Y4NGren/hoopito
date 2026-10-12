import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/app/entry/entry_renderer_ready.dart';
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

  Widget harness({
    EntryStartupStatus status = EntryStartupStatus.ready,
    EntryMotionPreferenceLoader? preferenceLoader,
    EntryImageLoader? imageLoader,
    EntryRendererReadyLoader? rendererReadyLoader,
    EntryRendererReadyLoader? presentationReadyLoader,
    EntryPlaybackSession? session,
    MediaQueryData media = const MediaQueryData(size: Size(390, 844)),
    VoidCallback? onChildTap,
  }) => MaterialApp(
    theme: buildHoopitoTheme(),
    home: MediaQuery(
      data: media,
      child: HoopitoEntryGate(
        startupStatus: status,
        waitingLabel: 'Opening local records…',
        motionPreferenceLoader: preferenceLoader,
        imageLoader: imageLoader ?? () async => image.clone(),
        rendererReadyLoader: rendererReadyLoader ?? () async {},
        presentationReadyLoader: presentationReadyLoader ?? () async {},
        playbackSession: session,
        child: GestureDetector(
          key: const Key('entry-child'),
          behavior: HitTestBehavior.opaque,
          onTap: onChildTap,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    ),
  );

  testWidgets('approved entry stays silent throughout bounce and reveal', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    for (final channel in [
      SystemChannels.platform,
      const MethodChannel('xyz.luan/audioplayers'),
      const MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
    }
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 861));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 141));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(find.byKey(const Key('entry-child')), findsOneWidget);
    expect(
      calls.where(
        (c) =>
            c.method.contains('HapticFeedback') ||
            c.method == 'play' ||
            c.method == 'create' ||
            c.method == 'setSourceBytes',
      ),
      isEmpty,
    );
  });

  testWidgets('page mounts only during opaque settled pose', (tester) async {
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byKey(const Key('entry-child')), findsNothing);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('entry-child')), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byKey(hoopitoEntrySceneKey),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 1);
    final childElement = tester.element(find.byKey(const Key('entry-child')));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const Key('entry-child'))),
      same(childElement),
    );
  });

  testWidgets('skip during reveal never flashes the opaque mark back', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 861));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    double opacity() => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(hoopitoEntrySceneKey),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    final before = opacity();
    expect(before, inExclusiveRange(0, 1));
    await tester.tap(find.byKey(hoopitoEntryOverlayKey));
    await tester.pump();
    expect(opacity(), closeTo(before, .001));
    await tester.pump(const Duration(milliseconds: 71));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('finished gate releases its owned decoded image', (tester) async {
    final owned = image.clone();
    await tester.pumpWidget(harness(imageLoader: () async => owned));
    await _start(tester);
    await tester.pumpAndSettle();
    expect(owned.debugDisposed, isTrue);
    expect(find.byKey(const Key('entry-child')), findsOneWidget);
  });

  testWidgets('readiness regression cancels reveal until content is ready', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 861));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(harness(status: EntryStartupStatus.loading));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_frame(tester).progress, .86);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('timeline starts after the unchanged handoff frame', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 700));
    expect(_frame(tester).progress, 0);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(_frame(tester).progress, closeTo(.06, .001));
  });

  testWidgets('slow startup settles and waits without replaying', (
    tester,
  ) async {
    await tester.pumpWidget(harness(status: EntryStartupStatus.loading));
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 861));
    await tester.pump(const Duration(seconds: 2));
    expect(_frame(tester).progress, .86);
    expect(find.text('Opening local records…'), findsOneWidget);
    expect(find.byKey(const Key('entry-child')), findsNothing);
    await tester.pumpWidget(harness());
    expect(_frame(tester).progress, .86);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 141));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('tap settles current deformation and does not tap through', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(harness(onChildTap: () => taps++));
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 330));
    final frozen = _frame(tester).progress;
    await tester.tap(find.byKey(hoopitoEntryOverlayKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(_frame(tester).progress, frozen);
    expect(_frame(tester).motionStrength, inExclusiveRange(0, 1));
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 61));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets(
    'skip while loading settles but still waits for actual readiness',
    (tester) async {
      await tester.pumpWidget(harness(status: EntryStartupStatus.loading));
      await _start(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(hoopitoEntryOverlayKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 121));
      await tester.pump();
      expect(_frame(tester).progress, .86);
      expect(_frame(tester).mode, EntryMotionMode.reduced);
      expect(find.byKey(const Key('entry-child')), findsNothing);
      await tester.pumpWidget(harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 141));
      await tester.pump();
      expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    },
  );

  testWidgets('skip before preference and image resolve remains bounded', (
    tester,
  ) async {
    final pending = Completer<MotionPreference>();
    final decode = Completer<ui.Image>();
    await tester.pumpWidget(
      harness(
        preferenceLoader: () => pending.future,
        imageLoader: () => decode.future,
      ),
    );
    await tester.tap(find.byKey(hoopitoEntryOverlayKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    final lateImage = image.clone();
    decode.complete(lateImage);
    pending.complete(MotionPreference.standard);
    await tester.pump();
    expect(lateImage.debugDisposed, isTrue);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'reduced ${reduced ? 'accessibility' : 'preference'} uses only a short fade',
      (tester) async {
        await tester.pumpWidget(
          harness(
            media: MediaQueryData(accessibleNavigation: reduced),
            preferenceLoader: () async =>
                reduced ? MotionPreference.standard : MotionPreference.reduced,
          ),
        );
        await _start(tester);
        expect(_frame(tester).mode, EntryMotionMode.reduced);
        await tester.pump(const Duration(milliseconds: 141));
        await tester.pump();
        expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
      },
    );
  }

  testWidgets('disabled animations bypass immediately without decoding', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      harness(
        media: const MediaQueryData(disableAnimations: true),
        imageLoader: () async {
          loads++;
          return image.clone();
        },
      ),
    );
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(loads, 0);
  });

  testWidgets('system disabling motion during jump reveals content', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      harness(media: const MediaQueryData(disableAnimations: true)),
    );
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'preference ${fails ? 'failure' : 'timeout'} falls back to fade',
      (tester) async {
        await tester.pumpWidget(
          harness(
            preferenceLoader: () => fails
                ? Future.error(StateError('unavailable'))
                : Completer<MotionPreference>().future,
          ),
        );
        await tester.pump(const Duration(milliseconds: 81));
        await _start(tester);
        expect(_frame(tester).mode, EntryMotionMode.reduced);
        await tester.pump(const Duration(milliseconds: 141));
        await tester.pump();
        expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
      },
    );
  }

  testWidgets('decode failure falls back to a static brand and proceeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(imageLoader: () async => throw StateError('decode failed')),
    );
    await _start(tester);
    expect(_frame(tester).mode, EntryMotionMode.reduced);
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 141));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('decode timeout disposes late image and never restarts', (
    tester,
  ) async {
    final pending = Completer<ui.Image>();
    await tester.pumpWidget(harness(imageLoader: () => pending.future));
    await tester.pump(const Duration(milliseconds: 101));
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 141));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    final lateImage = image.clone();
    pending.complete(lateImage);
    await tester.pump();
    expect(lateImage.debugDisposed, isTrue);
  });

  testWidgets('a stalled loader cannot beat the wall-clock image deadline', (
    tester,
  ) async {
    final lateImage = image.clone();
    await tester.pumpWidget(
      harness(
        imageLoader: () {
          // Reproduce a UI stall: the source Future wins the callback race,
          // although the image is already beyond the preparation deadline.
          sleep(
            HoopitoEntryTimeline.imageWait + const Duration(milliseconds: 20),
          );
          return Future.value(lateImage);
        },
      ),
    );
    await _start(tester);
    expect(_frame(tester).mode, EntryMotionMode.reduced);
    expect(lateImage.debugDisposed, isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('renderer readiness precedes the bounded image preparation', (
    tester,
  ) async {
    final surface = Completer<void>();
    var imageLoads = 0;
    await tester.pumpWidget(
      harness(
        rendererReadyLoader: () => surface.future,
        imageLoader: () async {
          imageLoads++;
          return image.clone();
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(imageLoads, 0);
    expect(_frame(tester).mode, isNull);
    surface.complete();
    await _start(tester);
    expect(imageLoads, 1);
    expect(_frame(tester).mode, EntryMotionMode.standard);
    await tester.pumpAndSettle();
  });

  testWidgets('a first-run preference reply waits on the same native surface', (
    tester,
  ) async {
    final surface = Completer<void>();
    await tester.pumpWidget(
      harness(
        rendererReadyLoader: () => surface.future,
        preferenceLoader: () async {
          await surface.future;
          return MotionPreference.standard;
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    surface.complete();
    await _start(tester);
    expect(_frame(tester).mode, EntryMotionMode.standard);
    await tester.pumpAndSettle();
  });

  testWidgets('the native splash must be removed before the jump starts', (
    tester,
  ) async {
    final presented = Completer<bool>();
    const channel = MethodChannel(
      'io.github.x1a0y4ngren.hooptrace/entry_renderer',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) => presented.future,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      harness(presentationReadyLoader: waitForEntryPresentation),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_frame(tester).progress, 0);
    presented.complete(true);
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester).progress, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('presentation timeout uses reduced motion without replaying', (
    tester,
  ) async {
    final presented = Completer<void>();
    await tester.pumpWidget(
      harness(presentationReadyLoader: () => presented.future),
    );
    await _start(tester);
    await tester.pump(HoopitoEntryTimeline.presentationWait);
    await _start(tester);
    expect(_frame(tester).mode, EntryMotionMode.reduced);
    await tester.pumpAndSettle();
    presented.complete();
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('terminal startup cancels pending native splash removal', (
    tester,
  ) async {
    final presented = Completer<void>();
    Future<void> waitForPresentation() => presented.future;
    await tester.pumpWidget(
      harness(presentationReadyLoader: waitForPresentation),
    );
    await _start(tester);
    await tester.pumpWidget(
      harness(
        status: EntryStartupStatus.failure,
        presentationReadyLoader: waitForPresentation,
      ),
    );
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    presented.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('skip consumes an entry still waiting for the native splash', (
    tester,
  ) async {
    final presented = Completer<void>();
    await tester.pumpWidget(
      harness(presentationReadyLoader: () => presented.future),
    );
    await _start(tester);
    await tester.tap(find.byKey(hoopitoEntrySceneKey));
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    presented.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('terminal startup cancels a pending renderer preparation', (
    tester,
  ) async {
    final surface = Completer<void>();
    var imageLoads = 0;
    Future<ui.Image> loadImage() async {
      imageLoads++;
      return image.clone();
    }

    await tester.pumpWidget(
      harness(
        rendererReadyLoader: () => surface.future,
        imageLoader: loadImage,
      ),
    );
    await tester.pumpWidget(
      harness(
        status: EntryStartupStatus.failure,
        rendererReadyLoader: () => surface.future,
        imageLoader: loadImage,
      ),
    );
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    surface.complete();
    await tester.pump();
    expect(imageLoads, 0);
  });

  testWidgets('a missing renderer notification cannot hang startup', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(rendererReadyLoader: () => Completer<void>().future),
    );
    await tester.pump(
      HoopitoEntryTimeline.rendererWait + const Duration(milliseconds: 1),
    );
    await _start(tester);
    expect(_frame(tester).mode, EntryMotionMode.standard);
    await tester.pumpAndSettle();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets(
    'native handoff waits on one decode without a second asset image',
    (tester) async {
      final pending = Completer<ui.Image>();
      await tester.pumpWidget(harness(imageLoader: () => pending.future));
      expect(find.byType(Image), findsNothing);
      pending.complete(image.clone());
      await _start(tester);
      expect(_frame(tester).image, isNotNull);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'disposal during decode releases native frame and late resource',
    (tester) async {
      final pending = Completer<ui.Image>();
      await tester.pumpWidget(harness(imageLoader: () => pending.future));
      await tester.pumpWidget(const SizedBox.shrink());
      final lateImage = image.clone();
      pending.complete(lateImage);
      await tester.pump();
      expect(lateImage.debugDisposed, isTrue);
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    EntryStartupStatus.failure,
    EntryStartupStatus.legacy,
  ]) {
    testWidgets('$status bypasses ongoing motion immediately', (tester) async {
      await tester.pumpWidget(harness(status: EntryStartupStatus.loading));
      await _start(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(harness(status: status));
      expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
      expect(find.byKey(const Key('entry-child')), findsOneWidget);
    });
  }

  testWidgets('foreground return settles rather than restarting jump', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 250));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump();
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('one process session does not replay on widget recreation', (
    tester,
  ) async {
    final session = EntryPlaybackSession();
    await tester.pumpWidget(harness(session: session));
    await _start(tester);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness(session: session));
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
  });

  testWidgets('long waiting hint is accessible with compact large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    tester.view.reset();
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        status: EntryStartupStatus.loading,
        media: const MediaQueryData(
          size: Size(320, 240),
          textScaler: TextScaler.linear(2),
          padding: EdgeInsets.only(bottom: 20),
        ),
      ),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Opening local records…'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(hoopitoEntryWaitingKey))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _start(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

HoopitoEntryFrame _frame(WidgetTester tester) =>
    tester.widget<HoopitoEntryFrame>(find.byKey(hoopitoEntrySceneKey));
