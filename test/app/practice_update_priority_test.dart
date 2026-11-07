import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/app_update_host.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/practice_host.dart';
import 'package:hoopito/app/practice_providers.dart';
import 'package:hoopito/app/update_providers.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';
import 'package:hoopito/core/update/app_update.dart';

import '../test_helpers/fake_update_platform.dart';
import '../test_helpers/test_database.dart';

void main() {
  testWidgets(
    'invitation takes popup priority; check runs and reminder survives entire practice',
    (tester) async {
      final h = await _Harness.create(tester);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(h.requests, 1);
      expect(
        find.byKey(const Key('practice-invitation-dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
      await tester.tap(find.byKey(const Key('practice-invite-start')));
      await tester.pumpAndSettle();
      expect(find.text('practice page'), findsOneWidget);
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
      // Keep flow ownership through the exit confirmation, even after route pop.
      h.container.read(practiceFlowVisibleProvider.notifier).state = true;
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-update-dialog')), findsNothing);
      h.container.read(practiceFlowVisibleProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-update-dialog')), findsOneWidget);
      expect(h.requests, 1);
    },
  );

  testWidgets('bounded preference read releases pending reminder on timeout', (
    tester,
  ) async {
    final h = await _Harness.create(tester, stallRead: true);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(h.requests, 1);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-update-dialog')), findsOneWidget);
    expect(h.container.read(practiceInvitationBlockingProvider), isFalse);
    h.pendingRead.complete(const PracticeProgress());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
  });
}

class _Harness {
  late ProviderContainer container;
  late GoRouter router;
  final revealed = ValueNotifier(true);
  final pendingRead = Completer<PracticeProgress>();
  int requests = 0;

  static Future<_Harness> create(
    WidgetTester tester, {
    bool stallRead = false,
  }) async {
    final h = _Harness();
    final db = createTestDatabase();
    final platform = FakeUpdatePlatform();
    final controller = UpdateController(
      service: UpdateService(
        sourceReader: (_) async {
          h.requests++;
          return fakeUpdateJson;
        },
      ),
      platform: platform,
      preferences: UpdatePreferencesRepository(db),
    );
    await controller.initialize();
    h.container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        updatePlatformProvider.overrideWithValue(platform),
        updateControllerProvider.overrideWith((ref) => controller),
        activeMatchProvider.overrideWith((ref) => Stream.value(null)),
        if (stallRead)
          practicePreferencesProvider.overrideWithValue(
            _PendingPreferences(db, h.pendingRead.future),
          ),
      ],
    );
    h.router = GoRouter(
      observers: [h.container.read(updateNavigationObserverProvider)],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home page')),
        ),
        GoRoute(
          path: '/practice',
          builder: (_, _) => const Scaffold(body: Text('practice page')),
        ),
        GoRoute(
          path: '/settings/update',
          builder: (_, _) => const Scaffold(body: Text('update page')),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      h.router.dispose();
      h.container.dispose();
      h.revealed.dispose();
    });
    return h;
  }

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (_, child) => PracticeHost(
        ready: true,
        entryRevealed: revealed,
        router: router,
        child: AppUpdateHost(
          ready: true,
          entryRevealed: revealed,
          router: router,
          child: child!,
        ),
      ),
    ),
  );
}

class _PendingPreferences extends PracticePreferences {
  _PendingPreferences(super.database, this.pending);
  final Future<PracticeProgress> pending;
  @override
  Future<PracticeProgress> load() => pending;
}
