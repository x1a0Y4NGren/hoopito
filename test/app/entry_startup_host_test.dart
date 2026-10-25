import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/app/entry/entry_renderer_ready.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/settings/language_preferences.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/history/history_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rendererChannel = MethodChannel(entryRendererChannelName);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(rendererChannel, (_) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(rendererChannel, null);
  });

  testWidgets('slow startup keeps the brand visible without a spinner', (
    tester,
  ) async {
    final startup = Completer<DatabaseBootstrapState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.reduced,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(hoopitoEntryOverlayKey), findsOneWidget);
    expect(find.text('正在打开本地记录…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('database and language readiness preserve one entry state', (
    tester,
  ) async {
    final database = createTestDatabase();
    final startup = Completer<DatabaseBootstrapState>();
    final language = LanguagePreferencesController(
      LanguagePreferencesRepository(database),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          databaseStartupProvider.overrideWith((ref) => startup.future),
          languagePreferencesControllerProvider.overrideWith((ref) => language),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.reduced,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    final entryState = tester.state(find.byType(HoopitoEntryGate));
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.loading);

    startup.complete(const DatabaseBootstrapState.ready());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.loading);
    expect(tester.state(find.byType(HoopitoEntryGate)), same(entryState));
    expect(find.byKey(const Key('home-start-scoring')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await language.setPreference(AppLanguagePreference.english);
    await tester.pumpAndSettle();
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.ready);
    expect(tester.state(find.byType(HoopitoEntryGate)), same(entryState));
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(find.byKey(const Key('home-start-scoring')), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(_entryGate(tester).waitingLabel, 'Opening local records…');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup failure bypasses the unfinished entry immediately', (
    tester,
  ) async {
    final startup = Completer<DatabaseBootstrapState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.standard,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    final entryState = tester.state(find.byType(HoopitoEntryGate));
    startup.completeError(StateError('startup failed'));
    await tester.pump();
    await tester.pump();

    expect(_entryGate(tester).startupStatus, EntryStartupStatus.failure);
    expect(tester.state(find.byType(HoopitoEntryGate)), same(entryState));
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(
      find.text(AppLocalizationsZh().bootstrapFailureBody),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('legacy bootstrap bypasses the unfinished entry immediately', (
    tester,
  ) async {
    final startup = Completer<DatabaseBootstrapState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.standard,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    final entryState = tester.state(find.byType(HoopitoEntryGate));
    startup.complete(const DatabaseBootstrapState.incompatibleLegacy(1));
    await tester.pump();
    await tester.pump();

    expect(_entryGate(tester).startupStatus, EntryStartupStatus.legacy);
    expect(tester.state(find.byType(HoopitoEntryGate)), same(entryState));
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(find.byKey(const Key('legacy-bootstrap')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('consumed process session retains static slow-startup content', (
    tester,
  ) async {
    final session = EntryPlaybackSession();
    final startup = Completer<DatabaseBootstrapState>();
    Widget app() => ProviderScope(
      overrides: [
        databaseStartupProvider.overrideWith((ref) => startup.future),
      ],
      child: HoopitoApp(
        initialMotionPreference: MotionPreference.reduced,
        entryPlaybackSession: session,
      ),
    );
    await tester.pumpWidget(app());
    expect(find.byKey(hoopitoEntryOverlayKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    expect(find.byType(HoopitoStartupPlaceholder), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('正在打开本地记录…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disabled animation retains static slow-startup content', (
    tester,
  ) async {
    final startup = Completer<DatabaseBootstrapState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    expect(find.byType(HoopitoStartupPlaceholder), findsOneWidget);
    expect(find.text('正在打开本地记录…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('正在打开本地记录…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup handoff preserves the initial deep link', (
    tester,
  ) async {
    final database = createTestDatabase();
    final startup = Completer<DatabaseBootstrapState>();
    tester.platformDispatcher.defaultRouteNameTestValue = '/history';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          databaseStartupProvider.overrideWith((ref) => startup.future),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.reduced,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    startup.complete(const DatabaseBootstrapState.ready());
    await _pumpUntil(
      tester,
      () => find.byType(HistoryPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byKey(hoopitoEntryOverlayKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('entry retains compatibility, built-ins, then backup ordering', (
    tester,
  ) async {
    final database = createTestDatabase();
    final compatibility = Completer<void>();
    final builtIns = Completer<void>();
    final backup = Completer<void>();
    final started = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          databaseCompatibilityProbeProvider.overrideWith((ref) {
            return (database) {
              started.add('compatibility');
              return compatibility.future;
            };
          }),
          startupEnsureBuiltInsProvider.overrideWith((ref) {
            return () {
              started.add('built-ins');
              return builtIns.future;
            };
          }),
          startupAutomaticBackupProvider.overrideWith((ref) {
            return () {
              started.add('backup');
              return backup.future;
            };
          }),
        ],
        child: HoopitoApp(
          initialMotionPreference: MotionPreference.reduced,
          entryPlaybackSession: EntryPlaybackSession(),
        ),
      ),
    );
    expect(started, ['compatibility']);
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.loading);

    compatibility.complete();
    await _pumpUntil(tester, () => started.length == 2);
    expect(started, ['compatibility', 'built-ins']);
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.loading);

    builtIns.complete();
    await _pumpUntil(tester, () => started.length == 3);
    expect(started, ['compatibility', 'built-ins', 'backup']);
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.loading);
    expect(find.byKey(const Key('home-start-scoring')), findsNothing);

    backup.complete();
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('home-start-scoring')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(_entryGate(tester).startupStatus, EntryStartupStatus.ready);
    expect(started, ['compatibility', 'built-ins', 'backup']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

HoopitoEntryGate _entryGate(WidgetTester tester) =>
    tester.widget<HoopitoEntryGate>(find.byType(HoopitoEntryGate));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for startup');
}
