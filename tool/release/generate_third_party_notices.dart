import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final repository = Directory.current;
  final configFile = File(
    '${repository.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}package_config.json',
  );
  if (!configFile.existsSync()) {
    stderr.writeln('Run flutter pub get before generating notices.');
    exitCode = 2;
    return;
  }
  final config = jsonDecode(await configFile.readAsString()) as Map;
  final configDirectory = configFile.parent.uri;
  final packages =
      (config['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['name'] != 'hoopito')
          .toList()
        ..sort(
          (left, right) =>
              (left['name'] as String).compareTo(right['name'] as String),
        );

  final groups = <String, _NoticeGroup>{};
  final missing = <String>[];
  for (final package in packages) {
    final name = package['name'] as String;
    final root = Directory.fromUri(
      configDirectory.resolve(package['rootUri'] as String),
    );
    final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
    final version = pubspec.existsSync()
        ? RegExp(
                r'^version:\s*([^\s#]+)',
                multiLine: true,
              ).firstMatch(await pubspec.readAsString())?.group(1) ??
              'SDK'
        : 'SDK';
    final license = _findLicense(root, includeAncestors: version == 'SDK');
    if (license == null) {
      missing.add('$name $version');
      continue;
    }
    final body = (await license.readAsString()).replaceAll('\r\n', '\n').trim();
    groups
        .putIfAbsent(body, () => _NoticeGroup(body))
        .packages
        .add('$name $version');
  }
  if (missing.isNotEmpty) {
    stderr.writeln('Missing license files: ${missing.join(', ')}');
    exitCode = 3;
    return;
  }

  final androidCoordinates = File(
    '${repository.path}${Platform.pathSeparator}third_party'
    '${Platform.pathSeparator}android_runtime'
    '${Platform.pathSeparator}coordinates.txt',
  );
  if (!androidCoordinates.existsSync()) {
    stderr.writeln('Missing Android release-runtime coordinate manifest.');
    exitCode = 4;
    return;
  }
  final androidComponents = const LineSplitter()
      .convert(await androidCoordinates.readAsString())
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  final coordinatePattern = RegExp(r'^[^:\s]+:[^:\s]+:[^:\s]+$');
  if (androidComponents.isEmpty ||
      androidComponents.any(
        (coordinate) => !coordinatePattern.hasMatch(coordinate),
      )) {
    stderr.writeln(
      'Android runtime coordinate manifest contains an invalid entry.',
    );
    exitCode = 5;
    return;
  }
  final sortedCoordinates = [...androidComponents]..sort();
  if (!_sameStrings(androidComponents, sortedCoordinates) ||
      androidComponents.toSet().length != androidComponents.length) {
    stderr.writeln(
      'Android runtime coordinate manifest must be sorted and duplicate-free.',
    );
    exitCode = 6;
    return;
  }
  if (!androidComponents.contains('androidx.work:work-runtime-ktx:2.11.2')) {
    stderr.writeln(
      'Android runtime manifest does not contain WorkManager 2.11.2.',
    );
    exitCode = 7;
    return;
  }

  final apacheLicense = await _findCompleteApacheLicense(
    packages,
    configDirectory,
  );
  if (apacheLicense == null) {
    stderr.writeln('Unable to resolve a complete Apache-2.0 license text.');
    exitCode = 8;
    return;
  }
  final apacheBody = (await apacheLicense.readAsString())
      .replaceAll('\r\n', '\n')
      .trim();
  final androidGroup = groups.putIfAbsent(
    apacheBody,
    () => _NoticeGroup(apacheBody),
  );
  for (final coordinate in androidComponents) {
    androidGroup.packages.add('Android/Maven release runtime: $coordinate');
  }

  final sortedGroups = groups.values.toList()
    ..sort(
      (left, right) => left.packages.first.compareTo(right.packages.first),
    );
  final output = StringBuffer()
    ..writeln('# Third-party notices')
    ..writeln()
    ..writeln(
      'This file contains the license notices for every package in the resolved '
      'Flutter package graph, the vendored SQLite amalgamation, and every '
      'component in the pinned Android/Maven release-runtime graph.',
    )
    ..writeln()
    ..writeln(
      'Regenerate after dependency changes with '
      '`dart --packages=.dart_tool/package_config.json '
      'tool/release/generate_third_party_notices.dart`.',
    )
    ..writeln();
  final vendoredSqliteLicense = File(
    '${repository.path}${Platform.pathSeparator}third_party'
    '${Platform.pathSeparator}sqlite${Platform.pathSeparator}LICENSE.sqlite',
  );
  if (vendoredSqliteLicense.existsSync()) {
    output
      ..writeln('## Vendored SQLite amalgamation 3.53.4')
      ..writeln();
    for (final line in const LineSplitter().convert(
      await vendoredSqliteLicense.readAsString(),
    )) {
      output.writeln('    $line');
    }
    output.writeln();
  }
  for (final group in sortedGroups) {
    group.packages.sort();
    output
      ..writeln('## ${group.packages.join(', ')}')
      ..writeln();
    for (final line in const LineSplitter().convert(group.licenseText)) {
      output.writeln('    $line');
    }
    output.writeln();
  }
  final outputFile = File(
    '${repository.path}${Platform.pathSeparator}docs'
    '${Platform.pathSeparator}legal'
    '${Platform.pathSeparator}THIRD_PARTY_NOTICES.md',
  );
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(output.toString());
  stdout.writeln(
    'Wrote ${packages.length} package notices in ${groups.length} license groups.',
  );
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Future<File?> _findCompleteApacheLicense(
  List<Map<String, dynamic>> packages,
  Uri configDirectory,
) async {
  for (final package in packages) {
    final root = Directory.fromUri(
      configDirectory.resolve(package['rootUri'] as String),
    );
    final license = _findLicense(root, includeAncestors: false);
    if (license == null) continue;
    final body = (await license.readAsString()).replaceAll('\r\n', '\n');
    if (body.length >= 5000 &&
        body.contains('Apache License') &&
        body.contains('Version 2.0') &&
        body.contains(
          'TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION',
        ) &&
        body.contains('END OF TERMS AND CONDITIONS')) {
      return license;
    }
  }
  return null;
}

File? _findLicense(Directory root, {required bool includeAncestors}) {
  if (!root.existsSync()) return null;
  var directory = root;
  for (var depth = 0; depth < (includeAncestors ? 6 : 1); depth++) {
    final found = _licenseIn(directory);
    if (found != null) return found;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}

File? _licenseIn(Directory directory) {
  final candidates =
      directory.listSync(followLinks: false).whereType<File>().where((file) {
        final name = file.uri.pathSegments.last.toUpperCase();
        return name == 'LICENSE' ||
            name == 'LICENCE' ||
            name.startsWith('LICENSE.') ||
            name.startsWith('LICENCE.') ||
            name == 'COPYING';
      }).toList()..sort((left, right) => left.path.compareTo(right.path));
  return candidates.firstOrNull;
}

class _NoticeGroup {
  _NoticeGroup(this.licenseText);

  final String licenseText;
  final List<String> packages = [];
}
