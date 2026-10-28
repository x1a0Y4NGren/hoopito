import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

class RuleTemplateRepository {
  RuleTemplateRepository(this._database);

  final AppDatabase _database;

  static const builtIns = [
    RuleTemplate(id: 'free', name: '自由计分', scoreButtons: [1, 2, 3]),
    RuleTemplate(
      id: 'eleven_win_by_two',
      name: '11 分制（领先 2 分）',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      winByTwo: false,
    ),
    RuleTemplate(
      id: 'twenty_one',
      name: '21 分制',
      scoreButtons: [1, 2, 3],
      targetScore: 21,
    ),
    RuleTemplate(
      id: 'timed_ten',
      name: '10 分钟计时',
      scoreButtons: [1, 2, 3],
      timeLimitSeconds: 600,
    ),
  ];

  Future<void> ensureBuiltIns() async {
    await _database.transaction(() async {
      for (final template in builtIns) {
        await save(template, isBuiltIn: true);
      }
    });
  }

  Future<void> save(RuleTemplate template, {bool isBuiltIn = false}) {
    return _database
        .into(_database.ruleTemplates)
        .insertOnConflictUpdate(
          RuleTemplatesCompanion.insert(
            id: template.id,
            name: template.name,
            scoreButtonsJson: jsonEncode(template.scoreButtons),
            targetScore: Value(template.targetScore),
            timeLimitSeconds: Value(template.timeLimitSeconds),
            winByTwo: Value(template.winByTwo),
            foulLimit: Value(template.foulLimit),
            customEventTypesJson: Value(
              jsonEncode({
                'eventTypes': template.customEventTypes,
                'possessionHintEnabled': template.possessionHintEnabled,
                'possessionPolicy': template.possessionPolicy.name,
              }),
            ),
            isBuiltIn: Value(isBuiltIn),
          ),
        );
  }

  Stream<List<RuleTemplate>> watchAll() {
    final query = _database.select(_database.ruleTemplates)
      ..orderBy([(template) => OrderingTerm.desc(template.isBuiltIn)]);

    return query.watch().map((rows) {
      return rows.map(_mapRow).toList();
    });
  }

  Future<List<RuleTemplate>> listAll() async {
    final query = _database.select(_database.ruleTemplates)
      ..orderBy([
        (template) => OrderingTerm.desc(template.isBuiltIn),
        (template) => OrderingTerm.asc(template.name),
      ]);
    return (await query.get()).map(_mapRow).toList(growable: false);
  }

  Future<RuleTemplate?> getById(String id) async {
    final query = _database.select(_database.ruleTemplates)
      ..where((template) => template.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<void> deleteCustom(String id) {
    return (_database.delete(_database.ruleTemplates)..where(
          (template) => template.id.equals(id) & template.isBuiltIn.not(),
        ))
        .go();
  }

  static RuleTemplate _mapRow(RuleTemplateRow row) {
    final metadata = jsonDecode(row.customEventTypesJson);
    final customEventTypes = metadata is List
        ? metadata.cast<String>()
        : ((metadata as Map)['eventTypes'] as List<Object?>? ?? const [])
              .cast<String>();
    final possessionHintEnabled = metadata is Map
        ? metadata['possessionHintEnabled'] as bool? ?? false
        : false;
    final possessionPolicy =
        metadata is Map && metadata['possessionPolicy'] is String
        ? PossessionPolicy.values.byName(metadata['possessionPolicy'] as String)
        : PossessionPolicy.manual;
    return RuleTemplate(
      id: row.id,
      name: row.name,
      scoreButtons: (jsonDecode(row.scoreButtonsJson) as List<Object?>)
          .cast<num>()
          .map((value) => value.toInt())
          .toList(),
      targetScore: row.targetScore,
      timeLimitSeconds: row.timeLimitSeconds,
      winByTwo: row.winByTwo,
      foulLimit: row.foulLimit,
      possessionHintEnabled: possessionHintEnabled,
      possessionPolicy: possessionPolicy,
      customEventTypes: customEventTypes,
    );
  }
}
