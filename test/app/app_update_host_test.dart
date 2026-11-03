import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/app_update_host.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/update_providers.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/update/app_update.dart';

import '../test_helpers/fake_update_platform.dart';
import '../test_helpers/test_database.dart';

void main() {
  testWidgets(
    'checks only after reveal; defers popup until match query settles',
    (tester) async {
      final active = StreamController<MatchDetail?>();
      addTearDown(active.close);
      final harness = await _Harness.create(tester, active: active.stream);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(harness.requests, 0);
      harness.revealed.value = true;
      await tester.pumpAndSettle();
      expect(harness.requests, 1);
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
      active.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-update-dialog')), findsOneWidget);
      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(harness.requests, 1);
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(harness.requests, 1);
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
    },
  );

  for (final outcome in ['current', 'error', 'disabled']) {
    testWidgets('startup is silent for $outcome', (tester) async {
      final harness = await _Harness.create(tester, outcome: outcome);
      harness.revealed.value = true;
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(
        harness.requests,
        outcome == 'disabled'
            ? 0
            : outcome == 'error'
            ? 2
            : 1,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('local home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('existing popup is allowed to finish before reminder', (
    tester,
  ) async {
    final harness = await _Harness.create(tester);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final context = harness.router.routerDelegate.navigatorKey.currentContext!;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('existing confirmation'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('finish confirmation'),
            ),
          ],
        ),
      ),
    );
    harness.revealed.value = true;
    await tester.pumpAndSettle();
    expect(harness.requests, 1);
    expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
    await tester.tap(find.text('finish confirmation'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-update-dialog')), findsOneWidget);
  });

  testWidgets('nested history sheet defers delayed startup reminder', (
    tester,
  ) async {
    final response = Completer<String>();
    final harness = await _Harness.create(
      tester,
      nested: true,
      response: response,
    );
    harness.revealed.value = true;
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.requests, 1);
    await tester.tap(find.text('advanced filter'));
    await tester.pumpAndSettle();
    response.complete(fakeUpdateJson);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
    await tester.tap(find.text('close filter'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-update-dialog')), findsOneWidget);
  });
}

class _Harness {
  final FakeUpdatePlatform platform = FakeUpdatePlatform();
  final ValueNotifier<bool> revealed = ValueNotifier(false);
  int requests = 0;
  late ProviderContainer container;
  late GoRouter router;

  static Future<_Harness> create(
    WidgetTester tester, {
    Stream<MatchDetail?>? active,
    String outcome = 'new',
    bool nested = false,
    Completer<String>? response,
  }) async {
    final harness = _Harness();
    final db = createTestDatabase();
    final preferences = UpdatePreferencesRepository(db);
    if (outcome == 'disabled') await preferences.save(false);
    final controller = UpdateController(
      service: UpdateService(
        sourceReader: (_) async {
          harness.requests++;
          if (response != null) return response.future;
          if (outcome == 'error') throw StateError('offline');
          if (outcome == 'current') {
            return jsonEncode({...fakeUpdateManifest, 'versionCode': 5});
          }
          return fakeUpdateJson;
        },
      ),
      platform: harness.platform,
      preferences: preferences,
    );
    await controller.initialize();
    harness.container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        updatePlatformProvider.overrideWithValue(harness.platform),
        updateControllerProvider.overrideWith((ref) => controller),
        activeMatchProvider.overrideWith((ref) => active ?? Stream.value(null)),
      ],
    );
    harness.router = GoRouter(
      observers: [harness.container.read(updateNavigationObserverProvider)],
      routes: [
        if (nested)
          StatefulShellRoute.indexedStack(
            notifyRootObserver: true,
            builder: (_, _, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, _) => Scaffold(
                      body: TextButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (context) => TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('close filter'),
                          ),
                        ),
                        child: const Text('advanced filter'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (!nested)
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('local home')),
          ),
        GoRoute(
          path: '/settings/update',
          builder: (_, _) => const Scaffold(body: Text('update page')),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.router.dispose();
      harness.container.dispose();
      harness.revealed.dispose();
      await db.close();
    });
    return harness;
  }

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => AppUpdateHost(
        ready: true,
        entryRevealed: revealed,
        router: router,
        child: child!,
      ),
    ),
  );
}
