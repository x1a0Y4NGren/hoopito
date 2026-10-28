import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/core/update/app_update.dart';
import 'package:hoopito/features/settings/software_update_page.dart';

import '../../test_helpers/test_database.dart';
import '../../test_helpers/fake_update_platform.dart';
import '../../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  testWidgets('permission return checks the current match before installing', (
    tester,
  ) async {
    final db = createTestDatabase();
    final platform = FakeUpdatePlatform()
      ..installResult = UpdateInstallResult.permissionRequired;
    final controller = UpdateController(
      service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
      platform: platform,
      preferences: UpdatePreferencesRepository(db),
    );
    var allowed = true;
    await controller.initialize();
    await controller.checkForUpdates();
    await controller.startDownload();
    await tester.pumpWidget(
      _app(controller: controller, canInstallNow: () => allowed),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('update-install')),
      160,
    );
    await tester.tap(find.byKey(const Key('update-install')));
    await tester.pumpAndSettle();
    expect(platform.prepareRequests, 1);
    expect(platform.installRequests, 0);
    await tester.tap(find.text('打开系统设置'));
    await tester.pumpAndSettle();
    expect(platform.settingsOpened, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    allowed = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.prepareRequests, 1);
    expect(platform.installRequests, 0);
    expect(find.textContaining('请先完成或结束当前比赛'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await db.close();
  });

  for (final interruption in ['match', 'disposed', 'covered', 'background']) {
    testWidgets('delayed preparation refuses install after $interruption', (
      tester,
    ) async {
      final db = createTestDatabase();
      final ready = Completer<void>();
      final platform = FakeUpdatePlatform()..preparing = ready;
      final controller = UpdateController(
        service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      var allowed = true;
      await controller.initialize();
      await controller.checkForUpdates();
      await controller.startDownload();
      await tester.pumpWidget(
        _app(controller: controller, canInstallNow: () => allowed),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('update-install')),
        160,
      );
      final pageContext = tester.element(find.byType(SoftwareUpdatePage));
      await tester.tap(find.byKey(const Key('update-install')));
      await tester.pump();
      expect(platform.prepareRequests, 1);
      if (interruption == 'match') allowed = false;
      if (interruption == 'disposed') {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      if (interruption == 'covered') {
        unawaited(
          Navigator.of(pageContext).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('other route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      if (interruption == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      ready.complete();
      await tester.pumpAndSettle();
      expect(platform.installRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      controller.dispose();
      await db.close();
    });
  }

  testWidgets(
    'failed settings launch reports failure and clears return retry',
    (tester) async {
      final db = createTestDatabase();
      final platform = FakeUpdatePlatform()
        ..installResult = UpdateInstallResult.permissionRequired
        ..failSettings = true;
      final controller = UpdateController(
        service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      await controller.initialize();
      await controller.checkForUpdates();
      await controller.startDownload();
      await tester.pumpWidget(_app(controller: controller));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('update-install')),
        160,
      );
      await tester.tap(find.byKey(const Key('update-install')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开系统设置'));
      await tester.pumpAndSettle();
      expect(find.textContaining('无法打开安装界面'), findsOneWidget);
      expect(controller.error, 'unavailable');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(platform.prepareRequests, 1);
      expect(platform.installRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await db.close();
    },
  );

  for (final locale in ['zh', 'en']) {
    for (final dark in [false, true]) {
      for (final landscape in [false, true]) {
        testWidgets('update layout $locale dark=$dark landscape=$landscape', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(
            landscape ? const Size(900, 440) : const Size(360, 800),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final db = createTestDatabase();
          final controller = UpdateController(
            service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
            platform: FakeUpdatePlatform(),
            preferences: UpdatePreferencesRepository(db),
          );
          await controller.initialize();
          await controller.checkForUpdates();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: _app(
                controller: controller,
                locale: locale,
                dark: dark,
                scale: 2,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const Key('update-download')),
            180,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('update-download')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_UPDATE_UI')) {
            final path =
                '.superpowers/copy-polish/previews/update-$locale-$dark-$landscape.png';
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(path).parent.create(recursive: true);
              await File(path).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await db.close();
        });
      }
    }
  }

  for (final locale in ['zh', 'en']) {
    testWidgets('manual check and active-match install gate $locale', (
      tester,
    ) async {
      final db = createTestDatabase();
      final platform = FakeUpdatePlatform();
      final controller = UpdateController(
        service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await db.close();
      });
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SoftwareUpdatePage(
            controller: controller,
            canInstall: false,
            canInstallNow: () => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update-check')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.0.2'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('update-download')));
      await tester.tap(find.byKey(const Key('update-download')));
      await tester.pumpAndSettle();
      expect(platform.downloadStarts, 1);
      await tester.scrollUntilVisible(
        find.byKey(const Key('update-install')),
        160,
      );
      final install = tester.widget<FilledButton>(
        find.byKey(const Key('update-install')),
      );
      expect(install.onPressed, isNull);
      expect(platform.installRequests, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app({
  required UpdateController controller,
  bool Function()? canInstallNow,
  String locale = 'zh',
  bool dark = false,
  double scale = 1,
}) => MaterialApp(
  locale: Locale(locale),
  theme: buildHoopitoTheme(
    brightness: dark ? Brightness.dark : Brightness.light,
  ),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: SoftwareUpdatePage(
    controller: controller,
    canInstall: true,
    canInstallNow: canInstallNow ?? () => true,
  ),
);
