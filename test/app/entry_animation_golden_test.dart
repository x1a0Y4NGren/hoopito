import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/entry/entry_creature.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';

import '../support/golden_fonts.dart';

void main() {
  late ui.Image image;

  setUpAll(() async {
    await loadHoopitoGoldenFonts();
    final data = await rootBundle.load(
      'assets/icons/hoopito-app-icon-foreground.png',
    );
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  });
  tearDownAll(() => image.dispose());

  for (final frame in <String, int>{
    'handoff': 0,
    'anticipation': 150,
    'flight': 330,
    'landing': 480,
    'ripple': 690,
    'lock': 860,
    'fade': 930,
  }.entries) {
    testWidgets('entry animation ${frame.key} at real 390x844 viewport', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        _harness(image: image, progress: frame.value / 1000),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(_goldenKey)), const Size(390, 844));
      expect(tester.getSize(find.byType(EntryCreature)), const Size(288, 288));
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/entry_${frame.key}.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final language in ['zh', 'en']) {
    testWidgets('entry waiting hint $language at 320x240 and 200% text', (
      tester,
    ) async {
      _setViewport(tester, const Size(320, 240));
      await tester.pumpWidget(
        _harness(
          image: image,
          progress: .86,
          language: language,
          waiting: true,
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.getRect(find.byKey(hoopitoEntryWaitingKey));
      expect(label.left, greaterThanOrEqualTo(0));
      expect(label.right, lessThanOrEqualTo(320));
      expect(label.top, greaterThanOrEqualTo(0));
      expect(label.bottom, lessThanOrEqualTo(240));
      final creature = tester.renderObject<RenderBox>(
        find.byType(EntryCreature),
      );
      final canvasBottom = creature
          .localToGlobal(Offset(0, creature.size.height))
          .dy;
      expect(canvasBottom, lessThanOrEqualTo(label.top - 16));
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile(
          hoopitoGoldenFile('entry_waiting_${language}_compact'),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

const _goldenKey = Key('entry-golden');

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _harness({
  required ui.Image image,
  required double progress,
  String language = 'zh',
  bool waiting = false,
  double textScale = 1,
}) => MaterialApp(
  theme: buildHoopitoTheme(),
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(
        key: _goldenKey,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: HoopitoEntryFrame(
            image: image,
            mode: EntryMotionMode.standard,
            progress: progress,
            waitingLabel: waiting
                ? AppLocalizations.of(context)!.entryPreparingRecords
                : null,
          ),
        ),
      ),
    ),
  ),
);
