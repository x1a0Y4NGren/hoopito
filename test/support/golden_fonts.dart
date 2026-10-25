import 'dart:io';

import 'package:flutter/services.dart';

String hoopitoGoldenFile(String name) =>
    Platform.isLinux ? 'goldens/${name}_linux.png' : 'goldens/$name.png';

Future<void> loadHoopitoGoldenFonts() async {
  await (FontLoader(
    'Noto Sans SC',
  )..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.otf'))).load();
  await (FontLoader('Barlow Condensed')
        ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-Bold.ttf')))
      .load();

  final sdkFonts = _flutterMaterialFontsDirectory();
  await (FontLoader('Roboto')
        ..addFont(_readFontFile(_fontNamed(sdkFonts, 'roboto-regular.ttf')))
        ..addFont(_readFontFile(_fontNamed(sdkFonts, 'roboto-medium.ttf')))
        ..addFont(_readFontFile(_fontNamed(sdkFonts, 'roboto-bold.ttf'))))
      .load();
  final materialIcons = _fontNamed(sdkFonts, 'materialicons-regular.otf');
  await (FontLoader(
    'MaterialIcons',
  )..addFont(_readFontFile(materialIcons))).load();
}

Directory _flutterMaterialFontsDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = Directory(
      [
        directory.path,
        'artifacts',
        'material_fonts',
      ].join(Platform.pathSeparator),
    );
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError(
    'Could not locate the Flutter SDK Material Icons font from '
    '${Platform.resolvedExecutable}.',
  );
}

File _fontNamed(Directory directory, String expectedName) {
  for (final entry in directory.listSync()) {
    if (entry is File &&
        entry.uri.pathSegments.last.toLowerCase() ==
            expectedName.toLowerCase()) {
      return entry;
    }
  }
  throw StateError(
    'Flutter SDK font $expectedName not found in ${directory.path}.',
  );
}

Future<ByteData> _readFontFile(File file) async {
  return ByteData.sublistView(await file.readAsBytes());
}
