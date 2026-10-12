import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hoopito/core/data/app_database.dart';

enum AppLanguagePreference { chinese, english }

const languagePreferencesKey = 'localization.language.v1';
const _languagePreferencesVersion = 1;

class LanguagePreferencesRepository {
  LanguagePreferencesRepository(this.database, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() now;

  AppLanguagePreference? _cached;
  Future<AppLanguagePreference>? _loading;
  Future<void> _writes = Future<void>.value();
  int _generation = 0;

  Future<AppLanguagePreference> load() {
    final cached = _cached;
    if (cached != null) return Future<AppLanguagePreference>.value(cached);
    final loading = _loading;
    if (loading != null) return loading;
    final requestGeneration = _generation;

    late final Future<AppLanguagePreference> future;
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

  Future<AppLanguagePreference> save(AppLanguagePreference preference) {
    final saveGeneration = ++_generation;
    late final Future<AppLanguagePreference> operation;
    operation = _writes.then((_) async {
      final value = jsonEncode({
        'version': _languagePreferencesVersion,
        'preference': preference.name,
      });
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: languagePreferencesKey,
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

  Future<AppLanguagePreference> _read() async {
    final row =
        await (database.select(database.appSettings)
              ..where((setting) => setting.key.equals(languagePreferencesKey)))
            .getSingleOrNull();
    if (row == null) return AppLanguagePreference.chinese;
    try {
      final decoded = jsonDecode(row.valueJson);
      if (decoded is! Map ||
          decoded['version'] != _languagePreferencesVersion ||
          decoded['preference'] is! String) {
        return AppLanguagePreference.chinese;
      }
      return AppLanguagePreference.values.firstWhere(
        (value) => value.name == decoded['preference'],
        orElse: () => AppLanguagePreference.chinese,
      );
    } on Object {
      return AppLanguagePreference.chinese;
    }
  }
}

class LanguagePreferencesController extends ChangeNotifier {
  LanguagePreferencesController(this.repository);

  final LanguagePreferencesRepository repository;

  AppLanguagePreference _preference = AppLanguagePreference.chinese;
  bool _initialized = false;
  Future<void>? _loading;
  int _generation = 0;
  bool _disposed = false;

  AppLanguagePreference get preference => _preference;
  bool get initialized => _initialized;

  Locale get locale => switch (_preference) {
    AppLanguagePreference.chinese => const Locale('zh'),
    AppLanguagePreference.english => const Locale('en'),
  };

  Future<void> load() {
    final loading = _loading;
    if (loading != null) return loading;
    final requestGeneration = _generation;
    late final Future<void> future;
    future =
        (() async {
          try {
            final value = await repository.load();
            if (requestGeneration != _generation) return;
            _preference = value;
          } on Object {
            if (requestGeneration != _generation) return;
            _preference = AppLanguagePreference.chinese;
          }
          _initialized = true;
          if (!_disposed) notifyListeners();
        })().whenComplete(() {
          if (identical(_loading, future)) _loading = null;
        });
    _loading = future;
    return future;
  }

  Future<void> setPreference(AppLanguagePreference preference) async {
    _generation++;
    await repository.save(preference);
    _preference = preference;
    _initialized = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
