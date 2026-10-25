import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';

final _processEntryPlaybackSession = EntryPlaybackSession();

/// Application composition root. The optional database and provider overrides
/// are test seams; production ownership lives in [appDatabaseProvider].
class HoopitoApp extends StatelessWidget {
  const HoopitoApp({
    this.database,
    this.showEntryAnimation = true,
    this.initialMotionPreference,
    this.entryPlaybackSession,
    super.key,
  });

  final AppDatabase? database;
  final bool showEntryAnimation;
  final MotionPreference? initialMotionPreference;

  /// Tests can isolate playback ownership; production shares one process claim.
  final EntryPlaybackSession? entryPlaybackSession;

  @override
  Widget build(BuildContext context) {
    if (database == null) {
      return ProviderScope(
        child: _HoopitoAppView(
          showEntryAnimation: showEntryAnimation,
          initialMotionPreference: initialMotionPreference,
          entryPlaybackSession: entryPlaybackSession,
        ),
      );
    }
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database!)],
      child: _HoopitoAppView(
        showEntryAnimation: showEntryAnimation,
        initialMotionPreference: initialMotionPreference,
        entryPlaybackSession: entryPlaybackSession,
      ),
    );
  }
}

class _HoopitoAppView extends ConsumerStatefulWidget {
  const _HoopitoAppView({
    required this.showEntryAnimation,
    required this.initialMotionPreference,
    required this.entryPlaybackSession,
  });

  final bool showEntryAnimation;
  final MotionPreference? initialMotionPreference;
  final EntryPlaybackSession? entryPlaybackSession;

  @override
  ConsumerState<_HoopitoAppView> createState() => _HoopitoAppViewState();
}

class _HoopitoAppViewState extends ConsumerState<_HoopitoAppView> {
  // The bootstrap navigator becomes a Router when local startup is ready.
  // Preserve the entry timeline and its process claim across that handoff.
  final _entryGateKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(databaseStartupProvider);
    final themeMode = bootstrap.value?.isReady == true
        ? ref.watch(themePreferencesControllerProvider).themeMode
        : ThemeMode.system;
    final languageController = bootstrap.value?.isReady == true
        ? ref.watch(languagePreferencesControllerProvider)
        : null;
    final locale = languageController?.locale ?? const Locale('zh');
    Future<MotionPreference> motionPreferenceLoader() async {
      final initial = widget.initialMotionPreference;
      if (initial != null) return initial;
      final feedback = ref.read(scoringFeedbackServiceProvider);
      final cached = await feedback.loadCachedMotionPreference();
      if (cached != null) return cached;
      return (await feedback.load()).motion;
    }

    return bootstrap.when(
      loading: () => _buildMaterialApp(
        themeMode: themeMode,
        locale: locale,
        motionPreferenceLoader: motionPreferenceLoader,
        startupStatus: EntryStartupStatus.loading,
        home: const _BootstrapLoadingPage(),
      ),
      error: (error, stackTrace) => _buildMaterialApp(
        themeMode: themeMode,
        locale: locale,
        motionPreferenceLoader: motionPreferenceLoader,
        startupStatus: EntryStartupStatus.failure,
        home: const _BootstrapFailurePage(),
      ),
      data: (state) {
        if (!state.isReady) {
          return _buildMaterialApp(
            themeMode: themeMode,
            locale: locale,
            motionPreferenceLoader: motionPreferenceLoader,
            startupStatus: EntryStartupStatus.legacy,
            home: LegacyDatabaseBootstrapPage(version: state.version),
          );
        }
        if (languageController?.initialized != true) {
          return _buildMaterialApp(
            themeMode: themeMode,
            locale: locale,
            motionPreferenceLoader: motionPreferenceLoader,
            startupStatus: EntryStartupStatus.loading,
            home: const _BootstrapLoadingPage(),
          );
        }
        return _buildMaterialApp(
          themeMode: themeMode,
          locale: locale,
          motionPreferenceLoader: motionPreferenceLoader,
          startupStatus: EntryStartupStatus.ready,
          routerConfig: ref.watch(appRouterProvider),
        );
      },
    );
  }

  MaterialApp _buildMaterialApp({
    required ThemeMode themeMode,
    required Locale locale,
    required EntryMotionPreferenceLoader motionPreferenceLoader,
    required EntryStartupStatus startupStatus,
    Widget? home,
    GoRouter? routerConfig,
  }) {
    if (routerConfig != null) {
      return MaterialApp.router(
        title: 'Hoopito',
        onGenerateTitle: (context) =>
            AppLocalizations.of(context)?.appName ?? 'Hoopito',
        theme: buildHoopitoTheme(),
        darkTheme: buildHoopitoTheme(brightness: Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: widget.showEntryAnimation
            ? (context, child) => HoopitoEntryGate(
                key: _entryGateKey,
                motionPreferenceLoader: motionPreferenceLoader,
                playbackSession:
                    widget.entryPlaybackSession ?? _processEntryPlaybackSession,
                startupStatus: startupStatus,
                waitingLabel: AppLocalizations.of(
                  context,
                )!.entryPreparingRecords,
                child: child ?? const SizedBox.shrink(),
              )
            : null,
        routerConfig: routerConfig,
        debugShowCheckedModeBanner: false,
      );
    }
    return MaterialApp(
      title: 'Hoopito',
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appName ?? 'Hoopito',
      theme: buildHoopitoTheme(),
      darkTheme: buildHoopitoTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: widget.showEntryAnimation
          ? (context, child) => HoopitoEntryGate(
              key: _entryGateKey,
              motionPreferenceLoader: motionPreferenceLoader,
              playbackSession:
                  widget.entryPlaybackSession ?? _processEntryPlaybackSession,
              startupStatus: startupStatus,
              waitingLabel: AppLocalizations.of(context)!.entryPreparingRecords,
              child: child ?? const SizedBox.shrink(),
            )
          : null,
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}

class LegacyDatabaseBootstrapPage extends StatelessWidget {
  const LegacyDatabaseBootstrapPage({this.version, super.key});

  final int? version;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('legacy-bootstrap'),
      appBar: AppBar(title: Text(l10n.legacyBootstrapTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    l10n.legacyBootstrapHeadline,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.legacyBootstrapBody(
                      version == null ? '' : ' v$version',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapLoadingPage extends StatelessWidget {
  const _BootstrapLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoopitoStartupPlaceholder(
        waitingLabel: AppLocalizations.of(context)!.entryPreparingRecords,
      ),
    );
  }
}

class _BootstrapFailurePage extends StatelessWidget {
  const _BootstrapFailurePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.bootstrapFailureBody, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
