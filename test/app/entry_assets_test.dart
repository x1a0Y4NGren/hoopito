import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'application bundle excludes unused swish audio and Cupertino font',
    () async {
      final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        assets.listAssets(),
        isNot(contains('assets/audio/entry_swish.wav')),
      );
      final fonts =
          (jsonDecode(await rootBundle.loadString('FontManifest.json')) as List)
              .cast<Map<String, dynamic>>();
      final families = fonts.map((font) => font['family']).toList();
      expect(
        families,
        containsAll(['MaterialIcons', 'Barlow Condensed', 'Noto Sans SC']),
      );
      expect(
        families,
        isNot(contains('packages/cupertino_icons/CupertinoIcons')),
      );
    },
  );

  test('platform launch artwork has deterministic dimensions', () async {
    final expectedDimensions = <String, int>{
      'android/app/src/main/res/drawable-mdpi/launch_mark.png': 288,
      'android/app/src/main/res/drawable-hdpi/launch_mark.png': 432,
      'android/app/src/main/res/drawable-xhdpi/launch_mark.png': 576,
      'android/app/src/main/res/drawable-xxhdpi/launch_mark.png': 864,
      'android/app/src/main/res/drawable-xxxhdpi/launch_mark.png': 1152,
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 288,
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png': 576,
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png': 864,
    };

    for (final entry in expectedDimensions.entries) {
      final dimensions = await _pngDimensions(entry.key);
      expect(dimensions, (entry.value, entry.value), reason: entry.key);
    }
  });

  test('native launch screens use the fixed black brand surface', () {
    final android = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final android31 = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final androidNormal = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    final androidNormalNight = File(
      'android/app/src/main/res/values-night/styles.xml',
    ).readAsStringSync();
    final ios = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();

    expect(android, contains('@color/launch_background'));
    expect(android, contains('@drawable/launch_mark'));
    expect(android31, contains('android:windowSplashScreenAnimatedIcon'));
    expect(android31, contains('@drawable/launch_mark'));
    expect(
      androidNormal,
      contains(
        '<item name="android:windowBackground">'
        '@color/launch_background</item>',
      ),
    );
    expect(
      androidNormalNight,
      contains(
        '<item name="android:windowBackground">'
        '@color/launch_background</item>',
      ),
    );
    expect(ios, contains('red="0.06274509804"'));
    expect(ios, contains('image="LaunchImage"'));
  });

  test('native shells expose the lightweight entry motion cache', () {
    final android = File(
      'android/app/src/main/kotlin/io/github/x1a0y4ngren/hooptrace/'
      'MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    const channel = 'io.github.x1a0y4ngren.hooptrace/entry_motion_preference';

    expect(android, contains(channel));
    expect(android, contains('ENTRY_MOTION_PREFERENCES'));
    expect(android, contains('getDartEntrypointArgs'));
    expect(android, contains('--hoopito-entry-motion='));
    expect(android, contains('entryAnimationClaimed'));
    expect(android, contains('--hoopito-entry-animation=disabled'));
    expect(ios, contains(channel));
    expect(ios, contains('UserDefaults.standard'));
  });
}

Future<(int, int)> _pngDimensions(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
