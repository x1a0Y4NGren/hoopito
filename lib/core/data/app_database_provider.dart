import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

AppDatabase createAppDatabase(QueryExecutor executor) {
  return AppDatabase(executor);
}

AppDatabase openAppDatabase() {
  return _openAppDatabaseAt(() async {
    final documents = await getApplicationDocumentsDirectory();
    return File(path.join(documents.path, 'hooptrace.sqlite'));
  });
}

/// Creates the same lazy, raw-probed database used by production, but for an
/// explicit file. Keeping the file resolver injectable makes it possible to
/// exercise the real v1 bootstrap path without replacing the compatibility
/// probe or touching the user's application directory.
AppDatabase openAppDatabaseAt(File file) {
  return _openAppDatabaseAt(
    () async => file,
    resolveTemporaryDirectory: () async => file.parent,
  );
}

AppDatabase _openAppDatabaseAt(
  Future<File> Function() resolveFile, {
  Future<Directory> Function()? resolveTemporaryDirectory,
}) {
  Future<File>? resolvedFile;
  Future<File> resolveOnce() => resolvedFile ??= resolveFile();
  return AppDatabase(
    LazyDatabase(() async {
      final file = await resolveOnce();
      final temporaryDirectory =
          await (resolveTemporaryDirectory?.call() ?? getTemporaryDirectory());
      final temporaryPath = temporaryDirectory.path;
      // The file is opened by Drift's worker isolate. Configure SQLite's
      // intermediate-result directory in that isolate as well, keeping all
      // database I/O within the application sandbox.
      return NativeDatabase.createInBackground(
        file,
        isolateSetup: _sqliteIsolateSetup(temporaryPath),
      );
    }),
    legacyVersionProbe: () async {
      final file = await resolveOnce();
      return StartupDiagnostics.measureSync(
        'legacy_version_probe',
        () => _legacyVersion(file),
      );
    },
  );
}

void Function() _sqliteIsolateSetup(String temporaryPath) {
  return () {
    sqlite3_lib.sqlite3.tempDirectory = temporaryPath;
  };
}

/// Opens the documented native file after a raw `user_version` probe.
Future<AppDatabase> openNativeAppDatabase() async {
  final documents = await getApplicationDocumentsDirectory();
  return openNativeAppDatabaseAt(
    File(path.join(documents.path, 'hooptrace.sqlite')),
  );
}

int? _legacyVersion(File file) {
  if (!file.existsSync()) return null;
  final raw = sqlite3_lib.sqlite3.open(file.path);
  try {
    return raw.userVersion == firstReleaseSchemaVersion
        ? raw.userVersion
        : null;
  } finally {
    raw.close();
  }
}

Future<AppDatabase> openNativeAppDatabaseAt(File file) async {
  final database = openAppDatabaseAt(file);
  try {
    await database.assertCompatible();
    return database;
  } on Object {
    await database.close();
    rethrow;
  }
}
