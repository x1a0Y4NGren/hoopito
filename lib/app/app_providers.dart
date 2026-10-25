import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hoopito/app/app_metadata.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_lifecycle_repository.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/data/repositories/player_career_repository.dart';
import 'package:hoopito/core/data/repositories/player_comparison_repository.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/automatic_backup_scheduler.dart';
import 'package:hoopito/core/export/device_automatic_backup_storage.dart';
import 'package:hoopito/core/export/device_export_gateway.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/settings/language_preferences.dart';
import 'package:hoopito/core/settings/motion_preference_cache.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/core/settings/theme_preferences.dart';
import 'package:hoopito/core/settings/scoring_guide_preferences.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/settings/settings_controller.dart';
import 'package:hoopito/features/players/player_career_controller.dart';
import 'package:hoopito/features/players/player_comparison_controller.dart';

/// The result of the pre-Drift compatibility probe. A legacy result is
/// deliberately a value instead of an exception so the app can show a clear
/// recovery screen without deleting or mutating the user's file.
enum DatabaseBootstrapKind { ready, incompatibleLegacy }

class DatabaseBootstrapState {
  const DatabaseBootstrapState.ready()
    : kind = DatabaseBootstrapKind.ready,
      version = null;

  const DatabaseBootstrapState.incompatibleLegacy(this.version)
    : kind = DatabaseBootstrapKind.incompatibleLegacy;

  final DatabaseBootstrapKind kind;
  final int? version;

  bool get isReady => kind == DatabaseBootstrapKind.ready;
}

typedef DatabaseCompatibilityProbe =
    Future<void> Function(AppDatabase database);

/// The composition root owns the production database. Tests override this
/// provider with an already-created in-memory database; value overrides do
/// not run the production close callback.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = openAppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

/// Kept separate from [appDatabaseProvider] so bootstrap tests can inject a
/// typed probe failure without opening or modifying a real user database.
final databaseCompatibilityProbeProvider = Provider<DatabaseCompatibilityProbe>(
  (ref) =>
      (database) => database.assertCompatible(),
);

final databaseBootstrapProvider = FutureProvider<DatabaseBootstrapState>((
  ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  try {
    await ref.watch(databaseCompatibilityProbeProvider)(database);
    return const DatabaseBootstrapState.ready();
  } on LegacySchemaDetectedException catch (legacy) {
    return DatabaseBootstrapState.incompatibleLegacy(legacy.version);
  }
});

typedef AppStartupTask = Future<void> Function();

extension AsyncValueNullable<ValueT> on AsyncValue<ValueT> {
  ValueT? get valueOrNull => value;
}

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.watch(appDatabaseProvider)),
);

final matchLifecycleRepositoryProvider = Provider<MatchLifecycleRepository>(
  (ref) => MatchLifecycleRepository(ref.watch(appDatabaseProvider)),
);

final playerRepositoryProvider = Provider<PlayerRepository>(
  (ref) => PlayerRepository(ref.watch(appDatabaseProvider)),
);

final playerCareerRepositoryProvider = Provider<PlayerCareerRepository>(
  (ref) => PlayerCareerRepository(ref.watch(appDatabaseProvider)),
);

