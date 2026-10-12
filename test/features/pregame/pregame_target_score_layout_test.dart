import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

import '../../support/golden_fonts.dart';

const _edit = Key('pregame-target-edit');
const _input = Key('pregame-target-input');

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final language in ['en', 'zh']) {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      testWidgets(
        '$language $mode target range remains visible at 200% with keyboard',
        (tester) async {
          await _openDialog(tester, language: language, brightness: brightness);
          final rangeMessage = language == 'en'
              ? 'Enter a whole number from 1 to 999'
              : '请输入 1～999 的整数';
          _expectRangeVisible(tester, rangeMessage);
          await _expectGolden(
            tester,
            'target_range_${language}_${mode}_200_keyboard',
          );

          await tester.enterText(find.byKey(_input), '1000');
          await tester.tap(find.byKey(const Key('pregame-target-confirm')));
          await tester.pumpAndSettle();
          _expectRangeVisible(tester, rangeMessage);
          await _expectGolden(
            tester,
            'target_error_${language}_${mode}_200_keyboard',
          );
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '$language $mode target range remains visible with Android nonlinear 200%',
        (tester) async {
          await _openDialog(
            tester,
            language: language,
            brightness: brightness,
            textScaler: const _AndroidLargeTextScaler(),
          );
          final rangeMessage = language == 'en'
              ? 'Enter a whole number from 1 to 999'
              : '请输入 1～999 的整数';
          _expectRangeVisible(tester, rangeMessage);
          await tester.enterText(find.byKey(_input), '1000');
          await tester.tap(find.byKey(const Key('pregame-target-confirm')));
          await tester.pumpAndSettle();
          _expectRangeVisible(tester, rangeMessage);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '$language $mode target range remains visible above a 312dp keyboard',
        (tester) async {
          await _openDialog(
            tester,
            language: language,
            brightness: brightness,
            keyboardInset: 312,
          );
          final rangeMessage = language == 'en'
              ? 'Enter a whole number from 1 to 999'
              : '请输入 1～999 的整数';
          _expectRangeVisible(tester, rangeMessage);
          await tester.enterText(find.byKey(_input), '1000');
          await tester.tap(find.byKey(const Key('pregame-target-confirm')));
          await tester.pumpAndSettle();
          _expectRangeVisible(tester, rangeMessage);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _openDialog(
  WidgetTester tester, {
  required String language,
  required Brightness brightness,
  TextScaler textScaler = const TextScaler.linear(2),
  double keyboardInset = 255,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHoopitoTheme(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const PregamePage(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('pregame-advanced')));
  await tester.tap(find.byKey(const Key('pregame-advanced')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(_edit));
  await tester.tap(find.byKey(_edit));
  await tester.pumpAndSettle();
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  tester.view.padding = const FakeViewPadding(top: 24);
  await tester.pumpAndSettle();
}

// Android's 200% system curve grows small text more than headings. A smaller
// intrinsic heading width must not force the actions onto two rows.
// Source: android.googlesource.com/platform/frameworks/base/+/refs/heads/main/
// core/java/android/content/res/FontScaleConverterFactory.java (scaleKey 2f).
class _AndroidLargeTextScaler extends TextScaler {
  const _AndroidLargeTextScaler();

  static const _sp = [8.0, 10.0, 12.0, 14.0, 18.0, 20.0, 24.0, 30.0, 100.0];
  static const _dp = [16.0, 20.0, 24.0, 26.0, 30.0, 34.0, 36.0, 38.0, 100.0];

  @override
  double get textScaleFactor => 2;

  @override
  double scale(double fontSize) {
    if (fontSize <= _sp.first) return fontSize * 2;
    for (var i = 1; i < _sp.length; i++) {
      if (fontSize <= _sp[i]) {
        final fraction = (fontSize - _sp[i - 1]) / (_sp[i] - _sp[i - 1]);
        return _dp[i - 1] + fraction * (_dp[i] - _dp[i - 1]);
      }
    }
    return fontSize;
  }
}

void _expectRangeVisible(WidgetTester tester, String message) {
  final range = find.text(message);
  expect(range, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(range);
  final viewport = tester.getRect(
    find
        .ancestor(of: range, matching: find.byType(SingleChildScrollView))
        .first,
  );
  final textBounds = tester.getRect(range);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    textBounds.bottom,
    lessThanOrEqualTo(viewport.bottom),
    reason:
        'The complete target range must fit above the action buttons. '
        'Text bounds: $textBounds; scroll viewport: $viewport.',
  );
  expect(textBounds.top, greaterThanOrEqualTo(viewport.top));
  final input = tester.getRect(
    find.descendant(
      of: find.byKey(_input),
      matching: find.byType(EditableText),
    ),
  );
  expect(input.top, greaterThanOrEqualTo(viewport.top));
  expect(input.bottom, lessThanOrEqualTo(viewport.bottom));
  final label = find.descendant(
    of: find.byKey(_input),
    matching: find.text(message.startsWith('Enter') ? 'Target score' : '目标分'),
  );
  final labelRender = tester.renderObject<RenderParagraph>(label);
  final labelBounds = MatrixUtils.transformRect(
    labelRender.getTransformTo(null),
    labelRender.paintBounds,
  );
  final surface = tester.getRect(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    ),
  );
  expect(
    labelBounds.top,
    greaterThanOrEqualTo(surface.top),
    reason:
        'The floating label must stay within the dialog surface. '
        'Label bounds: $labelBounds; surface: $surface.',
  );
  for (final action in ['pregame-target-confirm', 'pregame-target-cancel']) {
    final actionFinder = find.byKey(Key(action));
    final button = tester.getRect(actionFinder);
    expect(tester.getSize(actionFinder).height, greaterThanOrEqualTo(48));
    final keyboardTop =
        (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
        tester.view.devicePixelRatio;
    expect(button.bottom, lessThanOrEqualTo(keyboardTop));
  }
}

Future<void> _expectGolden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(hoopitoGoldenFile(name)),
  );
}
