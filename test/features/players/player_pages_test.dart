import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/players/player_editor_page.dart';
import 'package:hoopito/features/players/player_list_page.dart';

import '../../test_helpers/test_database.dart';

void main() {
  testWidgets('players list and editor stay usable across visual matrix', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
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
          final mediaQuery = MediaQuery(
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
              home: PlayerListPage(
                repository: repository,
                onCreate: () {},
                onEdit: (_) {},
              ),
            ),
          );
          await tester.pumpWidget(mediaQuery);
          expect(tester.takeException(), isNull);
          await _pumpDatabase(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(EditorialScaffold), findsOneWidget);
          expect(find.byType(EditorialMasthead), findsOneWidget);
          expect(find.byType(EditorialTapTarget), findsOneWidget);
          expect(
            tester.getSize(find.byType(EditorialTapTarget)).height,
            greaterThanOrEqualTo(48),
          );

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
                home: PlayerEditorPage(repository: repository, onSaved: () {}),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const Key('player-nickname'))).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('player row has one semantic action owner', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'semantic-player',
        nickname: '小北',
        createdAt: DateTime.utc(2026, 7, 10),
      ),
    );
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: PlayerListPage(
          repository: repository,
          onCreate: () {},
          onEdit: (_) => edits++,
        ),
      ),
    );
    await _pumpDatabase(tester);

    final row = find.byKey(const ValueKey('player-row-semantic-player'));
    expect(row, findsOneWidget);
    _expectSingleTapOwner(tester, row);
    await tester.tap(row);
    expect(edits, 1);
    semanticsHandle.dispose();
  });

  testWidgets('player editor save has one semantic action owner', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final database = createTestDatabase();
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: PlayerEditorPage(
          repository: PlayerRepository(database),
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('player-save'));
    expect(save, findsOneWidget);
    _expectSingleTapOwner(tester, save);
    await tester.enterText(find.byKey(const Key('player-nickname')), '小北');
    await tester.tap(save);
    await _pumpDatabase(tester);
    expect(saved, isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('player profiles no longer expose or persist a preferred side', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'legacy-sided-player',
        nickname: '自由球员',
        createdAt: DateTime.utc(2026, 7, 10),
        preferredSide: TeamSide.blue,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerEditorPage(
          repository: repository,
          playerId: 'legacy-sided-player',
          onSaved: () {},
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('自由球员'));

    expect(find.text('偏好方'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '红方'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '蓝方'), findsNothing);

    await tester.tap(find.byKey(const Key('player-save')));
    await _pumpDatabase(tester);
    expect(
      (await repository.getById('legacy-sided-player'))?.preferredSide,
      isNull,
    );
  });

  testWidgets('legacy preferred side is inert in the player list', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'legacy-list-player',
        nickname: '不分边球员',
        createdAt: DateTime.utc(2026, 7, 10),
        preferredSide: TeamSide.red,
        note: '旧数据备注',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: PlayerListPage(
          repository: repository,
          onCreate: () {},
          onEdit: (_) {},
        ),
      ),
    );
    await _pumpDatabase(tester);

    expect(find.text('偏好红方'), findsNothing);
    expect(find.text('旧数据备注'), findsOneWidget);
    final avatarFinder = find.byKey(
      const ValueKey('player-avatar-legacy-list-player'),
    );
    final avatar = tester.widget<CircleAvatar>(avatarFinder);
    expect(
      avatar.backgroundColor,
      editorialThemeOf(tester.element(avatarFinder)).ink,
    );
  });

  testWidgets('player avatar foreground meets normal-text contrast', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    final variants = <String, TeamSide?>{
      'red': TeamSide.red,
      'blue': TeamSide.blue,
      'neutral': null,
    };
    for (final entry in variants.entries) {
      await repository.save(
        Player(
          id: 'contrast-${entry.key}',
          nickname: entry.key,
          createdAt: DateTime.utc(2026, 7, 10),
          preferredSide: entry.value,
        ),
      );
    }
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(brightness: brightness),
          home: PlayerListPage(
            repository: repository,
            onCreate: () {},
            onEdit: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await _pumpDatabase(tester);
      expect(tester.takeException(), isNull);
      for (final id in variants.keys) {
        final avatar = tester.widget<CircleAvatar>(
          find.byKey(ValueKey('player-avatar-contrast-$id')),
        );
        expect(
          _contrastRatio(avatar.foregroundColor!, avatar.backgroundColor!),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness $id avatar contrast',
        );
      }
    }
  });

  testWidgets('player list exposes empty, create and edit flows', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    var created = false;
    Player? edited;

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerListPage(
          repository: repository,
          onCreate: () => created = true,
          onEdit: (player) => edited = player,
        ),
      ),
    );
    await _pumpDatabase(tester);
    expect(find.text('还没有保存的球员'), findsOneWidget);
    expect(find.byType(EditorialMasthead), findsOneWidget);
    expect(find.byType(EditorialEmptyState), findsOneWidget);

    await tester.tap(find.byTooltip('新建球员'));
    expect(created, isTrue);

    await repository.save(
      Player(
        id: 'player-1',
        nickname: '小北',
        createdAt: DateTime.utc(2026, 7, 10),
        note: '外线投篮',
      ),
    );
    await _pumpDatabase(tester);
    await tester.tap(find.text('小北'));
    expect(edited?.id, 'player-1');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('player list exposes error and retries into populated content', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = _SequencedPlayerRepository(
      database,
      streams: [
        Stream<List<Player>>.error(StateError('offline')),
        Stream.value([
          Player(
            id: 'retry-player',
            nickname: '重试成功',
            createdAt: DateTime.utc(2026, 7, 10),
          ),
        ]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerListPage(
          repository: repository,
          onCreate: () {},
          onEdit: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorialErrorState), findsOneWidget);
    expect(find.text('无法读取球员'), findsOneWidget);
    expect(repository.watchCalls, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(repository.watchCalls, 2);
    expect(find.byType(EditorialErrorState), findsNothing);
    expect(find.text('重试成功'), findsOneWidget);
  });

  testWidgets('player editor exposes open error and retries the load', (
    tester,
  ) async {
    final database = createTestDatabase();
    var loadCalls = 0;
    final repository = _SequencedPlayerRepository(
      database,
      streams: const [],
      load: (id) async {
        loadCalls++;
        if (loadCalls == 1) throw StateError('offline');
        return Player(
          id: id,
          nickname: '恢复档案',
          createdAt: DateTime.utc(2026, 7, 10),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerEditorPage(
          repository: repository,
          playerId: 'open-error-player',
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorialErrorState), findsOneWidget);
    expect(find.text('无法打开球员档案'), findsOneWidget);
    expect(find.text('无法打开该球员档案，请检查本地数据后重试。'), findsOneWidget);
    expect(loadCalls, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.byType(EditorialErrorState), findsNothing);
    expect(find.text('恢复档案'), findsOneWidget);
  });

  testWidgets('populated player list remains usable at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    var editCalls = 0;
    var analyticsCalls = 0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await repository.save(
      Player(
        id: 'large-text-player',
        nickname: '很长的球员昵称用于大字号列表',
        createdAt: DateTime.utc(2026, 7, 10),
        preferredSide: TeamSide.blue,
        note: '外线投篮与快速防守',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PlayerListPage(
          repository: repository,
          onCreate: () {},
          onEdit: (_) => editCalls++,
          onViewAnalytics: (_) => analyticsCalls++,
        ),
      ),
    );
    await _pumpDatabase(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('player-row-large-text-player')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-avatar-large-text-player')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('player-analytics-large-text-player')),
    );
    expect(editCalls, 1);
    expect(analyticsCalls, 0);
    await tester.tap(find.text('很长的球员昵称用于大字号列表'));
    expect(analyticsCalls, 1);
    expect(editCalls, 1);
  });

  testWidgets('player editor creates and updates persisted fields', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerEditorPage(
          repository: repository,
          idFactory: () => 'new-player',
          now: () => DateTime.utc(2026, 7, 10),
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('player-nickname')), '飞鱼');
    await tester.enterText(find.byKey(const Key('player-note')), '惯用左手');
    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(find.byType(EditorialSectionRule), findsAtLeastNWidgets(2));
    expect(find.byType(EditorialTapTarget), findsWidgets);
    await tester.tap(find.byTooltip('保存球员'));
    await _pumpDatabase(tester);

    final player = await repository.getById('new-player');
    expect(player?.nickname, '飞鱼');
    expect(player?.preferredSide, isNull);
    expect(player?.note, '惯用左手');
    expect(saved, isTrue);

    final updated = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerEditorPage(
          repository: repository,
          playerId: 'new-player',
          onSaved: updated.complete,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('飞鱼'));
    await tester.enterText(find.byKey(const Key('player-nickname')), '飞鱼 2');
    await tester.tap(find.byTooltip('保存球员'));
    await tester.runAsync(
      () => updated.future.timeout(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect((await repository.getById('new-player'))?.nickname, '飞鱼 2');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('player editor validates, confirms deletion, and calls back', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'delete-player',
        nickname: '小北',
        createdAt: DateTime.utc(2026, 7, 10),
      ),
    );
    var saved = false;
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerEditorPage(
          repository: repository,
          playerId: 'delete-player',
          onSaved: () => saved = true,
          onDeleted: () => deleted = true,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('小北'));

    final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    final editorial = editorialThemeOf(
      tester.element(find.byIcon(Icons.delete_outline)),
    );
    expect(deleteIcon.color, editorial.ink);

    await tester.enterText(find.byKey(const Key('player-nickname')), '');
    await tester.tap(find.byKey(const Key('player-save')));
    await tester.pump();
    expect(find.text('请输入球员昵称'), findsOneWidget);
    expect(saved, isFalse);

    await tester.tap(find.byTooltip('删除球员'));
    await tester.pumpAndSettle();
    expect(find.text('删除球员？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await repository.getById('delete-player'), isNotNull);
    expect(deleted, isFalse);

    await tester.tap(find.byTooltip('删除球员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await _pumpDatabase(tester);
    expect(await repository.getById('delete-player'), isNull);
    expect(deleted, isTrue);
  });
}

Future<void> _pumpDatabase(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the expected widget.');
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
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

class _SequencedPlayerRepository extends PlayerRepository {
  _SequencedPlayerRepository(
    super.database, {
    required this.streams,
    this.load,
  });

  final List<Stream<List<Player>>> streams;
  final Future<Player?> Function(String id)? load;
  var watchCalls = 0;

  @override
  Stream<List<Player>> watchAll() {
    final index = watchCalls++;
    return streams[index < streams.length ? index : streams.length - 1];
  }

  @override
  Future<Player?> getById(String id) {
    final loader = load;
    return loader == null ? super.getById(id) : loader(id);
  }
}
