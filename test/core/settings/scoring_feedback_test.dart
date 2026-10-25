import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/settings/motion_preference_cache.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('defaults to haptic enabled and sound disabled', () async {
    final database = createTestDatabase();
    final repository = ScoringFeedbackPreferencesRepository(database);

    expect(
      await repository.load(),
      const ScoringFeedbackPreferences.defaults(),
    );
  });

  test(
    'legacy payloads default motion to standard and unknown motion is safe',
    () async {
      final database = createTestDatabase();
      final now = DateTime.utc(2026, 8, 25);
      await database
          .into(database.appSettings)
          .insert(
            AppSetting(
              key: scoringFeedbackPreferencesKey,
              valueJson: jsonEncode({
                'version': 1,
                'haptic': false,
                'sound': true,
              }),
              updatedAt: now,
            ),
          );
      expect(
        (await ScoringFeedbackPreferencesRepository(database).load()).motion,
        MotionPreference.standard,
      );

      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: scoringFeedbackPreferencesKey,
              valueJson: jsonEncode({
                'version': 1,
                'haptic': false,
                'sound': true,
                'motion': 'future-mode',
              }),
              updatedAt: now,
            ),
          );
      expect(
        (await ScoringFeedbackPreferencesRepository(database).load()).motion,
        MotionPreference.standard,
      );
    },
  );

  test(
    'motion preference round trips with stable JSON field ordering',
    () async {
      final database = createTestDatabase();
      final repository = ScoringFeedbackPreferencesRepository(database);

      final saved = await repository.update(
        haptic: false,
        sound: true,
        motion: MotionPreference.reduced,
      );
      expect(saved.motion, MotionPreference.reduced);
      final row =
          await (database.select(database.appSettings)..where(
                (setting) => setting.key.equals(scoringFeedbackPreferencesKey),
              ))
              .getSingle();
      expect(
        row.valueJson,
        '{"version":1,"haptic":false,"sound":true,"motion":"reduced"}',
      );
      expect(
        await ScoringFeedbackPreferencesRepository(database).load(),
        saved,
      );
    },
  );

  test('malformed and unknown preference payloads fall back safely', () async {
    final database = createTestDatabase();
    final now = DateTime.utc(2026, 8, 23);
    await database
        .into(database.appSettings)
        .insert(
          AppSetting(
            key: scoringFeedbackPreferencesKey,
            valueJson: '{not-json',
            updatedAt: now,
          ),
        );
    final malformed = ScoringFeedbackPreferencesRepository(database);
    expect(await malformed.load(), const ScoringFeedbackPreferences.defaults());

    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSetting(
            key: scoringFeedbackPreferencesKey,
            valueJson: jsonEncode({
              'version': 99,
              'haptic': false,
              'sound': true,
            }),
            updatedAt: now,
          ),
        );
    final unknownVersion = ScoringFeedbackPreferencesRepository(database);
    expect(
      await unknownVersion.load(),
      const ScoringFeedbackPreferences.defaults(),
    );
  });

  test('round trips updates through AppSettings', () async {
    final database = createTestDatabase();
    final repository = ScoringFeedbackPreferencesRepository(database);

    final saved = await repository.update(haptic: false, sound: true);
    expect(saved.haptic, isFalse);
    expect(saved.sound, isTrue);

    final reloaded = ScoringFeedbackPreferencesRepository(database);
    expect(await reloaded.load(), saved);
  });

  test(
    'updates remain usable after backup dirty triggers are installed while disabled',
    () async {
      final database = createTestDatabase();
      await database.ensureBackupDirtyTriggers();
      final repository = ScoringFeedbackPreferencesRepository(database);

      expect(
        await repository.update(haptic: false, sound: true),
        const ScoringFeedbackPreferences(haptic: false, sound: true),
      );
      expect(
        await repository.update(haptic: true),
        const ScoringFeedbackPreferences(haptic: true, sound: true),
      );
    },
  );

  test(
    'reload observes a restored AppSettings row after invalidation',
    () async {
      final database = createTestDatabase();
      final repository = ScoringFeedbackPreferencesRepository(database);
      await repository.update(haptic: false, sound: true);

      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: scoringFeedbackPreferencesKey,
              valueJson: jsonEncode({
                'version': 1,
                'haptic': true,
                'sound': false,
              }),
              updatedAt: DateTime.utc(2026, 8, 23),
            ),
          );
      expect(
        await repository.load(),
        const ScoringFeedbackPreferences(haptic: false, sound: true),
      );
      repository.invalidate();
      expect(
        await repository.load(),
        const ScoringFeedbackPreferences(haptic: true, sound: false),
      );
    },
  );

  test(
    'motion listenable tracks effective load, write, and restore changes',
    () async {
      final database = createTestDatabase();
      final repository = ScoringFeedbackPreferencesRepository(database);
      final service = ScoringFeedbackService(repository);
      final changes = <MotionPreference>[];
      service.motionPreferenceListenable.addListener(() {
        changes.add(service.motionPreferenceListenable.value);
      });

      await service.load();
      expect(changes, isEmpty);
      await service.setMotionPreference(MotionPreference.reduced);
      expect(changes, [MotionPreference.reduced]);
      await service.load();
      expect(changes, [MotionPreference.reduced]);

      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: scoringFeedbackPreferencesKey,
              valueJson: jsonEncode({
                'version': 1,
                'haptic': true,
                'sound': false,
                'motion': 'standard',
              }),
              updatedAt: DateTime.utc(2026, 8, 26),
            ),
          );
      await service.reload();
      expect(changes, [MotionPreference.reduced, MotionPreference.standard]);
    },
  );

  test('serialized writes publish each effective motion change once', () async {
    final database = createTestDatabase();
    final repository = ScoringFeedbackPreferencesRepository(database);
    final changes = <MotionPreference>[];
    repository.motionPreferenceListenable.addListener(() {
      changes.add(repository.motionPreferenceListenable.value);
    });

    await Future.wait([
      repository.update(motion: MotionPreference.reduced),
      repository.update(motion: MotionPreference.standard),
    ]);

    expect(changes, [MotionPreference.reduced, MotionPreference.standard]);
  });

  test(
    'service mirrors loaded and updated motion into the entry cache',
    () async {
      final database = createTestDatabase();
      final cache = _FakeMotionPreferenceCache();
      final service = ScoringFeedbackService(
        ScoringFeedbackPreferencesRepository(database),
        motionPreferenceCache: cache,
      );

      expect(await service.loadCachedMotionPreference(), isNull);
      await service.load();
      expect(cache.writes, [MotionPreference.standard]);

      await service.setMotionPreference(MotionPreference.reduced);
      expect(cache.writes, [
        MotionPreference.standard,
        MotionPreference.reduced,
      ]);
      expect(
        await service.loadCachedMotionPreference(),
        MotionPreference.reduced,
      );
    },
  );

  test('entry cache failures never fail settings persistence', () async {
    final database = createTestDatabase();
    final cache = _FakeMotionPreferenceCache()..throws = true;
    final service = ScoringFeedbackService(
      ScoringFeedbackPreferencesRepository(database),
      motionPreferenceCache: cache,
    );

    expect(await service.loadCachedMotionPreference(), isNull);
    await expectLater(service.load(), completes);
    await expectLater(
      service.setMotionPreference(MotionPreference.reduced),
      completes,
    );
    expect(
      (await ScoringFeedbackPreferencesRepository(database).load()).motion,
      MotionPreference.reduced,
    );
  });

  test('a stalled entry cache never blocks settings persistence', () async {
    final database = createTestDatabase();
    final cache = _FakeMotionPreferenceCache()..hangs = true;
    final service = ScoringFeedbackService(
      ScoringFeedbackPreferencesRepository(database),
      motionPreferenceCache: cache,
    );

    await service.load().timeout(const Duration(seconds: 1));
    await service
        .setMotionPreference(MotionPreference.reduced)
        .timeout(const Duration(seconds: 1));

    expect(
      (await ScoringFeedbackPreferencesRepository(database).load()).motion,
      MotionPreference.reduced,
    );
  });

  test('concurrent loads share one in-flight read', () async {
    final database = createTestDatabase();
    final repository = ScoringFeedbackPreferencesRepository(database);

    final values = await Future.wait([
      repository.load(),
      repository.load(),
      repository.load(),
    ]);

    expect(values, everyElement(const ScoringFeedbackPreferences.defaults()));
  });

  test(
    'invalidate starts a fresh read and stale completion cannot overwrite it',
    () async {
      final database = createTestDatabase();
      final oldRead = Completer<ScoringFeedbackPreferences>();
      final freshRead = Completer<ScoringFeedbackPreferences>();
      var reads = 0;
      final repository = ScoringFeedbackPreferencesRepository(
        database,
        read: () {
          reads++;
          return reads == 1 ? oldRead.future : freshRead.future;
        },
      );

      final oldLoad = repository.load();
      repository.invalidate();
      final freshLoad = repository.load();
      freshRead.complete(
        const ScoringFeedbackPreferences(haptic: false, sound: true),
      );
      expect(
        await freshLoad,
        const ScoringFeedbackPreferences(haptic: false, sound: true),
      );
      oldRead.complete(const ScoringFeedbackPreferences.defaults());
      await oldLoad;

      expect(
        await repository.load(),
        const ScoringFeedbackPreferences(haptic: false, sound: true),
      );
      expect(reads, 2);
    },
  );

  test(
    'stale in-flight reads do not publish a lost motion preference',
    () async {
      final database = createTestDatabase();
      final oldRead = Completer<ScoringFeedbackPreferences>();
      final freshRead = Completer<ScoringFeedbackPreferences>();
      var reads = 0;
      final repository = ScoringFeedbackPreferencesRepository(
        database,
        read: () {
          reads++;
          return reads == 1 ? oldRead.future : freshRead.future;
        },
      );
      final changes = <MotionPreference>[];
      repository.motionPreferenceListenable.addListener(() {
        changes.add(repository.motionPreferenceListenable.value);
      });

      final oldLoad = repository.load();
      repository.invalidate();
      final freshLoad = repository.load();
      freshRead.complete(
        const ScoringFeedbackPreferences(
          haptic: true,
          sound: false,
          motion: MotionPreference.reduced,
        ),
      );
      await freshLoad;
      oldRead.complete(const ScoringFeedbackPreferences.defaults());
      await oldLoad;

      expect(changes, [MotionPreference.reduced]);
      expect(reads, 2);
    },
  );

  test('feedback platform failures are isolated per channel', () async {
    final database = createTestDatabase();
    final platform = _FakePlatform()
      ..throwOnHaptic = true
      ..throwOnSound = true;
    final repository = ScoringFeedbackPreferencesRepository(database);
    await repository.update(haptic: true, sound: true);
    final service = ScoringFeedbackService(repository, platform: platform);

    await expectLater(service.emitCommitted(), completes);
    expect(platform.hapticCalls, 1);
    expect(platform.soundCalls, 1);
  });

  test(
    'committed feedback follows haptic-only, sound-only, and both settings',
    () async {
      final database = createTestDatabase();
      final repository = ScoringFeedbackPreferencesRepository(database);
      final platform = _FakePlatform();
      final service = ScoringFeedbackService(repository, platform: platform);

      await service.emitCommitted();
      expect(platform.hapticCalls, 1);
      expect(platform.soundCalls, 0);

      await service.update(haptic: false, sound: true);
      await service.emitCommitted();
      expect(platform.hapticCalls, 1);
      expect(platform.soundCalls, 1);

      await service.update(haptic: true, sound: true);
      await service.emitCommitted();
      expect(platform.hapticCalls, 2);
      expect(platform.soundCalls, 2);
    },
  );
}

class _FakePlatform implements ScoringFeedbackPlatform {
  bool throwOnHaptic = false;
  bool throwOnSound = false;
  int hapticCalls = 0;
  int soundCalls = 0;

  @override
  Future<void> lightImpact() async {
    hapticCalls++;
    if (throwOnHaptic) throw StateError('haptic unavailable');
  }

  @override
  Future<void> click() async {
    soundCalls++;
    if (throwOnSound) throw StateError('sound unavailable');
  }
}

class _FakeMotionPreferenceCache implements MotionPreferenceCache {
  MotionPreference? value;
  bool throws = false;
  bool hangs = false;
  final writes = <MotionPreference>[];

  @override
  Future<MotionPreference?> read() async {
    if (throws) throw StateError('cache unavailable');
    return value;
  }

  @override
  Future<void> write(MotionPreference preference) async {
    if (throws) throw StateError('cache unavailable');
    if (hangs) return Completer<void>().future;
    value = preference;
    writes.add(preference);
  }
}
