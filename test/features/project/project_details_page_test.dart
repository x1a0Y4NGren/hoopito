import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/project/external_link_launcher.dart';
import 'package:hoopito/features/project/project_details_page.dart';

class RecordingLauncher extends ExternalLinkLauncher {
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

class FailingLauncher extends ExternalLinkLauncher {
  @override
  Future<bool> open(String url) async => false;
}

void main() {
  testWidgets('about uses editorial composition and localized title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(ProjectDetailsPage(launcher: RecordingLauncher())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(find.byType(EditorialMasthead), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Hoopito · 球豆'), findsOneWidget);
  });

  testWidgets('project details stays usable across visual matrix', (
    tester,
  ) async {
    const locales = [Locale('zh'), Locale('en')];
    const sizes = [
      Size(390, 844),
      Size(731, 411),
      Size(1095, 616),
      Size(1920, 1080),
    ];
    for (final brightness in Brightness.values) {
      for (final locale in locales) {
        for (final size in sizes) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: MaterialApp(
                theme: buildHoopitoTheme(brightness: brightness),
                locale: locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: ProjectDetailsPage(
                  key: ValueKey('$brightness-$locale-$size'),
                  launcher: RecordingLauncher(),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(EditorialScaffold), findsOneWidget);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ProjectDetailsPage)),
          )!;
          await tester.scrollUntilVisible(
            find.text(l10n.projectGitHub),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .getSize(
                  find.byKey(ValueKey('project-link-${l10n.projectGitHub}')),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('project links have one semantic action owner', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final launcher = RecordingLauncher();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProjectDetailsPage(launcher: launcher),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('GitHub'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final link = find.byKey(const ValueKey('project-link-GitHub'));
    expect(link, findsOneWidget);
    _expectSingleTapOwner(tester, link);
    semanticsHandle.dispose();
  });

  testWidgets('failed external launch keeps the localized snackbar contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(ProjectDetailsPage(launcher: FailingLauncher())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('GitHub'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectDetailsPage)),
    )!;
    expect(find.text(l10n.routeProjectLinkError), findsOneWidget);
  });

  testWidgets('project details state open-source and local data principles', (
    tester,
  ) async {
    final launcher = RecordingLauncher();
    await tester.pumpWidget(
      _localizedApp(ProjectDetailsPage(launcher: launcher)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditorialScaffold), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectDetailsPage)),
    )!;

    for (final text in [
      l10n.projectFreeForever,
      l10n.projectOpenSource,
      l10n.projectOffline,
      l10n.projectPrivacy,
    ]) {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(text), findsOneWidget);
    }
    for (final link in [
      l10n.projectGitHub,
      l10n.projectLicense,
      l10n.projectContribute,
      l10n.projectIssue,
    ]) {
      await tester.scrollUntilVisible(
        find.text(link),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(link), findsOneWidget);
    }

    await tester.tap(find.text(l10n.projectGitHub));
    await tester.pump();
    expect(launcher.opened, [hoopitoRepositoryUrl]);
  });
}

Widget _localizedApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void _expectSingleTapOwner(WidgetTester tester, Finder target) {
  final targetNode = tester.getSemantics(target);
  final tapNodes = <SemanticsNode>[];

  void visit(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(ui.SemanticsAction.tap)) {
      tapNodes.add(node);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(targetNode);
  expect(tapNodes, hasLength(1));
  expect(tapNodes.single, same(targetNode));
}
