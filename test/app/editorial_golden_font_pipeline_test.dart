import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/editorial_masthead.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  testWidgets('production theme preserves body and display font roles', (
    tester,
  ) async {
    const bodyKey = Key('body-copy');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(
                'English body 中文正文',
                key: bodyKey,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const EditorialMasthead(title: 'English display 中文标题'),
            ],
          ),
        ),
      ),
    );

    final bodyStyle = tester.widget<Text>(find.byKey(bodyKey)).style!;
    final displayStyle = tester
        .widget<Text>(find.text('English display 中文标题'))
        .style!;
    expect(bodyStyle.fontFamily, isNot('Noto Sans SC'));
    expect(bodyStyle.fontFamilyFallback, contains('Noto Sans SC'));
    expect(displayStyle.fontFamily, HoopitoTypography.displayFamily);
    expect(displayStyle.fontFamilyFallback, contains('Noto Sans SC'));
  });

  testWidgets('golden font pipeline renders real Material Icons glyphs', (
    tester,
  ) async {
    const materialIcon = Key('material-icon');
    const missingGlyph = Key('missing-material-glyph');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: Row(
          textDirection: TextDirection.ltr,
          children: const [
            RepaintBoundary(
              key: materialIcon,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.tune, size: 32),
              ),
            ),
            RepaintBoundary(
              key: missingGlyph,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  IconData(0x10ffff, fontFamily: 'MaterialIcons'),
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await _capturePixels(tester, find.byKey(materialIcon)),
      isNot(equals(await _capturePixels(tester, find.byKey(missingGlyph)))),
      reason: 'Icons.tune must not render as the missing-glyph tofu box.',
    );
  });

  testWidgets('golden font pipeline renders real English body glyphs', (
    tester,
  ) async {
    const bodyGlyph = Key('body-glyph');
    final bodyStyle = buildHoopitoTheme().textTheme.bodyMedium!.copyWith(
      color: Colors.black,
      fontSize: 40,
      height: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: bodyGlyph,
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox.square(
                dimension: 64,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('A', style: bodyStyle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final raster = await _captureRaster(tester, find.byKey(bodyGlyph));
    final metrics = _measureDarkGlyph(raster);
    expect(
      metrics.backgroundRatioInsideBounds,
      // SDK Roboto measures 0.435 here, while the deliberate no-Roboto
      // mutation produces Ahem's 41x41 solid block at exactly 0.000. The 0.20
      // floor keeps wide anti-aliasing/platform tolerance without accepting a
      // substantially filled test-font box or coupling the gate to a hash.
      greaterThan(0.20),
      reason:
          'A production-theme Latin "A" must contain substantial white space '
          'inside its ink bounds (the counter and the area outside its angled '
          'strokes). Flutter test\'s Ahem fallback is a solid block with no such '
          'space. Raster metrics: $metrics',
    );
  });

  testWidgets('golden font pipeline renders real Chinese body glyphs', (
    tester,
  ) async {
    const bodyGlyph = Key('chinese-body-glyph');
    final bodyStyle = buildHoopitoTheme().textTheme.bodyMedium!.copyWith(
      color: Colors.black,
      fontSize: 40,
      height: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: bodyGlyph,
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox.square(
                dimension: 64,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('中', style: bodyStyle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final metrics = _measureDarkGlyph(
      await _captureRaster(tester, find.byKey(bodyGlyph)),
    );
    expect(
      metrics.backgroundRatioInsideBounds,
      greaterThan(0.15),
      reason:
          'A production-theme Chinese glyph must preserve the counters and '
          'stroke spacing of Noto Sans SC. Ahem/tofu renders as a filled '
          'test block. Raster metrics: $metrics',
    );
  });
}

final class _Raster {
  const _Raster({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final Uint8List pixels;
}

final class _GlyphMetrics {
  const _GlyphMetrics({
    required this.bounds,
    required this.inkPixels,
    required this.backgroundPixelsInsideBounds,
  });

  final Rect bounds;
  final int inkPixels;
  final int backgroundPixelsInsideBounds;

  double get backgroundRatioInsideBounds {
    final area = bounds.width.toInt() * bounds.height.toInt();
    return backgroundPixelsInsideBounds / area;
  }

  @override
  String toString() =>
      'bounds=$bounds, inkPixels=$inkPixels, '
      'backgroundPixelsInsideBounds=$backgroundPixelsInsideBounds, '
      'backgroundRatioInsideBounds='
      '${backgroundRatioInsideBounds.toStringAsFixed(3)}';
}

_GlyphMetrics _measureDarkGlyph(_Raster raster) {
  var minX = raster.width;
  var minY = raster.height;
  var maxX = -1;
  var maxY = -1;
  var inkPixels = 0;
  for (var y = 0; y < raster.height; y++) {
    for (var x = 0; x < raster.width; x++) {
      if (!_isDarkPixel(raster, x, y)) continue;
      inkPixels++;
      minX = x < minX ? x : minX;
      minY = y < minY ? y : minY;
      maxX = x > maxX ? x : maxX;
      maxY = y > maxY ? y : maxY;
    }
  }
  if (inkPixels == 0) {
    fail('The rendered Latin glyph contained no dark pixels.');
  }

  var backgroundPixels = 0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (_isWhitePixel(raster, x, y)) backgroundPixels++;
    }
  }
  return _GlyphMetrics(
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ),
    inkPixels: inkPixels,
    backgroundPixelsInsideBounds: backgroundPixels,
  );
}

bool _isDarkPixel(_Raster raster, int x, int y) {
  final offset = (y * raster.width + x) * 4;
  return raster.pixels[offset] < 224 &&
      raster.pixels[offset + 1] < 224 &&
      raster.pixels[offset + 2] < 224;
}

bool _isWhitePixel(_Raster raster, int x, int y) {
  final offset = (y * raster.width + x) * 4;
  return raster.pixels[offset] > 248 &&
      raster.pixels[offset + 1] > 248 &&
      raster.pixels[offset + 2] > 248;
}

Future<_Raster> _captureRaster(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final raster = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      image.dispose();
      return null;
    }
    final result = _Raster(
      width: image.width,
      height: image.height,
      pixels: Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
    image.dispose();
    return result;
  });
  if (raster == null) fail('Could not capture pixels for $finder.');
  return raster;
}

Future<Uint8List> _capturePixels(WidgetTester tester, Finder finder) async {
  return (await _captureRaster(tester, finder)).pixels;
}