final playerCareerControllerProvider = Provider.autoDispose
    .family<PlayerCareerController, String>((ref, playerId) {
      final repository = ref.watch(playerCareerRepositoryProvider);
      final controller = PlayerCareerController(
        playerId: playerId,
        loader: (query) => repository.watchByPlayerId(playerId, query: query),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final playerComparisonRepositoryProvider = Provider<PlayerComparisonRepository>(
  (ref) => PlayerComparisonRepository(ref.watch(appDatabaseProvider)),
);

final playerComparisonControllerProvider = Provider.autoDispose
    .family<PlayerComparisonController, String>((ref, playerId) {
      final repository = ref.watch(playerComparisonRepositoryProvider);
      final controller = PlayerComparisonController(
        playerId: playerId,
        listMatches: repository.listEligibleMatches,
        compare: repository.compare,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// The pre-game route consumes this stream directly so profile edits become
/// available without rebuilding the page's local setup controller.
final playerProfilesProvider = StreamProvider<List<Player>>((ref) {
  return ref.watch(playerRepositoryProvider).watchAll();
});

final ruleTemplateRepositoryProvider = Provider<RuleTemplateRepository>(
  (ref) => RuleTemplateRepository(ref.watch(appDatabaseProvider)),
);

final ruleTemplatesProvider = StreamProvider<List<RuleTemplate>>((ref) {
  final repository = ref.watch(ruleTemplateRepositoryProvider);
  return repository.watchAll();
});

final clockEngineProvider = Provider<ClockEngine>((ref) => const ClockEngine());

final scoringGuidePreferencesProvider = Provider<ScoringGuidePreferences>(
  (ref) => ScoringGuidePreferences(ref.watch(appDatabaseProvider)),
);
final scoringGuideSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(scoringGuidePreferencesProvider).hasSeen(),
);

final matchCommandServiceProvider = Provider<MatchCommandService>(
  (ref) => MatchCommandService(ref.watch(appDatabaseProvider)),
);

final backupCodecProvider = Provider<JsonBackupCodec>(
  (ref) => JsonBackupCodec(
    ref.watch(appDatabaseProvider),
    appVersion: hoopitoAppVersion,
  ),
);

final backupStorageProvider = Provider<DeviceAutomaticBackupStorage>(
  (ref) => DeviceAutomaticBackupStorage(),
);

final automaticBackupServiceProvider = Provider<AutomaticBackupService>((ref) {
  return AutomaticBackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(backupCodecProvider),
    storage: ref.watch(backupStorageProvider),
    scheduler: DeviceAutomaticBackupScheduler(),
  );
});

final scoringFeedbackPreferencesProvider =
    Provider<ScoringFeedbackPreferencesRepository>((ref) {
      return ScoringFeedbackPreferencesRepository(
        ref.watch(appDatabaseProvider),
      );
    });

final scoringFeedbackServiceProvider = Provider<ScoringFeedbackService>((ref) {
  return ScoringFeedbackService(
    ref.watch(scoringFeedbackPreferencesProvider),
    motionPreferenceCache: const PlatformMotionPreferenceCache(),
  );
});

final themePreferencesRepositoryProvider = Provider<ThemePreferencesRepository>(
  (ref) => ThemePreferencesRepository(ref.watch(appDatabaseProvider)),
);

/// The provider is kept alive for the app shell, while its initial value is
/// system so MaterialApp can render immediately and then react to the
/// persisted manual choice once the local database read completes.
final themePreferencesControllerProvider =
    ChangeNotifierProvider<ThemePreferencesController>((ref) {
      final controller = ThemePreferencesController(
        ref.watch(themePreferencesRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

final languagePreferencesRepositoryProvider =
    Provider<LanguagePreferencesRepository>((ref) {
      return LanguagePreferencesRepository(ref.watch(appDatabaseProvider));
    });

final languagePreferencesControllerProvider =
    ChangeNotifierProvider<LanguagePreferencesController>((ref) {
      final controller = LanguagePreferencesController(
        ref.watch(languagePreferencesRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

/// Startup tasks are function providers instead of hard-coded calls so a
/// provider container can verify ordering/counts without touching a user's
/// backup directory. The production functions still delegate to the real
/// repository/service instances owned by this composition root.
final startupEnsureBuiltInsProvider = Provider<AppStartupTask>((ref) {
  final repository = ref.watch(ruleTemplateRepositoryProvider);
  return repository.ensureBuiltIns;
});

final startupAutomaticBackupProvider = Provider<AppStartupTask>((ref) {
  final automaticBackup = ref.watch(automaticBackupServiceProvider);
  return () async {
    await automaticBackup.runIfDue();
  };
});

/// Compatibility errors remain visible to the bootstrap screen. Only the
/// optional automatic backup task is best-effort: a moved/unavailable backup
/// directory must not prevent the local app from opening.
final databaseStartupProvider = FutureProvider<DatabaseBootstrapState>((
  ref,
) async {
  final bootstrap = await ref.watch(databaseBootstrapProvider.future);
  if (!bootstrap.isReady) return bootstrap;

  // Repair persisted runtime triggers before the first domain UPSERT. Waiting
  // until backup.loadState() leaves older enabled backups unable to start.
  await ref.watch(appDatabaseProvider).ensureBackupDirtyTriggers();
  await ref.watch(startupEnsureBuiltInsProvider)();
  try {
    await ref.watch(startupAutomaticBackupProvider)();
  } on Object {
    // Automatic backup is an auxiliary startup task. Its next explicit or
    // scheduled run can retry after the directory is repaired.
  }
  return bootstrap;
});

final exportGatewayProvider = Provider<ExportGateway>((ref) {
  return DeviceExportGateway(backupStorage: ref.watch(backupStorageProvider));
});

final exportCoordinatorProvider = Provider<ExportCoordinator>((ref) {
  return ExportCoordinator(
    ref.watch(appDatabaseProvider),
    ref.watch(backupCodecProvider),
    gateway: ref.watch(exportGatewayProvider),
    automaticBackup: ref.watch(automaticBackupServiceProvider),
  );
});

/// The query tracks active_sessions, matches, participants, events, locations
/// and clocks. It is the only source of truth for resume cards and active
/// match gating after a process restart.
final activeMatchProvider = StreamProvider<MatchDetail?>((ref) {
  return ref.watch(matchRepositoryProvider).watchActiveMatch();
});

final historyProvider = StreamProvider<List<MatchHistoryEntry>>((ref) {
  return ref.watch(matchRepositoryProvider).watchHistory();
});

/// Home reads three bounded summaries without hydrating events per match.
final recentMatchSummariesProvider = StreamProvider<List<MatchHistoryEntry>>(
  (ref) => ref
      .watch(matchRepositoryProvider)
      .watchHistoryPage(limit: 3)
      .map((page) => page.entries),
);

final liveMatchProvider = StreamProvider.autoDispose
    .family<MatchDetail?, String>((ref, matchId) {
      return ref.watch(matchRepositoryProvider).watchLiveMatch(matchId);
    });

/// Optional presentation projection for Home's latest-result strip.
/// History already supplies newest-first, unarchived finished matches.
final latestFinishedMatchProvider = Provider<AsyncValue<MatchDetail?>>((ref) {
  final history = ref.watch(historyProvider);
  return history.when(
    loading: () => const AsyncLoading<MatchDetail?>(),
    error: (error, stackTrace) => AsyncError<MatchDetail?>(error, stackTrace),
    data: (entries) {
      if (entries.isEmpty) return const AsyncData<MatchDetail?>(null);
      return ref.watch(liveMatchProvider(entries.first.id));
    },
  );
});

/// A command-backed controller is reconstructed from the latest committed
/// projection. Subsequent Drift updates are applied to the same short-lived
/// controller, preserving a pending location only until its command commits.
final scoringControllerProvider = Provider.autoDispose
    .family<ScoringController?, String>((ref, matchId) {
      // Do not watch the live projection here. Watching it would invalidate
      // this provider on every committed score/location/clock write and
      // silently throw away controller-local interaction state (for example
      // a pending shot location). The live stream is listened to below and
      // only the first projection/terminal lifecycle transition invalidates
      // this provider.
      final initial = ref.read(liveMatchProvider(matchId)).valueOrNull;
      ScoringController? controller;
      if (initial != null && initial.match.lifecycle.name == 'active') {
        controller = ScoringController.fromCommittedProjection(
          initial,
          ref.read(matchCommandServiceProvider),
        );
      }
      ref.listen<AsyncValue<MatchDetail?>>(liveMatchProvider(matchId), (
        _,
        next,
      ) {
        final projection = next.valueOrNull;
        final isActive = projection?.match.lifecycle.name == 'active';
        if (controller == null) {
          if (isActive) {
            // The provider may have been first read while the stream was
            // loading. Re-evaluate once the initial committed projection is
            // available, then keep that controller stable for later writes.
            ref.invalidateSelf();
          }
          return;
        }
        if (!isActive) {
          ref.invalidateSelf();
          return;
        }
        controller.replaceCommittedProjection(projection!);
      });
      ref.onDispose(() => controller?.dispose());
      return controller;
    });

/// Settings is recreated when the active projection changes, so restore
/// gating cannot remain stale after abandon/finish or after process restore.
final settingsControllerProvider = Provider.autoDispose<SettingsController>((
  ref,
) {
  final activeState = ref.watch(activeMatchProvider);
  final canRestore = canRestoreBackupFor(activeState);
  final controller = SettingsController(
    exports: ref.watch(exportCoordinatorProvider),
    automaticBackup: ref.watch(automaticBackupServiceProvider),
    canRestoreBackup: canRestore,
    feedback: ref.watch(scoringFeedbackServiceProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Restore is safe only after the active-match query has settled successfully
/// to a genuine null. Riverpod may retain a previous value while refreshing,
/// so loading/error flags must be checked before inspecting [valueOrNull].
bool canRestoreBackupFor(AsyncValue<MatchDetail?> activeState) {
  return !activeState.isLoading &&
      !activeState.hasError &&
      activeState.hasValue &&
      activeState.valueOrNull == null;
}
