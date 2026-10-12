import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hoopito/core/data/app_database.dart';

/// The persisted appearance choice. [system] deliberately remains the safe
/// default so a user's platform setting is respected until they choose a
/// manual lock.
enum AppThemePreference { system, light, dark }

const themePreferencesKey = 'appearance.theme.v1';
const _themePreferencesVersion = 1;

class ThemePreferencesRepository {
  ThemePreferencesRepository(this.database, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() now;

  AppThemePreference? _cached;
  Future<AppThemePreference>? _loading;
  Future<void> _writes = Future<void>.value();
  int _generation = 0;

  Future<AppThemePreference> load() {
    final cached = _cached;
    if (cached != null) return Future<AppThemePreference>.value(cached);
    final loading = _loading;
    if (loading != null) return loading;
    final requestGeneration = _generation;

    late final Future<AppThemePreference> future;
    future = _read()
        .then((value) {
          if (requestGeneration == _generation) _cached = value;
          return value;
        })
        .whenComplete(() {
          if (identical(_loading, future)) _loading = null;
        });
    _loading = future;
    return future;
  }

  Future<AppThemePreference> save(AppThemePreference preference) {
    final saveGeneration = ++_generation;
    late final Future<AppThemePreference> operation;
    operation = _writes.then((_) async {
      final value = jsonEncode({
        'version': _themePreferencesVersion,
        'preference': preference.name,
      });
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: themePreferencesKey,
              valueJson: value,
              updatedAt: now().toUtc(),
            ),
          );
      if (saveGeneration == _generation) _cached = preference;
      return preference;
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  void invalidate() {
    _generation++;
    _cached = null;
  }

  Future<AppThemePreference> _read() async {
    final row =
        await (database.select(database.appSettings)
              ..where((setting) => setting.key.equals(themePreferencesKey)))
            .getSingleOrNull();
    if (row == null) return AppThemePreference.system;
    try {
      final decoded = jsonDecode(row.valueJson);
      if (decoded is! Map ||
          decoded['version'] != _themePreferencesVersion ||
          decoded['preference'] is! String) {
        return AppThemePreference.system;
      }
      return AppThemePreference.values.firstWhere(
        (value) => value.name == decoded['preference'],
        orElse: () => AppThemePreference.system,
      );
    } on Object {
      return AppThemePreference.system;
    }
  }
}

/// Coordinates the persisted appearance preference with the Material app.
/// The initial in-memory value is system, so startup never flashes a theme
/// chosen by a previous process after the repository has loaded it.
class ThemePreferencesController extends ChangeNotifier {
  ThemePreferencesController(this.repository);

  final ThemePreferencesRepository repository;

  AppThemePreference _preference = AppThemePreference.system;
  Future<void>? _loading;
  int _generation = 0;
  bool _disposed = false;

  AppThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Future<void> load() {
    final loading = _loading;
    if (loading != null) return loading;
    final requestGeneration = _generation;
    late final Future<void> future;
    future = repository
        .load()
        .then((value) {
          if (requestGeneration != _generation) return;
          _preference = value;
          if (!_disposed) notifyListeners();
        })
        .whenComplete(() {
          if (identical(_loading, future)) _loading = null;
        });
    _loading = future;
    return future;
  }

  Future<void> setPreference(AppThemePreference preference) async {
    _generation++;
    await repository.save(preference);
    _preference = preference;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
