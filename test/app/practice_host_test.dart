import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/practice_host.dart';
import 'package:hoopito/app/practice_providers.dart';
import 'package:hoopito/app/update_providers.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';
import 'package:hoopito/core/settings/scoring_guide_preferences.dart';

import '../test_helpers/test_database.dart';

void main() {
  for (final action in [
    'practice-invite-start',
    'practice-invite-later',
    'back',
    'barrier',
  ]) {
    testWidgets('$action handles invitation once; only start opens practice', (
      tester,
    ) async {
      final h = await _Harness.create(tester);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
      h.revealed.value = true;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('practice-invitation-dialog')),
        findsOneWidget,
      );
      if (action == 'back') {
        await tester.binding.handlePopRoute();
      } else if (action == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.byKey(Key(action)));
      }
      await tester.pumpAndSettle();
      expect((await h.preferences.load()).invitationHandled, isTrue);
      expect((await h.preferences.load()).practiceCompleted, isFalse);
      expect(
        find.text('practice page'),
        action.endsWith('start') ? findsOneWidget : findsNothing,
      );
      h.router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
      expect(h.container.read(practiceInvitationBlockingProvider), isFalse);
    });
  }

  testWidgets(
    'legacy seen users are invited; pushed page defers until popped',
    (tester) async {
      final h = await _Harness.create(tester, legacySeen: true);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      unawaited(h.router.push('/other'));
      await tester.pumpAndSettle();
      h.revealed.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('practice-invitation-dialog')),
        findsOneWidget,
      );
    },
  );

  testWidgets('active query and existing popup defer invitation', (
    tester,
  ) async {
    final active = StreamController<MatchDetail?>();
    addTearDown(active.close);
    final h = await _Harness.create(tester, active: active.stream);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.revealed.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
    unawaited(
      showDialog<void>(
        context: h.router.routerDelegate.navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('close popup'),
            ),
          ],
        ),
      ),
    );
    active.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-invitation-dialog')), findsNothing);
    await tester.tap(find.text('close popup'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-invitation-dialog')), findsOneWidget);
  });

  for (final failWrite in [false, true]) {
    testWidgets(
      '${failWrite ? 'write' : 'read'} failure releases arbitration without loops',
      (tester) async {
        final h = await _Harness.create(
          tester,
          failRead: !failWrite,
          failWrite: failWrite,
        );
        h.revealed.value = true;
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();
        if (failWrite) {
          await tester.tap(find.byKey(const Key('practice-invite-later')));
          await tester.pumpAndSettle();
        }
        expect(h.container.read(practiceInvitationBlockingProvider), isFalse);
        h.router.go('/other');
        await tester.pumpAndSettle();
        h.router.go('/');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('practice-invitation-dialog')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Harness {
  late ProviderContainer container;
  late GoRouter router;
  late PracticePreferences preferences;
  final revealed = ValueNotifier(false);

  static Future<_Harness> create(
    WidgetTester tester, {
    bool legacySeen = false,
    bool failRead = false,
    bool failWrite = false,
    Stream<MatchDetail?>? active,
  }) async {
    final h = _Harness();
    final db = createTestDatabase();
    if (legacySeen) await ScoringGuidePreferences(db).markSeen();
    h.preferences = _FailingPreferences(
      db,
      failRead: failRead,
      failWrite: failWrite,
    );
    h.container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        practicePreferencesProvider.overrideWithValue(h.preferences),
        activeMatchProvider.overrideWith((ref) => active ?? Stream.value(null)),
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
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('other page')),
        ),
        GoRoute(
          path: '/practice',
          builder: (_, _) => const Scaffold(body: Text('practice page')),
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
        child: child!,
      ),
    ),
  );
}

class _FailingPreferences extends PracticePreferences {
  _FailingPreferences(
    super.database, {
    this.failRead = false,
    this.failWrite = false,
  });
  final bool failRead;
  final bool failWrite;
  @override
  Future<PracticeProgress> load() =>
      failRead ? Future.error(StateError('read unavailable')) : super.load();
  @override
  Future<void> markInvitationHandled() => failWrite
      ? Future.error(StateError('write unavailable'))
      : super.markInvitationHandled();
}
