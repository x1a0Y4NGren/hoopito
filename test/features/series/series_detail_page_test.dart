import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/features/series/series_detail_page.dart';
import '../../support/golden_fonts.dart';
import '../../test_helpers/test_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

MatchSeries series({bool open = true}) => MatchSeries(
  id: 'pair',
  slotAName: 'Alex',
  slotBName: 'Bo',
  slotAPlayerProfileId: null,
  slotBPlayerProfileId: null,
  isOpen: open,
  revision: 1,
  nextGameNumber: 1,
  createdAt: DateTime.utc(2026),
  closedAt: open ? null : DateTime.utc(2026),
  defaultSetup: const {},
  games: const [],
);
Widget app(
  Widget page, {
  String language = 'en',
  bool dark = false,
  double scale = 1,
}) => MaterialApp(
  theme: buildHoopitoTheme(),
  darkTheme: buildHoopitoTheme(brightness: Brightness.dark),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);
void main() {
  setUpAll(loadHoopitoGoldenFonts);
  testWidgets('reopened empty series is in progress without a winner or draw', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(Scaffold(body: SeriesOverview(series: series()))),
    );
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.textContaining('Winner'), findsNothing);
    expect(find.text('No completed games yet'), findsOneWidget);
    expect(find.text('Draw'), findsNothing);
    await tester.pumpWidget(
      app(Scaffold(body: SeriesOverview(series: series(open: false)))),
    );
    expect(find.textContaining('No completed games yet'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
  });
  testWidgets('closed winning series keeps lifecycle status beside outcome', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final service = MatchCommandService(database);
    final repository = MatchSeriesRepository(database);
    final command = StartMatchCommand(
      redName: 'Alex',
      blueName: 'Bo',
      recordingMode: RecordingMode.simple,
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      seriesContext: const SeriesStartContext(
        seriesId: 'pair',
        expectedRevision: 0,
        gameNumber: 1,
        create: true,
      ),
    );
    await service.start(command);
    await service.record(
      RecordMatchEventCommand(
        matchId: command.matchId,
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await service.finish(
      FinishMatchCommand(
        matchId: command.matchId,
        endedAt: DateTime.now(),
        confirmFinalScore: true,
      ),
    );
    final open = (await repository.getSeries('pair'))!;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        app(Scaffold(body: SeriesOverview(series: open))),
      );
      expect(
        RegExp('In progress').allMatches(
          tester.getSemantics(find.byType(SeriesOverview)).toStringDeep(),
        ),
        hasLength(1),
      );
    } finally {
      semantics.dispose();
    }
    await repository.close(
      seriesId: 'pair',
      expectedRevision: open.revision,
      intentId: 'close',
    );
    final closed = (await repository.getSeries('pair'))!;
    await tester.pumpWidget(
      app(Scaffold(body: SeriesOverview(series: closed))),
    );
    expect(find.text('Closed'), findsOneWidget);
    expect(find.textContaining('Alex'), findsNWidgets(2));
    expect(find.text('Draw'), findsNothing);
    expect(find.byKey(const Key('series-outcome')), findsOneWidget);
  });
  testWidgets('active game blocks close and next but allows resume', (
    tester,
  ) async {
    String? resumed;
    await tester.pumpWidget(
      app(
        SeriesDetailPage(
          series: series(),
          activeMatchId: 'game',
          onBack: () {},
          onMatch: (id) => resumed = id,
          onClose: () {},
        ),
      ),
    );
    expect(find.byKey(const Key('series-next')), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('series-close')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('series-resume')));
    expect(resumed, 'game');
  });
  for (final language in ['en', 'zh']) {
    for (final dark in [false, true]) {
      testWidgets(
        'series detail $language dark=$dark supports 200 percent text',
        (tester) async {
          tester.view.physicalSize = const Size(420, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            app(
              SeriesDetailPage(
                series: series(),
                onBack: () {},
                onMatch: (_) {},
                onNext: () {},
                onSettings: () {},
                onClose: () {},
              ),
              language: language,
              dark: dark,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(SeriesDetailPage),
            matchesGoldenFile(
              hoopitoGoldenFile(
                'series_${language}_${dark ? 'dark' : 'light'}_200',
              ),
            ),
          );
        },
      );
    }
  }
}
