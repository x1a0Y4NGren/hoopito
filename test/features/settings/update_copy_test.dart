import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/update/app_update.dart';
import 'package:hoopito/features/settings/software_update_page.dart';

import '../../test_helpers/fake_update_platform.dart';
import '../../test_helpers/test_database.dart';

void main() {
  testWidgets('checking is shown once and release does not repeat page title', (
    tester,
  ) async {
    final db = createTestDatabase();
    final semantics = tester.ensureSemantics();
    final response = Completer<String>();
    final controller = UpdateController(
      service: UpdateService(sourceReader: (_) => response.future),
      platform: FakeUpdatePlatform(),
      preferences: UpdatePreferencesRepository(db),
    );
    addTearDown(() async {
      if (!response.isCompleted) response.complete(fakeUpdateJson);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await db.close();
    });
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SoftwareUpdatePage(
          controller: controller,
          canInstall: true,
          canInstallNow: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SoftwareUpdatePage)),
    )!;
    final checking = controller.checkForUpdates();
    await tester.pump();
    expect(find.text(l10n.updateChecking), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('update-check-announcement')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    response.complete(fakeUpdateJson);
    await checking;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('update-download')),
      160,
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.updateTitle), findsOneWidget);
    expect(find.textContaining('2.0.2+6'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('update-release-announcement')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
