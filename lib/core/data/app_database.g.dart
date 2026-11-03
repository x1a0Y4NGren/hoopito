// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MatchesTable extends Matches with TableInfo<$MatchesTable, Matche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _recordingModeMeta = const VerificationMeta(
    'recordingMode',
  );
  @override
  late final GeneratedColumn<String> recordingMode = GeneratedColumn<String>(
    'recording_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('simple'),
  );
  static const VerificationMeta _trackingCoverageMeta = const VerificationMeta(
    'trackingCoverage',
  );
  @override
  late final GeneratedColumn<String> trackingCoverage = GeneratedColumn<String>(
    'tracking_coverage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scoresOnly'),
  );
  static const VerificationMeta _ruleTemplateJsonMeta = const VerificationMeta(
    'ruleTemplateJson',
  );
  @override
  late final GeneratedColumn<String> ruleTemplateJson = GeneratedColumn<String>(
    'rule_template_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timerEnabledMeta = const VerificationMeta(
    'timerEnabled',
  );
  @override
  late final GeneratedColumn<bool> timerEnabled = GeneratedColumn<bool>(
    'timer_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("timer_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lifecycle,
    recordingMode,
    trackingCoverage,
    ruleTemplateJson,
    createdAt,
    startedAt,
    endedAt,
    timerEnabled,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<Matche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    }
    if (data.containsKey('recording_mode')) {
      context.handle(
        _recordingModeMeta,
        recordingMode.isAcceptableOrUnknown(
          data['recording_mode']!,
          _recordingModeMeta,
        ),
      );
    }
    if (data.containsKey('tracking_coverage')) {
      context.handle(
        _trackingCoverageMeta,
        trackingCoverage.isAcceptableOrUnknown(
          data['tracking_coverage']!,
          _trackingCoverageMeta,
        ),
      );
    }
    if (data.containsKey('rule_template_json')) {
      context.handle(
        _ruleTemplateJsonMeta,
        ruleTemplateJson.isAcceptableOrUnknown(
          data['rule_template_json']!,
          _ruleTemplateJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ruleTemplateJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('timer_enabled')) {
      context.handle(
        _timerEnabledMeta,
        timerEnabled.isAcceptableOrUnknown(
          data['timer_enabled']!,
          _timerEnabledMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Matche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Matche(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      recordingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_mode'],
      )!,
      trackingCoverage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tracking_coverage'],
      )!,
      ruleTemplateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_template_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      timerEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}timer_enabled'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class Matche extends DataClass implements Insertable<Matche> {
  final String id;
  final String lifecycle;
  final String recordingMode;
  final String trackingCoverage;
  final String ruleTemplateJson;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool timerEnabled;
  final String? note;
  const Matche({
    required this.id,
    required this.lifecycle,
    required this.recordingMode,
    required this.trackingCoverage,
    required this.ruleTemplateJson,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.timerEnabled,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lifecycle'] = Variable<String>(lifecycle);
    map['recording_mode'] = Variable<String>(recordingMode);
    map['tracking_coverage'] = Variable<String>(trackingCoverage);
    map['rule_template_json'] = Variable<String>(ruleTemplateJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['timer_enabled'] = Variable<bool>(timerEnabled);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      id: Value(id),
      lifecycle: Value(lifecycle),
      recordingMode: Value(recordingMode),
      trackingCoverage: Value(trackingCoverage),
      ruleTemplateJson: Value(ruleTemplateJson),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      timerEnabled: Value(timerEnabled),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Matche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Matche(
      id: serializer.fromJson<String>(json['id']),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      recordingMode: serializer.fromJson<String>(json['recordingMode']),
      trackingCoverage: serializer.fromJson<String>(json['trackingCoverage']),
      ruleTemplateJson: serializer.fromJson<String>(json['ruleTemplateJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      timerEnabled: serializer.fromJson<bool>(json['timerEnabled']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'recordingMode': serializer.toJson<String>(recordingMode),
      'trackingCoverage': serializer.toJson<String>(trackingCoverage),
      'ruleTemplateJson': serializer.toJson<String>(ruleTemplateJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'timerEnabled': serializer.toJson<bool>(timerEnabled),
      'note': serializer.toJson<String?>(note),
    };
  }

  Matche copyWith({
    String? id,
    String? lifecycle,
    String? recordingMode,
    String? trackingCoverage,
    String? ruleTemplateJson,
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
    bool? timerEnabled,
    Value<String?> note = const Value.absent(),
  }) => Matche(
    id: id ?? this.id,
    lifecycle: lifecycle ?? this.lifecycle,
    recordingMode: recordingMode ?? this.recordingMode,
    trackingCoverage: trackingCoverage ?? this.trackingCoverage,
    ruleTemplateJson: ruleTemplateJson ?? this.ruleTemplateJson,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    timerEnabled: timerEnabled ?? this.timerEnabled,
    note: note.present ? note.value : this.note,
  );
  Matche copyWithCompanion(MatchesCompanion data) {
    return Matche(
      id: data.id.present ? data.id.value : this.id,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      recordingMode: data.recordingMode.present
          ? data.recordingMode.value
          : this.recordingMode,
      trackingCoverage: data.trackingCoverage.present
          ? data.trackingCoverage.value
          : this.trackingCoverage,
      ruleTemplateJson: data.ruleTemplateJson.present
          ? data.ruleTemplateJson.value
          : this.ruleTemplateJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      timerEnabled: data.timerEnabled.present
          ? data.timerEnabled.value
          : this.timerEnabled,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Matche(')
          ..write('id: $id, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('recordingMode: $recordingMode, ')
          ..write('trackingCoverage: $trackingCoverage, ')
          ..write('ruleTemplateJson: $ruleTemplateJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('timerEnabled: $timerEnabled, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lifecycle,
    recordingMode,
    trackingCoverage,
    ruleTemplateJson,
    createdAt,
    startedAt,
    endedAt,
    timerEnabled,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Matche &&
          other.id == this.id &&
          other.lifecycle == this.lifecycle &&
          other.recordingMode == this.recordingMode &&
          other.trackingCoverage == this.trackingCoverage &&
          other.ruleTemplateJson == this.ruleTemplateJson &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.timerEnabled == this.timerEnabled &&
          other.note == this.note);
}

class MatchesCompanion extends UpdateCompanion<Matche> {
  final Value<String> id;
  final Value<String> lifecycle;
  final Value<String> recordingMode;
  final Value<String> trackingCoverage;
  final Value<String> ruleTemplateJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> endedAt;
  final Value<bool> timerEnabled;
  final Value<String?> note;
  final Value<int> rowid;
  const MatchesCompanion({
    this.id = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.recordingMode = const Value.absent(),
    this.trackingCoverage = const Value.absent(),
    this.ruleTemplateJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.timerEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String id,
    this.lifecycle = const Value.absent(),
    this.recordingMode = const Value.absent(),
    this.trackingCoverage = const Value.absent(),
    required String ruleTemplateJson,
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.timerEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ruleTemplateJson = Value(ruleTemplateJson),
       createdAt = Value(createdAt);
  static Insertable<Matche> custom({
    Expression<String>? id,
    Expression<String>? lifecycle,
    Expression<String>? recordingMode,
    Expression<String>? trackingCoverage,
    Expression<String>? ruleTemplateJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? timerEnabled,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (recordingMode != null) 'recording_mode': recordingMode,
      if (trackingCoverage != null) 'tracking_coverage': trackingCoverage,
      if (ruleTemplateJson != null) 'rule_template_json': ruleTemplateJson,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (timerEnabled != null) 'timer_enabled': timerEnabled,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? lifecycle,
    Value<String>? recordingMode,
    Value<String>? trackingCoverage,
    Value<String>? ruleTemplateJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? endedAt,
    Value<bool>? timerEnabled,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return MatchesCompanion(
      id: id ?? this.id,
      lifecycle: lifecycle ?? this.lifecycle,
      recordingMode: recordingMode ?? this.recordingMode,
      trackingCoverage: trackingCoverage ?? this.trackingCoverage,
      ruleTemplateJson: ruleTemplateJson ?? this.ruleTemplateJson,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (recordingMode.present) {
      map['recording_mode'] = Variable<String>(recordingMode.value);
    }
    if (trackingCoverage.present) {
      map['tracking_coverage'] = Variable<String>(trackingCoverage.value);
    }
    if (ruleTemplateJson.present) {
      map['rule_template_json'] = Variable<String>(ruleTemplateJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (timerEnabled.present) {
      map['timer_enabled'] = Variable<bool>(timerEnabled.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('id: $id, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('recordingMode: $recordingMode, ')
          ..write('trackingCoverage: $trackingCoverage, ')
          ..write('ruleTemplateJson: $ruleTemplateJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('timerEnabled: $timerEnabled, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayersTable extends Players with TableInfo<$PlayersTable, PlayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferredSideMeta = const VerificationMeta(
    'preferredSide',
  );
  @override
  late final GeneratedColumn<String> preferredSide = GeneratedColumn<String>(
    'preferred_side',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nickname,
    createdAt,
    preferredSide,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('preferred_side')) {
      context.handle(
        _preferredSideMeta,
        preferredSide.isAcceptableOrUnknown(
          data['preferred_side']!,
          _preferredSideMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      preferredSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_side'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class PlayerRow extends DataClass implements Insertable<PlayerRow> {
  final String id;
  final String nickname;
  final DateTime createdAt;
  final String? preferredSide;
  final String? note;
  const PlayerRow({
    required this.id,
    required this.nickname,
    required this.createdAt,
    this.preferredSide,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nickname'] = Variable<String>(nickname);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || preferredSide != null) {
      map['preferred_side'] = Variable<String>(preferredSide);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      nickname: Value(nickname),
      createdAt: Value(createdAt),
      preferredSide: preferredSide == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSide),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory PlayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerRow(
      id: serializer.fromJson<String>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      preferredSide: serializer.fromJson<String?>(json['preferredSide']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nickname': serializer.toJson<String>(nickname),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'preferredSide': serializer.toJson<String?>(preferredSide),
      'note': serializer.toJson<String?>(note),
    };
  }

  PlayerRow copyWith({
    String? id,
    String? nickname,
    DateTime? createdAt,
    Value<String?> preferredSide = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => PlayerRow(
    id: id ?? this.id,
    nickname: nickname ?? this.nickname,
    createdAt: createdAt ?? this.createdAt,
    preferredSide: preferredSide.present
        ? preferredSide.value
        : this.preferredSide,
    note: note.present ? note.value : this.note,
  );
  PlayerRow copyWithCompanion(PlayersCompanion data) {
    return PlayerRow(
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      preferredSide: data.preferredSide.present
          ? data.preferredSide.value
          : this.preferredSide,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerRow(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('createdAt: $createdAt, ')
          ..write('preferredSide: $preferredSide, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nickname, createdAt, preferredSide, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerRow &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.createdAt == this.createdAt &&
          other.preferredSide == this.preferredSide &&
          other.note == this.note);
}

class PlayersCompanion extends UpdateCompanion<PlayerRow> {
  final Value<String> id;
  final Value<String> nickname;
  final Value<DateTime> createdAt;
  final Value<String?> preferredSide;
  final Value<String?> note;
  final Value<int> rowid;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.preferredSide = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayersCompanion.insert({
    required String id,
    required String nickname,
    required DateTime createdAt,
    this.preferredSide = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nickname = Value(nickname),
       createdAt = Value(createdAt);
  static Insertable<PlayerRow> custom({
    Expression<String>? id,
    Expression<String>? nickname,
    Expression<DateTime>? createdAt,
    Expression<String>? preferredSide,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (createdAt != null) 'created_at': createdAt,
      if (preferredSide != null) 'preferred_side': preferredSide,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayersCompanion copyWith({
    Value<String>? id,
    Value<String>? nickname,
    Value<DateTime>? createdAt,
    Value<String?>? preferredSide,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      preferredSide: preferredSide ?? this.preferredSide,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (preferredSide.present) {
      map['preferred_side'] = Variable<String>(preferredSide.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('createdAt: $createdAt, ')
          ..write('preferredSide: $preferredSide, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchSeriesTable extends MatchSeries
    with TableInfo<$MatchSeriesTable, MatchSeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchSeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotANameMeta = const VerificationMeta(
    'slotAName',
  );
  @override
  late final GeneratedColumn<String> slotAName = GeneratedColumn<String>(
    'slot_a_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotBNameMeta = const VerificationMeta(
    'slotBName',
  );
  @override
  late final GeneratedColumn<String> slotBName = GeneratedColumn<String>(
    'slot_b_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotAPlayerProfileIdMeta =
      const VerificationMeta('slotAPlayerProfileId');
  @override
  late final GeneratedColumn<String> slotAPlayerProfileId =
      GeneratedColumn<String>(
        'slot_a_player_profile_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES players (id) ON DELETE SET NULL',
        ),
      );
  static const VerificationMeta _slotBPlayerProfileIdMeta =
      const VerificationMeta('slotBPlayerProfileId');
  @override
  late final GeneratedColumn<String> slotBPlayerProfileId =
      GeneratedColumn<String>(
        'slot_b_player_profile_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES players (id) ON DELETE SET NULL',
        ),
      );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextGameNumberMeta = const VerificationMeta(
    'nextGameNumber',
  );
  @override
  late final GeneratedColumn<int> nextGameNumber = GeneratedColumn<int>(
    'next_game_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _defaultSetupJsonMeta = const VerificationMeta(
    'defaultSetupJson',
  );
  @override
  late final GeneratedColumn<String> defaultSetupJson = GeneratedColumn<String>(
    'default_setup_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lifecycleIntentsJsonMeta =
      const VerificationMeta('lifecycleIntentsJson');
  @override
  late final GeneratedColumn<String> lifecycleIntentsJson =
      GeneratedColumn<String>(
        'lifecycle_intents_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slotAName,
    slotBName,
    slotAPlayerProfileId,
    slotBPlayerProfileId,
    lifecycle,
    createdAt,
    closedAt,
    nextGameNumber,
    revision,
    defaultSetupJson,
    lifecycleIntentsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchSeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slot_a_name')) {
      context.handle(
        _slotANameMeta,
        slotAName.isAcceptableOrUnknown(data['slot_a_name']!, _slotANameMeta),
      );
    } else if (isInserting) {
      context.missing(_slotANameMeta);
    }
    if (data.containsKey('slot_b_name')) {
      context.handle(
        _slotBNameMeta,
        slotBName.isAcceptableOrUnknown(data['slot_b_name']!, _slotBNameMeta),
      );
    } else if (isInserting) {
      context.missing(_slotBNameMeta);
    }
    if (data.containsKey('slot_a_player_profile_id')) {
      context.handle(
        _slotAPlayerProfileIdMeta,
        slotAPlayerProfileId.isAcceptableOrUnknown(
          data['slot_a_player_profile_id']!,
          _slotAPlayerProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('slot_b_player_profile_id')) {
      context.handle(
        _slotBPlayerProfileIdMeta,
        slotBPlayerProfileId.isAcceptableOrUnknown(
          data['slot_b_player_profile_id']!,
          _slotBPlayerProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('next_game_number')) {
      context.handle(
        _nextGameNumberMeta,
        nextGameNumber.isAcceptableOrUnknown(
          data['next_game_number']!,
          _nextGameNumberMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('default_setup_json')) {
      context.handle(
        _defaultSetupJsonMeta,
        defaultSetupJson.isAcceptableOrUnknown(
          data['default_setup_json']!,
          _defaultSetupJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultSetupJsonMeta);
    }
    if (data.containsKey('lifecycle_intents_json')) {
      context.handle(
        _lifecycleIntentsJsonMeta,
        lifecycleIntentsJson.isAcceptableOrUnknown(
          data['lifecycle_intents_json']!,
          _lifecycleIntentsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchSeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchSeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slotAName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_a_name'],
      )!,
      slotBName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_b_name'],
      )!,
      slotAPlayerProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_a_player_profile_id'],
      ),
      slotBPlayerProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_b_player_profile_id'],
      ),
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      nextGameNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_game_number'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      defaultSetupJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_setup_json'],
      )!,
      lifecycleIntentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle_intents_json'],
      )!,
    );
  }

  @override
  $MatchSeriesTable createAlias(String alias) {
    return $MatchSeriesTable(attachedDatabase, alias);
  }
}

class MatchSeriesRow extends DataClass implements Insertable<MatchSeriesRow> {
  final String id;
  final String slotAName;
  final String slotBName;
  final String? slotAPlayerProfileId;
  final String? slotBPlayerProfileId;
  final String lifecycle;
  final DateTime createdAt;
  final DateTime? closedAt;
  final int nextGameNumber;
  final int revision;
  final String defaultSetupJson;
  final String lifecycleIntentsJson;
  const MatchSeriesRow({
    required this.id,
    required this.slotAName,
    required this.slotBName,
    this.slotAPlayerProfileId,
    this.slotBPlayerProfileId,
    required this.lifecycle,
    required this.createdAt,
    this.closedAt,
    required this.nextGameNumber,
    required this.revision,
    required this.defaultSetupJson,
    required this.lifecycleIntentsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slot_a_name'] = Variable<String>(slotAName);
    map['slot_b_name'] = Variable<String>(slotBName);
    if (!nullToAbsent || slotAPlayerProfileId != null) {
      map['slot_a_player_profile_id'] = Variable<String>(slotAPlayerProfileId);
    }
    if (!nullToAbsent || slotBPlayerProfileId != null) {
      map['slot_b_player_profile_id'] = Variable<String>(slotBPlayerProfileId);
    }
    map['lifecycle'] = Variable<String>(lifecycle);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    map['next_game_number'] = Variable<int>(nextGameNumber);
    map['revision'] = Variable<int>(revision);
    map['default_setup_json'] = Variable<String>(defaultSetupJson);
    map['lifecycle_intents_json'] = Variable<String>(lifecycleIntentsJson);
    return map;
  }

  MatchSeriesCompanion toCompanion(bool nullToAbsent) {
    return MatchSeriesCompanion(
      id: Value(id),
      slotAName: Value(slotAName),
      slotBName: Value(slotBName),
      slotAPlayerProfileId: slotAPlayerProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(slotAPlayerProfileId),
      slotBPlayerProfileId: slotBPlayerProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(slotBPlayerProfileId),
      lifecycle: Value(lifecycle),
      createdAt: Value(createdAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      nextGameNumber: Value(nextGameNumber),
      revision: Value(revision),
      defaultSetupJson: Value(defaultSetupJson),
      lifecycleIntentsJson: Value(lifecycleIntentsJson),
    );
  }

  factory MatchSeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchSeriesRow(
      id: serializer.fromJson<String>(json['id']),
      slotAName: serializer.fromJson<String>(json['slotAName']),
      slotBName: serializer.fromJson<String>(json['slotBName']),
      slotAPlayerProfileId: serializer.fromJson<String?>(
        json['slotAPlayerProfileId'],
      ),
      slotBPlayerProfileId: serializer.fromJson<String?>(
        json['slotBPlayerProfileId'],
      ),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      nextGameNumber: serializer.fromJson<int>(json['nextGameNumber']),
      revision: serializer.fromJson<int>(json['revision']),
      defaultSetupJson: serializer.fromJson<String>(json['defaultSetupJson']),
      lifecycleIntentsJson: serializer.fromJson<String>(
        json['lifecycleIntentsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slotAName': serializer.toJson<String>(slotAName),
      'slotBName': serializer.toJson<String>(slotBName),
      'slotAPlayerProfileId': serializer.toJson<String?>(slotAPlayerProfileId),
      'slotBPlayerProfileId': serializer.toJson<String?>(slotBPlayerProfileId),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'nextGameNumber': serializer.toJson<int>(nextGameNumber),
      'revision': serializer.toJson<int>(revision),
      'defaultSetupJson': serializer.toJson<String>(defaultSetupJson),
      'lifecycleIntentsJson': serializer.toJson<String>(lifecycleIntentsJson),
    };
  }

  MatchSeriesRow copyWith({
    String? id,
    String? slotAName,
    String? slotBName,
    Value<String?> slotAPlayerProfileId = const Value.absent(),
    Value<String?> slotBPlayerProfileId = const Value.absent(),
    String? lifecycle,
    DateTime? createdAt,
    Value<DateTime?> closedAt = const Value.absent(),
    int? nextGameNumber,
    int? revision,
    String? defaultSetupJson,
    String? lifecycleIntentsJson,
  }) => MatchSeriesRow(
    id: id ?? this.id,
    slotAName: slotAName ?? this.slotAName,
    slotBName: slotBName ?? this.slotBName,
    slotAPlayerProfileId: slotAPlayerProfileId.present
        ? slotAPlayerProfileId.value
        : this.slotAPlayerProfileId,
    slotBPlayerProfileId: slotBPlayerProfileId.present
        ? slotBPlayerProfileId.value
        : this.slotBPlayerProfileId,
    lifecycle: lifecycle ?? this.lifecycle,
    createdAt: createdAt ?? this.createdAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    nextGameNumber: nextGameNumber ?? this.nextGameNumber,
    revision: revision ?? this.revision,
    defaultSetupJson: defaultSetupJson ?? this.defaultSetupJson,
    lifecycleIntentsJson: lifecycleIntentsJson ?? this.lifecycleIntentsJson,
  );
  MatchSeriesRow copyWithCompanion(MatchSeriesCompanion data) {
    return MatchSeriesRow(
      id: data.id.present ? data.id.value : this.id,
      slotAName: data.slotAName.present ? data.slotAName.value : this.slotAName,
      slotBName: data.slotBName.present ? data.slotBName.value : this.slotBName,
      slotAPlayerProfileId: data.slotAPlayerProfileId.present
          ? data.slotAPlayerProfileId.value
          : this.slotAPlayerProfileId,
      slotBPlayerProfileId: data.slotBPlayerProfileId.present
          ? data.slotBPlayerProfileId.value
          : this.slotBPlayerProfileId,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      nextGameNumber: data.nextGameNumber.present
          ? data.nextGameNumber.value
          : this.nextGameNumber,
      revision: data.revision.present ? data.revision.value : this.revision,
      defaultSetupJson: data.defaultSetupJson.present
          ? data.defaultSetupJson.value
          : this.defaultSetupJson,
      lifecycleIntentsJson: data.lifecycleIntentsJson.present
          ? data.lifecycleIntentsJson.value
          : this.lifecycleIntentsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchSeriesRow(')
          ..write('id: $id, ')
          ..write('slotAName: $slotAName, ')
          ..write('slotBName: $slotBName, ')
          ..write('slotAPlayerProfileId: $slotAPlayerProfileId, ')
          ..write('slotBPlayerProfileId: $slotBPlayerProfileId, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('createdAt: $createdAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('nextGameNumber: $nextGameNumber, ')
          ..write('revision: $revision, ')
          ..write('defaultSetupJson: $defaultSetupJson, ')
          ..write('lifecycleIntentsJson: $lifecycleIntentsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    slotAName,
    slotBName,
    slotAPlayerProfileId,
    slotBPlayerProfileId,
    lifecycle,
    createdAt,
    closedAt,
    nextGameNumber,
    revision,
    defaultSetupJson,
    lifecycleIntentsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchSeriesRow &&
          other.id == this.id &&
          other.slotAName == this.slotAName &&
          other.slotBName == this.slotBName &&
          other.slotAPlayerProfileId == this.slotAPlayerProfileId &&
          other.slotBPlayerProfileId == this.slotBPlayerProfileId &&
          other.lifecycle == this.lifecycle &&
          other.createdAt == this.createdAt &&
          other.closedAt == this.closedAt &&
          other.nextGameNumber == this.nextGameNumber &&
          other.revision == this.revision &&
          other.defaultSetupJson == this.defaultSetupJson &&
          other.lifecycleIntentsJson == this.lifecycleIntentsJson);
}

class MatchSeriesCompanion extends UpdateCompanion<MatchSeriesRow> {
  final Value<String> id;
  final Value<String> slotAName;
  final Value<String> slotBName;
  final Value<String?> slotAPlayerProfileId;
  final Value<String?> slotBPlayerProfileId;
  final Value<String> lifecycle;
  final Value<DateTime> createdAt;
  final Value<DateTime?> closedAt;
  final Value<int> nextGameNumber;
  final Value<int> revision;
  final Value<String> defaultSetupJson;
  final Value<String> lifecycleIntentsJson;
  final Value<int> rowid;
  const MatchSeriesCompanion({
    this.id = const Value.absent(),
    this.slotAName = const Value.absent(),
    this.slotBName = const Value.absent(),
    this.slotAPlayerProfileId = const Value.absent(),
    this.slotBPlayerProfileId = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.nextGameNumber = const Value.absent(),
    this.revision = const Value.absent(),
    this.defaultSetupJson = const Value.absent(),
    this.lifecycleIntentsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchSeriesCompanion.insert({
    required String id,
    required String slotAName,
    required String slotBName,
    this.slotAPlayerProfileId = const Value.absent(),
    this.slotBPlayerProfileId = const Value.absent(),
    this.lifecycle = const Value.absent(),
    required DateTime createdAt,
    this.closedAt = const Value.absent(),
    this.nextGameNumber = const Value.absent(),
    this.revision = const Value.absent(),
    required String defaultSetupJson,
    this.lifecycleIntentsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       slotAName = Value(slotAName),
       slotBName = Value(slotBName),
       createdAt = Value(createdAt),
       defaultSetupJson = Value(defaultSetupJson);
  static Insertable<MatchSeriesRow> custom({
    Expression<String>? id,
    Expression<String>? slotAName,
    Expression<String>? slotBName,
    Expression<String>? slotAPlayerProfileId,
    Expression<String>? slotBPlayerProfileId,
    Expression<String>? lifecycle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? closedAt,
    Expression<int>? nextGameNumber,
    Expression<int>? revision,
    Expression<String>? defaultSetupJson,
    Expression<String>? lifecycleIntentsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slotAName != null) 'slot_a_name': slotAName,
      if (slotBName != null) 'slot_b_name': slotBName,
      if (slotAPlayerProfileId != null)
        'slot_a_player_profile_id': slotAPlayerProfileId,
      if (slotBPlayerProfileId != null)
        'slot_b_player_profile_id': slotBPlayerProfileId,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (createdAt != null) 'created_at': createdAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (nextGameNumber != null) 'next_game_number': nextGameNumber,
      if (revision != null) 'revision': revision,
      if (defaultSetupJson != null) 'default_setup_json': defaultSetupJson,
      if (lifecycleIntentsJson != null)
        'lifecycle_intents_json': lifecycleIntentsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchSeriesCompanion copyWith({
    Value<String>? id,
    Value<String>? slotAName,
    Value<String>? slotBName,
    Value<String?>? slotAPlayerProfileId,
    Value<String?>? slotBPlayerProfileId,
    Value<String>? lifecycle,
    Value<DateTime>? createdAt,
    Value<DateTime?>? closedAt,
    Value<int>? nextGameNumber,
    Value<int>? revision,
    Value<String>? defaultSetupJson,
    Value<String>? lifecycleIntentsJson,
    Value<int>? rowid,
  }) {
    return MatchSeriesCompanion(
      id: id ?? this.id,
      slotAName: slotAName ?? this.slotAName,
      slotBName: slotBName ?? this.slotBName,
      slotAPlayerProfileId: slotAPlayerProfileId ?? this.slotAPlayerProfileId,
      slotBPlayerProfileId: slotBPlayerProfileId ?? this.slotBPlayerProfileId,
      lifecycle: lifecycle ?? this.lifecycle,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      nextGameNumber: nextGameNumber ?? this.nextGameNumber,
      revision: revision ?? this.revision,
      defaultSetupJson: defaultSetupJson ?? this.defaultSetupJson,
      lifecycleIntentsJson: lifecycleIntentsJson ?? this.lifecycleIntentsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slotAName.present) {
      map['slot_a_name'] = Variable<String>(slotAName.value);
    }
    if (slotBName.present) {
      map['slot_b_name'] = Variable<String>(slotBName.value);
    }
    if (slotAPlayerProfileId.present) {
      map['slot_a_player_profile_id'] = Variable<String>(
        slotAPlayerProfileId.value,
      );
    }
    if (slotBPlayerProfileId.present) {
      map['slot_b_player_profile_id'] = Variable<String>(
        slotBPlayerProfileId.value,
      );
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (nextGameNumber.present) {
      map['next_game_number'] = Variable<int>(nextGameNumber.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (defaultSetupJson.present) {
      map['default_setup_json'] = Variable<String>(defaultSetupJson.value);
    }
    if (lifecycleIntentsJson.present) {
      map['lifecycle_intents_json'] = Variable<String>(
        lifecycleIntentsJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchSeriesCompanion(')
          ..write('id: $id, ')
          ..write('slotAName: $slotAName, ')
          ..write('slotBName: $slotBName, ')
          ..write('slotAPlayerProfileId: $slotAPlayerProfileId, ')
          ..write('slotBPlayerProfileId: $slotBPlayerProfileId, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('createdAt: $createdAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('nextGameNumber: $nextGameNumber, ')
          ..write('revision: $revision, ')
          ..write('defaultSetupJson: $defaultSetupJson, ')
          ..write('lifecycleIntentsJson: $lifecycleIntentsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesMatchesTable extends SeriesMatches
    with TableInfo<$SeriesMatchesTable, SeriesMatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_series (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _gameNumberMeta = const VerificationMeta(
    'gameNumber',
  );
  @override
  late final GeneratedColumn<int> gameNumber = GeneratedColumn<int>(
    'game_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotASideMeta = const VerificationMeta(
    'slotASide',
  );
  @override
  late final GeneratedColumn<String> slotASide = GeneratedColumn<String>(
    'slot_a_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    matchId,
    seriesId,
    gameNumber,
    slotASide,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesMatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('game_number')) {
      context.handle(
        _gameNumberMeta,
        gameNumber.isAcceptableOrUnknown(data['game_number']!, _gameNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_gameNumberMeta);
    }
    if (data.containsKey('slot_a_side')) {
      context.handle(
        _slotASideMeta,
        slotASide.isAcceptableOrUnknown(data['slot_a_side']!, _slotASideMeta),
      );
    } else if (isInserting) {
      context.missing(_slotASideMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId};
  @override
  SeriesMatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesMatche(
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      gameNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_number'],
      )!,
      slotASide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_a_side'],
      )!,
    );
  }

  @override
  $SeriesMatchesTable createAlias(String alias) {
    return $SeriesMatchesTable(attachedDatabase, alias);
  }
}

class SeriesMatche extends DataClass implements Insertable<SeriesMatche> {
  final String matchId;
  final String seriesId;
  final int gameNumber;
  final String slotASide;
  const SeriesMatche({
    required this.matchId,
    required this.seriesId,
    required this.gameNumber,
    required this.slotASide,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['series_id'] = Variable<String>(seriesId);
    map['game_number'] = Variable<int>(gameNumber);
    map['slot_a_side'] = Variable<String>(slotASide);
    return map;
  }

  SeriesMatchesCompanion toCompanion(bool nullToAbsent) {
    return SeriesMatchesCompanion(
      matchId: Value(matchId),
      seriesId: Value(seriesId),
      gameNumber: Value(gameNumber),
      slotASide: Value(slotASide),
    );
  }

  factory SeriesMatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesMatche(
      matchId: serializer.fromJson<String>(json['matchId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      gameNumber: serializer.fromJson<int>(json['gameNumber']),
      slotASide: serializer.fromJson<String>(json['slotASide']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'matchId': serializer.toJson<String>(matchId),
      'seriesId': serializer.toJson<String>(seriesId),
      'gameNumber': serializer.toJson<int>(gameNumber),
      'slotASide': serializer.toJson<String>(slotASide),
    };
  }

  SeriesMatche copyWith({
    String? matchId,
    String? seriesId,
    int? gameNumber,
    String? slotASide,
  }) => SeriesMatche(
    matchId: matchId ?? this.matchId,
    seriesId: seriesId ?? this.seriesId,
    gameNumber: gameNumber ?? this.gameNumber,
    slotASide: slotASide ?? this.slotASide,
  );
  SeriesMatche copyWithCompanion(SeriesMatchesCompanion data) {
    return SeriesMatche(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      gameNumber: data.gameNumber.present
          ? data.gameNumber.value
          : this.gameNumber,
      slotASide: data.slotASide.present ? data.slotASide.value : this.slotASide,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesMatche(')
          ..write('matchId: $matchId, ')
          ..write('seriesId: $seriesId, ')
          ..write('gameNumber: $gameNumber, ')
          ..write('slotASide: $slotASide')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(matchId, seriesId, gameNumber, slotASide);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesMatche &&
          other.matchId == this.matchId &&
          other.seriesId == this.seriesId &&
          other.gameNumber == this.gameNumber &&
          other.slotASide == this.slotASide);
}

class SeriesMatchesCompanion extends UpdateCompanion<SeriesMatche> {
  final Value<String> matchId;
  final Value<String> seriesId;
  final Value<int> gameNumber;
  final Value<String> slotASide;
  final Value<int> rowid;
  const SeriesMatchesCompanion({
    this.matchId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.gameNumber = const Value.absent(),
    this.slotASide = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesMatchesCompanion.insert({
    required String matchId,
    required String seriesId,
    required int gameNumber,
    required String slotASide,
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId),
       seriesId = Value(seriesId),
       gameNumber = Value(gameNumber),
       slotASide = Value(slotASide);
  static Insertable<SeriesMatche> custom({
    Expression<String>? matchId,
    Expression<String>? seriesId,
    Expression<int>? gameNumber,
    Expression<String>? slotASide,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (seriesId != null) 'series_id': seriesId,
      if (gameNumber != null) 'game_number': gameNumber,
      if (slotASide != null) 'slot_a_side': slotASide,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesMatchesCompanion copyWith({
    Value<String>? matchId,
    Value<String>? seriesId,
    Value<int>? gameNumber,
    Value<String>? slotASide,
    Value<int>? rowid,
  }) {
    return SeriesMatchesCompanion(
      matchId: matchId ?? this.matchId,
      seriesId: seriesId ?? this.seriesId,
      gameNumber: gameNumber ?? this.gameNumber,
      slotASide: slotASide ?? this.slotASide,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (gameNumber.present) {
      map['game_number'] = Variable<int>(gameNumber.value);
    }
    if (slotASide.present) {
      map['slot_a_side'] = Variable<String>(slotASide.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesMatchesCompanion(')
          ..write('matchId: $matchId, ')
          ..write('seriesId: $seriesId, ')
          ..write('gameNumber: $gameNumber, ')
          ..write('slotASide: $slotASide, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchParticipantsTable extends MatchParticipants
    with TableInfo<$MatchParticipantsTable, MatchParticipant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchParticipantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameSnapshotMeta = const VerificationMeta(
    'nameSnapshot',
  );
  @override
  late final GeneratedColumn<String> nameSnapshot = GeneratedColumn<String>(
    'name_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerProfileIdMeta = const VerificationMeta(
    'playerProfileId',
  );
  @override
  late final GeneratedColumn<String> playerProfileId = GeneratedColumn<String>(
    'player_profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    side,
    nameSnapshot,
    playerProfileId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_participants';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchParticipant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    } else if (isInserting) {
      context.missing(_sideMeta);
    }
    if (data.containsKey('name_snapshot')) {
      context.handle(
        _nameSnapshotMeta,
        nameSnapshot.isAcceptableOrUnknown(
          data['name_snapshot']!,
          _nameSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameSnapshotMeta);
    }
    if (data.containsKey('player_profile_id')) {
      context.handle(
        _playerProfileIdMeta,
        playerProfileId.isAcceptableOrUnknown(
          data['player_profile_id']!,
          _playerProfileIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchParticipant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchParticipant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      )!,
      nameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_snapshot'],
      )!,
      playerProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_profile_id'],
      ),
    );
  }

  @override
  $MatchParticipantsTable createAlias(String alias) {
    return $MatchParticipantsTable(attachedDatabase, alias);
  }
}

class MatchParticipant extends DataClass
    implements Insertable<MatchParticipant> {
  final String id;
  final String matchId;
  final String side;
  final String nameSnapshot;
  final String? playerProfileId;
  const MatchParticipant({
    required this.id,
    required this.matchId,
    required this.side,
    required this.nameSnapshot,
    this.playerProfileId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['side'] = Variable<String>(side);
    map['name_snapshot'] = Variable<String>(nameSnapshot);
    if (!nullToAbsent || playerProfileId != null) {
      map['player_profile_id'] = Variable<String>(playerProfileId);
    }
    return map;
  }

  MatchParticipantsCompanion toCompanion(bool nullToAbsent) {
    return MatchParticipantsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      side: Value(side),
      nameSnapshot: Value(nameSnapshot),
      playerProfileId: playerProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(playerProfileId),
    );
  }

  factory MatchParticipant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchParticipant(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      side: serializer.fromJson<String>(json['side']),
      nameSnapshot: serializer.fromJson<String>(json['nameSnapshot']),
      playerProfileId: serializer.fromJson<String?>(json['playerProfileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'side': serializer.toJson<String>(side),
      'nameSnapshot': serializer.toJson<String>(nameSnapshot),
      'playerProfileId': serializer.toJson<String?>(playerProfileId),
    };
  }

  MatchParticipant copyWith({
    String? id,
    String? matchId,
    String? side,
    String? nameSnapshot,
    Value<String?> playerProfileId = const Value.absent(),
  }) => MatchParticipant(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    side: side ?? this.side,
    nameSnapshot: nameSnapshot ?? this.nameSnapshot,
    playerProfileId: playerProfileId.present
        ? playerProfileId.value
        : this.playerProfileId,
  );
  MatchParticipant copyWithCompanion(MatchParticipantsCompanion data) {
    return MatchParticipant(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      side: data.side.present ? data.side.value : this.side,
      nameSnapshot: data.nameSnapshot.present
          ? data.nameSnapshot.value
          : this.nameSnapshot,
      playerProfileId: data.playerProfileId.present
          ? data.playerProfileId.value
          : this.playerProfileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchParticipant(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('side: $side, ')
          ..write('nameSnapshot: $nameSnapshot, ')
          ..write('playerProfileId: $playerProfileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, matchId, side, nameSnapshot, playerProfileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchParticipant &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.side == this.side &&
          other.nameSnapshot == this.nameSnapshot &&
          other.playerProfileId == this.playerProfileId);
}

class MatchParticipantsCompanion extends UpdateCompanion<MatchParticipant> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> side;
  final Value<String> nameSnapshot;
  final Value<String?> playerProfileId;
  final Value<int> rowid;
  const MatchParticipantsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.side = const Value.absent(),
    this.nameSnapshot = const Value.absent(),
    this.playerProfileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchParticipantsCompanion.insert({
    required String id,
    required String matchId,
    required String side,
    required String nameSnapshot,
    this.playerProfileId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       side = Value(side),
       nameSnapshot = Value(nameSnapshot);
  static Insertable<MatchParticipant> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? side,
    Expression<String>? nameSnapshot,
    Expression<String>? playerProfileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (side != null) 'side': side,
      if (nameSnapshot != null) 'name_snapshot': nameSnapshot,
      if (playerProfileId != null) 'player_profile_id': playerProfileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchParticipantsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? side,
    Value<String>? nameSnapshot,
    Value<String?>? playerProfileId,
    Value<int>? rowid,
  }) {
    return MatchParticipantsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      side: side ?? this.side,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      playerProfileId: playerProfileId ?? this.playerProfileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (nameSnapshot.present) {
      map['name_snapshot'] = Variable<String>(nameSnapshot.value);
    }
    if (playerProfileId.present) {
      map['player_profile_id'] = Variable<String>(playerProfileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchParticipantsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('side: $side, ')
          ..write('nameSnapshot: $nameSnapshot, ')
          ..write('playerProfileId: $playerProfileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchClocksTable extends MatchClocks
    with TableInfo<$MatchClocksTable, MatchClock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchClocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('countUp'),
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('regulation'),
  );
  static const VerificationMeta _accumulatedSecondsMeta =
      const VerificationMeta('accumulatedSeconds');
  @override
  late final GeneratedColumn<int> accumulatedSeconds = GeneratedColumn<int>(
    'accumulated_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _runningSinceUtcMeta = const VerificationMeta(
    'runningSinceUtc',
  );
  @override
  late final GeneratedColumn<DateTime> runningSinceUtc =
      GeneratedColumn<DateTime>(
        'running_since_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _regulationSecondsMeta = const VerificationMeta(
    'regulationSeconds',
  );
  @override
  late final GeneratedColumn<int> regulationSeconds = GeneratedColumn<int>(
    'regulation_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    mode,
    phase,
    accumulatedSeconds,
    runningSinceUtc,
    regulationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_clocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchClock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    }
    if (data.containsKey('accumulated_seconds')) {
      context.handle(
        _accumulatedSecondsMeta,
        accumulatedSeconds.isAcceptableOrUnknown(
          data['accumulated_seconds']!,
          _accumulatedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('running_since_utc')) {
      context.handle(
        _runningSinceUtcMeta,
        runningSinceUtc.isAcceptableOrUnknown(
          data['running_since_utc']!,
          _runningSinceUtcMeta,
        ),
      );
    }
    if (data.containsKey('regulation_seconds')) {
      context.handle(
        _regulationSecondsMeta,
        regulationSeconds.isAcceptableOrUnknown(
          data['regulation_seconds']!,
          _regulationSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchClock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchClock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      accumulatedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accumulated_seconds'],
      )!,
      runningSinceUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}running_since_utc'],
      ),
      regulationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}regulation_seconds'],
      ),
    );
  }

  @override
  $MatchClocksTable createAlias(String alias) {
    return $MatchClocksTable(attachedDatabase, alias);
  }
}

class MatchClock extends DataClass implements Insertable<MatchClock> {
  final String id;
  final String matchId;
  final String mode;
  final String phase;
  final int accumulatedSeconds;
  final DateTime? runningSinceUtc;
  final int? regulationSeconds;
  const MatchClock({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.phase,
    required this.accumulatedSeconds,
    this.runningSinceUtc,
    this.regulationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['mode'] = Variable<String>(mode);
    map['phase'] = Variable<String>(phase);
    map['accumulated_seconds'] = Variable<int>(accumulatedSeconds);
    if (!nullToAbsent || runningSinceUtc != null) {
      map['running_since_utc'] = Variable<DateTime>(runningSinceUtc);
    }
    if (!nullToAbsent || regulationSeconds != null) {
      map['regulation_seconds'] = Variable<int>(regulationSeconds);
    }
    return map;
  }

  MatchClocksCompanion toCompanion(bool nullToAbsent) {
    return MatchClocksCompanion(
      id: Value(id),
      matchId: Value(matchId),
      mode: Value(mode),
      phase: Value(phase),
      accumulatedSeconds: Value(accumulatedSeconds),
      runningSinceUtc: runningSinceUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(runningSinceUtc),
      regulationSeconds: regulationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(regulationSeconds),
    );
  }

  factory MatchClock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchClock(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      mode: serializer.fromJson<String>(json['mode']),
      phase: serializer.fromJson<String>(json['phase']),
      accumulatedSeconds: serializer.fromJson<int>(json['accumulatedSeconds']),
      runningSinceUtc: serializer.fromJson<DateTime?>(json['runningSinceUtc']),
      regulationSeconds: serializer.fromJson<int?>(json['regulationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'mode': serializer.toJson<String>(mode),
      'phase': serializer.toJson<String>(phase),
      'accumulatedSeconds': serializer.toJson<int>(accumulatedSeconds),
      'runningSinceUtc': serializer.toJson<DateTime?>(runningSinceUtc),
      'regulationSeconds': serializer.toJson<int?>(regulationSeconds),
    };
  }

  MatchClock copyWith({
    String? id,
    String? matchId,
    String? mode,
    String? phase,
    int? accumulatedSeconds,
    Value<DateTime?> runningSinceUtc = const Value.absent(),
    Value<int?> regulationSeconds = const Value.absent(),
  }) => MatchClock(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    mode: mode ?? this.mode,
    phase: phase ?? this.phase,
    accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
    runningSinceUtc: runningSinceUtc.present
        ? runningSinceUtc.value
        : this.runningSinceUtc,
    regulationSeconds: regulationSeconds.present
        ? regulationSeconds.value
        : this.regulationSeconds,
  );
  MatchClock copyWithCompanion(MatchClocksCompanion data) {
    return MatchClock(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      mode: data.mode.present ? data.mode.value : this.mode,
      phase: data.phase.present ? data.phase.value : this.phase,
      accumulatedSeconds: data.accumulatedSeconds.present
          ? data.accumulatedSeconds.value
          : this.accumulatedSeconds,
      runningSinceUtc: data.runningSinceUtc.present
          ? data.runningSinceUtc.value
          : this.runningSinceUtc,
      regulationSeconds: data.regulationSeconds.present
          ? data.regulationSeconds.value
          : this.regulationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchClock(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('mode: $mode, ')
          ..write('phase: $phase, ')
          ..write('accumulatedSeconds: $accumulatedSeconds, ')
          ..write('runningSinceUtc: $runningSinceUtc, ')
          ..write('regulationSeconds: $regulationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    mode,
    phase,
    accumulatedSeconds,
    runningSinceUtc,
    regulationSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchClock &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.mode == this.mode &&
          other.phase == this.phase &&
          other.accumulatedSeconds == this.accumulatedSeconds &&
          other.runningSinceUtc == this.runningSinceUtc &&
          other.regulationSeconds == this.regulationSeconds);
}

class MatchClocksCompanion extends UpdateCompanion<MatchClock> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> mode;
  final Value<String> phase;
  final Value<int> accumulatedSeconds;
  final Value<DateTime?> runningSinceUtc;
  final Value<int?> regulationSeconds;
  final Value<int> rowid;
  const MatchClocksCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.mode = const Value.absent(),
    this.phase = const Value.absent(),
    this.accumulatedSeconds = const Value.absent(),
    this.runningSinceUtc = const Value.absent(),
    this.regulationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchClocksCompanion.insert({
    required String id,
    required String matchId,
    this.mode = const Value.absent(),
    this.phase = const Value.absent(),
    this.accumulatedSeconds = const Value.absent(),
    this.runningSinceUtc = const Value.absent(),
    this.regulationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId);
  static Insertable<MatchClock> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? mode,
    Expression<String>? phase,
    Expression<int>? accumulatedSeconds,
    Expression<DateTime>? runningSinceUtc,
    Expression<int>? regulationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (mode != null) 'mode': mode,
      if (phase != null) 'phase': phase,
      if (accumulatedSeconds != null) 'accumulated_seconds': accumulatedSeconds,
      if (runningSinceUtc != null) 'running_since_utc': runningSinceUtc,
      if (regulationSeconds != null) 'regulation_seconds': regulationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchClocksCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? mode,
    Value<String>? phase,
    Value<int>? accumulatedSeconds,
    Value<DateTime?>? runningSinceUtc,
    Value<int?>? regulationSeconds,
    Value<int>? rowid,
  }) {
    return MatchClocksCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      runningSinceUtc: runningSinceUtc ?? this.runningSinceUtc,
      regulationSeconds: regulationSeconds ?? this.regulationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (accumulatedSeconds.present) {
      map['accumulated_seconds'] = Variable<int>(accumulatedSeconds.value);
    }
    if (runningSinceUtc.present) {
      map['running_since_utc'] = Variable<DateTime>(runningSinceUtc.value);
    }
    if (regulationSeconds.present) {
      map['regulation_seconds'] = Variable<int>(regulationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchClocksCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('mode: $mode, ')
          ..write('phase: $phase, ')
          ..write('accumulatedSeconds: $accumulatedSeconds, ')
          ..write('runningSinceUtc: $runningSinceUtc, ')
          ..write('regulationSeconds: $regulationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveSessionsTable extends ActiveSessions
    with TableInfo<$ActiveSessionsTable, ActiveSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _claimedAtUtcMeta = const VerificationMeta(
    'claimedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> claimedAtUtc = GeneratedColumn<DateTime>(
    'claimed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, matchId, claimedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('claimed_at_utc')) {
      context.handle(
        _claimedAtUtcMeta,
        claimedAtUtc.isAcceptableOrUnknown(
          data['claimed_at_utc']!,
          _claimedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      claimedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}claimed_at_utc'],
      )!,
    );
  }

  @override
  $ActiveSessionsTable createAlias(String alias) {
    return $ActiveSessionsTable(attachedDatabase, alias);
  }
}

class ActiveSession extends DataClass implements Insertable<ActiveSession> {
  final String id;
  final String matchId;
  final DateTime claimedAtUtc;
  const ActiveSession({
    required this.id,
    required this.matchId,
    required this.claimedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['claimed_at_utc'] = Variable<DateTime>(claimedAtUtc);
    return map;
  }

  ActiveSessionsCompanion toCompanion(bool nullToAbsent) {
    return ActiveSessionsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      claimedAtUtc: Value(claimedAtUtc),
    );
  }

  factory ActiveSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveSession(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      claimedAtUtc: serializer.fromJson<DateTime>(json['claimedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'claimedAtUtc': serializer.toJson<DateTime>(claimedAtUtc),
    };
  }

  ActiveSession copyWith({
    String? id,
    String? matchId,
    DateTime? claimedAtUtc,
  }) => ActiveSession(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    claimedAtUtc: claimedAtUtc ?? this.claimedAtUtc,
  );
  ActiveSession copyWithCompanion(ActiveSessionsCompanion data) {
    return ActiveSession(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      claimedAtUtc: data.claimedAtUtc.present
          ? data.claimedAtUtc.value
          : this.claimedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSession(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('claimedAtUtc: $claimedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, claimedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveSession &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.claimedAtUtc == this.claimedAtUtc);
}

class ActiveSessionsCompanion extends UpdateCompanion<ActiveSession> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<DateTime> claimedAtUtc;
  final Value<int> rowid;
  const ActiveSessionsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.claimedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String matchId,
    this.claimedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId);
  static Insertable<ActiveSession> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<DateTime>? claimedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (claimedAtUtc != null) 'claimed_at_utc': claimedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<DateTime>? claimedAtUtc,
    Value<int>? rowid,
  }) {
    return ActiveSessionsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      claimedAtUtc: claimedAtUtc ?? this.claimedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (claimedAtUtc.present) {
      map['claimed_at_utc'] = Variable<DateTime>(claimedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSessionsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('claimedAtUtc: $claimedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchEventsTable extends MatchEvents
    with TableInfo<$MatchEventsTable, MatchEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchClockPositionSecondsMeta =
      const VerificationMeta('matchClockPositionSeconds');
  @override
  late final GeneratedColumn<int> matchClockPositionSeconds =
      GeneratedColumn<int>(
        'match_clock_position_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customLabelMeta = const VerificationMeta(
    'customLabel',
  );
  @override
  late final GeneratedColumn<String> customLabel = GeneratedColumn<String>(
    'custom_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    type,
    side,
    points,
    outcome,
    matchClockPositionSeconds,
    occurredAt,
    note,
    customLabel,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('match_clock_position_seconds')) {
      context.handle(
        _matchClockPositionSecondsMeta,
        matchClockPositionSeconds.isAcceptableOrUnknown(
          data['match_clock_position_seconds']!,
          _matchClockPositionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('custom_label')) {
      context.handle(
        _customLabelMeta,
        customLabel.isAcceptableOrUnknown(
          data['custom_label']!,
          _customLabelMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      matchClockPositionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_clock_position_seconds'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      customLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_label'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $MatchEventsTable createAlias(String alias) {
    return $MatchEventsTable(attachedDatabase, alias);
  }
}

class MatchEventRow extends DataClass implements Insertable<MatchEventRow> {
  final String id;
  final String matchId;
  final String type;
  final String? side;
  final int points;
  final String? outcome;
  final int? matchClockPositionSeconds;
  final DateTime occurredAt;
  final String? note;
  final String? customLabel;
  final bool isDeleted;
  const MatchEventRow({
    required this.id,
    required this.matchId,
    required this.type,
    this.side,
    required this.points,
    this.outcome,
    this.matchClockPositionSeconds,
    required this.occurredAt,
    this.note,
    this.customLabel,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || side != null) {
      map['side'] = Variable<String>(side);
    }
    map['points'] = Variable<int>(points);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || matchClockPositionSeconds != null) {
      map['match_clock_position_seconds'] = Variable<int>(
        matchClockPositionSeconds,
      );
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || customLabel != null) {
      map['custom_label'] = Variable<String>(customLabel);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  MatchEventsCompanion toCompanion(bool nullToAbsent) {
    return MatchEventsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      type: Value(type),
      side: side == null && nullToAbsent ? const Value.absent() : Value(side),
      points: Value(points),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      matchClockPositionSeconds:
          matchClockPositionSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(matchClockPositionSeconds),
      occurredAt: Value(occurredAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      customLabel: customLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(customLabel),
      isDeleted: Value(isDeleted),
    );
  }

  factory MatchEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchEventRow(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      type: serializer.fromJson<String>(json['type']),
      side: serializer.fromJson<String?>(json['side']),
      points: serializer.fromJson<int>(json['points']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      matchClockPositionSeconds: serializer.fromJson<int?>(
        json['matchClockPositionSeconds'],
      ),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      note: serializer.fromJson<String?>(json['note']),
      customLabel: serializer.fromJson<String?>(json['customLabel']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'type': serializer.toJson<String>(type),
      'side': serializer.toJson<String?>(side),
      'points': serializer.toJson<int>(points),
      'outcome': serializer.toJson<String?>(outcome),
      'matchClockPositionSeconds': serializer.toJson<int?>(
        matchClockPositionSeconds,
      ),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'note': serializer.toJson<String?>(note),
      'customLabel': serializer.toJson<String?>(customLabel),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  MatchEventRow copyWith({
    String? id,
    String? matchId,
    String? type,
    Value<String?> side = const Value.absent(),
    int? points,
    Value<String?> outcome = const Value.absent(),
    Value<int?> matchClockPositionSeconds = const Value.absent(),
    DateTime? occurredAt,
    Value<String?> note = const Value.absent(),
    Value<String?> customLabel = const Value.absent(),
    bool? isDeleted,
  }) => MatchEventRow(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    type: type ?? this.type,
    side: side.present ? side.value : this.side,
    points: points ?? this.points,
    outcome: outcome.present ? outcome.value : this.outcome,
    matchClockPositionSeconds: matchClockPositionSeconds.present
        ? matchClockPositionSeconds.value
        : this.matchClockPositionSeconds,
    occurredAt: occurredAt ?? this.occurredAt,
    note: note.present ? note.value : this.note,
    customLabel: customLabel.present ? customLabel.value : this.customLabel,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  MatchEventRow copyWithCompanion(MatchEventsCompanion data) {
    return MatchEventRow(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      type: data.type.present ? data.type.value : this.type,
      side: data.side.present ? data.side.value : this.side,
      points: data.points.present ? data.points.value : this.points,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      matchClockPositionSeconds: data.matchClockPositionSeconds.present
          ? data.matchClockPositionSeconds.value
          : this.matchClockPositionSeconds,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      note: data.note.present ? data.note.value : this.note,
      customLabel: data.customLabel.present
          ? data.customLabel.value
          : this.customLabel,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventRow(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('type: $type, ')
          ..write('side: $side, ')
          ..write('points: $points, ')
          ..write('outcome: $outcome, ')
          ..write('matchClockPositionSeconds: $matchClockPositionSeconds, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('customLabel: $customLabel, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    type,
    side,
    points,
    outcome,
    matchClockPositionSeconds,
    occurredAt,
    note,
    customLabel,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchEventRow &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.type == this.type &&
          other.side == this.side &&
          other.points == this.points &&
          other.outcome == this.outcome &&
          other.matchClockPositionSeconds == this.matchClockPositionSeconds &&
          other.occurredAt == this.occurredAt &&
          other.note == this.note &&
          other.customLabel == this.customLabel &&
          other.isDeleted == this.isDeleted);
}

class MatchEventsCompanion extends UpdateCompanion<MatchEventRow> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> type;
  final Value<String?> side;
  final Value<int> points;
  final Value<String?> outcome;
  final Value<int?> matchClockPositionSeconds;
  final Value<DateTime> occurredAt;
  final Value<String?> note;
  final Value<String?> customLabel;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const MatchEventsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.type = const Value.absent(),
    this.side = const Value.absent(),
    this.points = const Value.absent(),
    this.outcome = const Value.absent(),
    this.matchClockPositionSeconds = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.customLabel = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchEventsCompanion.insert({
    required String id,
    required String matchId,
    required String type,
    this.side = const Value.absent(),
    this.points = const Value.absent(),
    this.outcome = const Value.absent(),
    this.matchClockPositionSeconds = const Value.absent(),
    required DateTime occurredAt,
    this.note = const Value.absent(),
    this.customLabel = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       type = Value(type),
       occurredAt = Value(occurredAt);
  static Insertable<MatchEventRow> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? type,
    Expression<String>? side,
    Expression<int>? points,
    Expression<String>? outcome,
    Expression<int>? matchClockPositionSeconds,
    Expression<DateTime>? occurredAt,
    Expression<String>? note,
    Expression<String>? customLabel,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (type != null) 'type': type,
      if (side != null) 'side': side,
      if (points != null) 'points': points,
      if (outcome != null) 'outcome': outcome,
      if (matchClockPositionSeconds != null)
        'match_clock_position_seconds': matchClockPositionSeconds,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (note != null) 'note': note,
      if (customLabel != null) 'custom_label': customLabel,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? type,
    Value<String?>? side,
    Value<int>? points,
    Value<String?>? outcome,
    Value<int?>? matchClockPositionSeconds,
    Value<DateTime>? occurredAt,
    Value<String?>? note,
    Value<String?>? customLabel,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return MatchEventsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      type: type ?? this.type,
      side: side ?? this.side,
      points: points ?? this.points,
      outcome: outcome ?? this.outcome,
      matchClockPositionSeconds:
          matchClockPositionSeconds ?? this.matchClockPositionSeconds,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      customLabel: customLabel ?? this.customLabel,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (matchClockPositionSeconds.present) {
      map['match_clock_position_seconds'] = Variable<int>(
        matchClockPositionSeconds.value,
      );
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (customLabel.present) {
      map['custom_label'] = Variable<String>(customLabel.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('type: $type, ')
          ..write('side: $side, ')
          ..write('points: $points, ')
          ..write('outcome: $outcome, ')
          ..write('matchClockPositionSeconds: $matchClockPositionSeconds, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('customLabel: $customLabel, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShotLocationsTable extends ShotLocations
    with TableInfo<$ShotLocationsTable, ShotLocation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotLocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isConfirmedMeta = const VerificationMeta(
    'isConfirmed',
  );
  @override
  late final GeneratedColumn<bool> isConfirmed = GeneratedColumn<bool>(
    'is_confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_confirmed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    eventId,
    x,
    y,
    isConfirmed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotLocation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('is_confirmed')) {
      context.handle(
        _isConfirmedMeta,
        isConfirmed.isAcceptableOrUnknown(
          data['is_confirmed']!,
          _isConfirmedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotLocation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotLocation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      isConfirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_confirmed'],
      )!,
    );
  }

  @override
  $ShotLocationsTable createAlias(String alias) {
    return $ShotLocationsTable(attachedDatabase, alias);
  }
}

class ShotLocation extends DataClass implements Insertable<ShotLocation> {
  final String id;
  final String matchId;
  final String eventId;
  final double x;
  final double y;
  final bool isConfirmed;
  const ShotLocation({
    required this.id,
    required this.matchId,
    required this.eventId,
    required this.x,
    required this.y,
    required this.isConfirmed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['event_id'] = Variable<String>(eventId);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['is_confirmed'] = Variable<bool>(isConfirmed);
    return map;
  }

  ShotLocationsCompanion toCompanion(bool nullToAbsent) {
    return ShotLocationsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      eventId: Value(eventId),
      x: Value(x),
      y: Value(y),
      isConfirmed: Value(isConfirmed),
    );
  }

  factory ShotLocation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotLocation(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      isConfirmed: serializer.fromJson<bool>(json['isConfirmed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'eventId': serializer.toJson<String>(eventId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'isConfirmed': serializer.toJson<bool>(isConfirmed),
    };
  }

  ShotLocation copyWith({
    String? id,
    String? matchId,
    String? eventId,
    double? x,
    double? y,
    bool? isConfirmed,
  }) => ShotLocation(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    eventId: eventId ?? this.eventId,
    x: x ?? this.x,
    y: y ?? this.y,
    isConfirmed: isConfirmed ?? this.isConfirmed,
  );
  ShotLocation copyWithCompanion(ShotLocationsCompanion data) {
    return ShotLocation(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      isConfirmed: data.isConfirmed.present
          ? data.isConfirmed.value
          : this.isConfirmed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotLocation(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('eventId: $eventId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('isConfirmed: $isConfirmed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, eventId, x, y, isConfirmed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotLocation &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.eventId == this.eventId &&
          other.x == this.x &&
          other.y == this.y &&
          other.isConfirmed == this.isConfirmed);
}

class ShotLocationsCompanion extends UpdateCompanion<ShotLocation> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> eventId;
  final Value<double> x;
  final Value<double> y;
  final Value<bool> isConfirmed;
  final Value<int> rowid;
  const ShotLocationsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.isConfirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShotLocationsCompanion.insert({
    required String id,
    required String matchId,
    required String eventId,
    required double x,
    required double y,
    this.isConfirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       eventId = Value(eventId),
       x = Value(x),
       y = Value(y);
  static Insertable<ShotLocation> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? eventId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<bool>? isConfirmed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (eventId != null) 'event_id': eventId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (isConfirmed != null) 'is_confirmed': isConfirmed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShotLocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? eventId,
    Value<double>? x,
    Value<double>? y,
    Value<bool>? isConfirmed,
    Value<int>? rowid,
  }) {
    return ShotLocationsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      eventId: eventId ?? this.eventId,
      x: x ?? this.x,
      y: y ?? this.y,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (isConfirmed.present) {
      map['is_confirmed'] = Variable<bool>(isConfirmed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotLocationsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('eventId: $eventId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('isConfirmed: $isConfirmed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleTemplatesTable extends RuleTemplates
    with TableInfo<$RuleTemplatesTable, RuleTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreButtonsJsonMeta = const VerificationMeta(
    'scoreButtonsJson',
  );
  @override
  late final GeneratedColumn<String> scoreButtonsJson = GeneratedColumn<String>(
    'score_buttons_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetScoreMeta = const VerificationMeta(
    'targetScore',
  );
  @override
  late final GeneratedColumn<int> targetScore = GeneratedColumn<int>(
    'target_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeLimitSecondsMeta = const VerificationMeta(
    'timeLimitSeconds',
  );
  @override
  late final GeneratedColumn<int> timeLimitSeconds = GeneratedColumn<int>(
    'time_limit_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _winByTwoMeta = const VerificationMeta(
    'winByTwo',
  );
  @override
  late final GeneratedColumn<bool> winByTwo = GeneratedColumn<bool>(
    'win_by_two',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("win_by_two" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _foulLimitMeta = const VerificationMeta(
    'foulLimit',
  );
  @override
  late final GeneratedColumn<int> foulLimit = GeneratedColumn<int>(
    'foul_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customEventTypesJsonMeta =
      const VerificationMeta('customEventTypesJson');
  @override
  late final GeneratedColumn<String> customEventTypesJson =
      GeneratedColumn<String>(
        'custom_event_types_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    scoreButtonsJson,
    targetScore,
    timeLimitSeconds,
    winByTwo,
    foulLimit,
    customEventTypesJson,
    isBuiltIn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('score_buttons_json')) {
      context.handle(
        _scoreButtonsJsonMeta,
        scoreButtonsJson.isAcceptableOrUnknown(
          data['score_buttons_json']!,
          _scoreButtonsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scoreButtonsJsonMeta);
    }
    if (data.containsKey('target_score')) {
      context.handle(
        _targetScoreMeta,
        targetScore.isAcceptableOrUnknown(
          data['target_score']!,
          _targetScoreMeta,
        ),
      );
    }
    if (data.containsKey('time_limit_seconds')) {
      context.handle(
        _timeLimitSecondsMeta,
        timeLimitSeconds.isAcceptableOrUnknown(
          data['time_limit_seconds']!,
          _timeLimitSecondsMeta,
        ),
      );
    }
    if (data.containsKey('win_by_two')) {
      context.handle(
        _winByTwoMeta,
        winByTwo.isAcceptableOrUnknown(data['win_by_two']!, _winByTwoMeta),
      );
    }
    if (data.containsKey('foul_limit')) {
      context.handle(
        _foulLimitMeta,
        foulLimit.isAcceptableOrUnknown(data['foul_limit']!, _foulLimitMeta),
      );
    }
    if (data.containsKey('custom_event_types_json')) {
      context.handle(
        _customEventTypesJsonMeta,
        customEventTypesJson.isAcceptableOrUnknown(
          data['custom_event_types_json']!,
          _customEventTypesJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      scoreButtonsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_buttons_json'],
      )!,
      targetScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_score'],
      ),
      timeLimitSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_limit_seconds'],
      ),
      winByTwo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}win_by_two'],
      )!,
      foulLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}foul_limit'],
      ),
      customEventTypesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_event_types_json'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
    );
  }

  @override
  $RuleTemplatesTable createAlias(String alias) {
    return $RuleTemplatesTable(attachedDatabase, alias);
  }
}

class RuleTemplateRow extends DataClass implements Insertable<RuleTemplateRow> {
  final String id;
  final String name;
  final String scoreButtonsJson;
  final int? targetScore;
  final int? timeLimitSeconds;
  final bool winByTwo;
  final int? foulLimit;
  final String customEventTypesJson;
  final bool isBuiltIn;
  const RuleTemplateRow({
    required this.id,
    required this.name,
    required this.scoreButtonsJson,
    this.targetScore,
    this.timeLimitSeconds,
    required this.winByTwo,
    this.foulLimit,
    required this.customEventTypesJson,
    required this.isBuiltIn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['score_buttons_json'] = Variable<String>(scoreButtonsJson);
    if (!nullToAbsent || targetScore != null) {
      map['target_score'] = Variable<int>(targetScore);
    }
    if (!nullToAbsent || timeLimitSeconds != null) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds);
    }
    map['win_by_two'] = Variable<bool>(winByTwo);
    if (!nullToAbsent || foulLimit != null) {
      map['foul_limit'] = Variable<int>(foulLimit);
    }
    map['custom_event_types_json'] = Variable<String>(customEventTypesJson);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    return map;
  }

  RuleTemplatesCompanion toCompanion(bool nullToAbsent) {
    return RuleTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      scoreButtonsJson: Value(scoreButtonsJson),
      targetScore: targetScore == null && nullToAbsent
          ? const Value.absent()
          : Value(targetScore),
      timeLimitSeconds: timeLimitSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(timeLimitSeconds),
      winByTwo: Value(winByTwo),
      foulLimit: foulLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(foulLimit),
      customEventTypesJson: Value(customEventTypesJson),
      isBuiltIn: Value(isBuiltIn),
    );
  }

  factory RuleTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleTemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      scoreButtonsJson: serializer.fromJson<String>(json['scoreButtonsJson']),
      targetScore: serializer.fromJson<int?>(json['targetScore']),
      timeLimitSeconds: serializer.fromJson<int?>(json['timeLimitSeconds']),
      winByTwo: serializer.fromJson<bool>(json['winByTwo']),
      foulLimit: serializer.fromJson<int?>(json['foulLimit']),
      customEventTypesJson: serializer.fromJson<String>(
        json['customEventTypesJson'],
      ),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'scoreButtonsJson': serializer.toJson<String>(scoreButtonsJson),
      'targetScore': serializer.toJson<int?>(targetScore),
      'timeLimitSeconds': serializer.toJson<int?>(timeLimitSeconds),
      'winByTwo': serializer.toJson<bool>(winByTwo),
      'foulLimit': serializer.toJson<int?>(foulLimit),
      'customEventTypesJson': serializer.toJson<String>(customEventTypesJson),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
    };
  }

  RuleTemplateRow copyWith({
    String? id,
    String? name,
    String? scoreButtonsJson,
    Value<int?> targetScore = const Value.absent(),
    Value<int?> timeLimitSeconds = const Value.absent(),
    bool? winByTwo,
    Value<int?> foulLimit = const Value.absent(),
    String? customEventTypesJson,
    bool? isBuiltIn,
  }) => RuleTemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    scoreButtonsJson: scoreButtonsJson ?? this.scoreButtonsJson,
    targetScore: targetScore.present ? targetScore.value : this.targetScore,
    timeLimitSeconds: timeLimitSeconds.present
        ? timeLimitSeconds.value
        : this.timeLimitSeconds,
    winByTwo: winByTwo ?? this.winByTwo,
    foulLimit: foulLimit.present ? foulLimit.value : this.foulLimit,
    customEventTypesJson: customEventTypesJson ?? this.customEventTypesJson,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
  );
  RuleTemplateRow copyWithCompanion(RuleTemplatesCompanion data) {
    return RuleTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      scoreButtonsJson: data.scoreButtonsJson.present
          ? data.scoreButtonsJson.value
          : this.scoreButtonsJson,
      targetScore: data.targetScore.present
          ? data.targetScore.value
          : this.targetScore,
      timeLimitSeconds: data.timeLimitSeconds.present
          ? data.timeLimitSeconds.value
          : this.timeLimitSeconds,
      winByTwo: data.winByTwo.present ? data.winByTwo.value : this.winByTwo,
      foulLimit: data.foulLimit.present ? data.foulLimit.value : this.foulLimit,
      customEventTypesJson: data.customEventTypesJson.present
          ? data.customEventTypesJson.value
          : this.customEventTypesJson,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleTemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scoreButtonsJson: $scoreButtonsJson, ')
          ..write('targetScore: $targetScore, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('winByTwo: $winByTwo, ')
          ..write('foulLimit: $foulLimit, ')
          ..write('customEventTypesJson: $customEventTypesJson, ')
          ..write('isBuiltIn: $isBuiltIn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    scoreButtonsJson,
    targetScore,
    timeLimitSeconds,
    winByTwo,
    foulLimit,
    customEventTypesJson,
    isBuiltIn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleTemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.scoreButtonsJson == this.scoreButtonsJson &&
          other.targetScore == this.targetScore &&
          other.timeLimitSeconds == this.timeLimitSeconds &&
          other.winByTwo == this.winByTwo &&
          other.foulLimit == this.foulLimit &&
          other.customEventTypesJson == this.customEventTypesJson &&
          other.isBuiltIn == this.isBuiltIn);
}

class RuleTemplatesCompanion extends UpdateCompanion<RuleTemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> scoreButtonsJson;
  final Value<int?> targetScore;
  final Value<int?> timeLimitSeconds;
  final Value<bool> winByTwo;
  final Value<int?> foulLimit;
  final Value<String> customEventTypesJson;
  final Value<bool> isBuiltIn;
  final Value<int> rowid;
  const RuleTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.scoreButtonsJson = const Value.absent(),
    this.targetScore = const Value.absent(),
    this.timeLimitSeconds = const Value.absent(),
    this.winByTwo = const Value.absent(),
    this.foulLimit = const Value.absent(),
    this.customEventTypesJson = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleTemplatesCompanion.insert({
    required String id,
    required String name,
    required String scoreButtonsJson,
    this.targetScore = const Value.absent(),
    this.timeLimitSeconds = const Value.absent(),
    this.winByTwo = const Value.absent(),
    this.foulLimit = const Value.absent(),
    this.customEventTypesJson = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       scoreButtonsJson = Value(scoreButtonsJson);
  static Insertable<RuleTemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? scoreButtonsJson,
    Expression<int>? targetScore,
    Expression<int>? timeLimitSeconds,
    Expression<bool>? winByTwo,
    Expression<int>? foulLimit,
    Expression<String>? customEventTypesJson,
    Expression<bool>? isBuiltIn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (scoreButtonsJson != null) 'score_buttons_json': scoreButtonsJson,
      if (targetScore != null) 'target_score': targetScore,
      if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
      if (winByTwo != null) 'win_by_two': winByTwo,
      if (foulLimit != null) 'foul_limit': foulLimit,
      if (customEventTypesJson != null)
        'custom_event_types_json': customEventTypesJson,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? scoreButtonsJson,
    Value<int?>? targetScore,
    Value<int?>? timeLimitSeconds,
    Value<bool>? winByTwo,
    Value<int?>? foulLimit,
    Value<String>? customEventTypesJson,
    Value<bool>? isBuiltIn,
    Value<int>? rowid,
  }) {
    return RuleTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      scoreButtonsJson: scoreButtonsJson ?? this.scoreButtonsJson,
      targetScore: targetScore ?? this.targetScore,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      winByTwo: winByTwo ?? this.winByTwo,
      foulLimit: foulLimit ?? this.foulLimit,
      customEventTypesJson: customEventTypesJson ?? this.customEventTypesJson,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (scoreButtonsJson.present) {
      map['score_buttons_json'] = Variable<String>(scoreButtonsJson.value);
    }
    if (targetScore.present) {
      map['target_score'] = Variable<int>(targetScore.value);
    }
    if (timeLimitSeconds.present) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds.value);
    }
    if (winByTwo.present) {
      map['win_by_two'] = Variable<bool>(winByTwo.value);
    }
    if (foulLimit.present) {
      map['foul_limit'] = Variable<int>(foulLimit.value);
    }
    if (customEventTypesJson.present) {
      map['custom_event_types_json'] = Variable<String>(
        customEventTypesJson.value,
      );
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scoreButtonsJson: $scoreButtonsJson, ')
          ..write('targetScore: $targetScore, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('winByTwo: $winByTwo, ')
          ..write('foulLimit: $foulLimit, ')
          ..write('customEventTypesJson: $customEventTypesJson, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PossessionSegmentsTable extends PossessionSegments
    with TableInfo<$PossessionSegmentsTable, PossessionSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PossessionSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtEventIdMeta = const VerificationMeta(
    'startedAtEventId',
  );
  @override
  late final GeneratedColumn<String> startedAtEventId = GeneratedColumn<String>(
    'started_at_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _endedAtEventIdMeta = const VerificationMeta(
    'endedAtEventId',
  );
  @override
  late final GeneratedColumn<String> endedAtEventId = GeneratedColumn<String>(
    'ended_at_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_events (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    side,
    startedAtEventId,
    endedAtEventId,
    reason,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'possession_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PossessionSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    } else if (isInserting) {
      context.missing(_sideMeta);
    }
    if (data.containsKey('started_at_event_id')) {
      context.handle(
        _startedAtEventIdMeta,
        startedAtEventId.isAcceptableOrUnknown(
          data['started_at_event_id']!,
          _startedAtEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtEventIdMeta);
    }
    if (data.containsKey('ended_at_event_id')) {
      context.handle(
        _endedAtEventIdMeta,
        endedAtEventId.isAcceptableOrUnknown(
          data['ended_at_event_id']!,
          _endedAtEventIdMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PossessionSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PossessionSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      )!,
      startedAtEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at_event_id'],
      )!,
      endedAtEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ended_at_event_id'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $PossessionSegmentsTable createAlias(String alias) {
    return $PossessionSegmentsTable(attachedDatabase, alias);
  }
}

class PossessionSegment extends DataClass
    implements Insertable<PossessionSegment> {
  final String id;
  final String matchId;
  final String side;
  final String startedAtEventId;
  final String? endedAtEventId;
  final String? reason;
  final String source;
  const PossessionSegment({
    required this.id,
    required this.matchId,
    required this.side,
    required this.startedAtEventId,
    this.endedAtEventId,
    this.reason,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['side'] = Variable<String>(side);
    map['started_at_event_id'] = Variable<String>(startedAtEventId);
    if (!nullToAbsent || endedAtEventId != null) {
      map['ended_at_event_id'] = Variable<String>(endedAtEventId);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  PossessionSegmentsCompanion toCompanion(bool nullToAbsent) {
    return PossessionSegmentsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      side: Value(side),
      startedAtEventId: Value(startedAtEventId),
      endedAtEventId: endedAtEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtEventId),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      source: Value(source),
    );
  }

  factory PossessionSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PossessionSegment(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      side: serializer.fromJson<String>(json['side']),
      startedAtEventId: serializer.fromJson<String>(json['startedAtEventId']),
      endedAtEventId: serializer.fromJson<String?>(json['endedAtEventId']),
      reason: serializer.fromJson<String?>(json['reason']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'side': serializer.toJson<String>(side),
      'startedAtEventId': serializer.toJson<String>(startedAtEventId),
      'endedAtEventId': serializer.toJson<String?>(endedAtEventId),
      'reason': serializer.toJson<String?>(reason),
      'source': serializer.toJson<String>(source),
    };
  }

  PossessionSegment copyWith({
    String? id,
    String? matchId,
    String? side,
    String? startedAtEventId,
    Value<String?> endedAtEventId = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    String? source,
  }) => PossessionSegment(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    side: side ?? this.side,
    startedAtEventId: startedAtEventId ?? this.startedAtEventId,
    endedAtEventId: endedAtEventId.present
        ? endedAtEventId.value
        : this.endedAtEventId,
    reason: reason.present ? reason.value : this.reason,
    source: source ?? this.source,
  );
  PossessionSegment copyWithCompanion(PossessionSegmentsCompanion data) {
    return PossessionSegment(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      side: data.side.present ? data.side.value : this.side,
      startedAtEventId: data.startedAtEventId.present
          ? data.startedAtEventId.value
          : this.startedAtEventId,
      endedAtEventId: data.endedAtEventId.present
          ? data.endedAtEventId.value
          : this.endedAtEventId,
      reason: data.reason.present ? data.reason.value : this.reason,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PossessionSegment(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('side: $side, ')
          ..write('startedAtEventId: $startedAtEventId, ')
          ..write('endedAtEventId: $endedAtEventId, ')
          ..write('reason: $reason, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    side,
    startedAtEventId,
    endedAtEventId,
    reason,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PossessionSegment &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.side == this.side &&
          other.startedAtEventId == this.startedAtEventId &&
          other.endedAtEventId == this.endedAtEventId &&
          other.reason == this.reason &&
          other.source == this.source);
}

class PossessionSegmentsCompanion extends UpdateCompanion<PossessionSegment> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> side;
  final Value<String> startedAtEventId;
  final Value<String?> endedAtEventId;
  final Value<String?> reason;
  final Value<String> source;
  final Value<int> rowid;
  const PossessionSegmentsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.side = const Value.absent(),
    this.startedAtEventId = const Value.absent(),
    this.endedAtEventId = const Value.absent(),
    this.reason = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PossessionSegmentsCompanion.insert({
    required String id,
    required String matchId,
    required String side,
    required String startedAtEventId,
    this.endedAtEventId = const Value.absent(),
    this.reason = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       side = Value(side),
       startedAtEventId = Value(startedAtEventId);
  static Insertable<PossessionSegment> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? side,
    Expression<String>? startedAtEventId,
    Expression<String>? endedAtEventId,
    Expression<String>? reason,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (side != null) 'side': side,
      if (startedAtEventId != null) 'started_at_event_id': startedAtEventId,
      if (endedAtEventId != null) 'ended_at_event_id': endedAtEventId,
      if (reason != null) 'reason': reason,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PossessionSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? side,
    Value<String>? startedAtEventId,
    Value<String?>? endedAtEventId,
    Value<String?>? reason,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return PossessionSegmentsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      side: side ?? this.side,
      startedAtEventId: startedAtEventId ?? this.startedAtEventId,
      endedAtEventId: endedAtEventId ?? this.endedAtEventId,
      reason: reason ?? this.reason,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (startedAtEventId.present) {
      map['started_at_event_id'] = Variable<String>(startedAtEventId.value);
    }
    if (endedAtEventId.present) {
      map['ended_at_event_id'] = Variable<String>(endedAtEventId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PossessionSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('side: $side, ')
          ..write('startedAtEventId: $startedAtEventId, ')
          ..write('endedAtEventId: $endedAtEventId, ')
          ..write('reason: $reason, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterJsonMeta = const VerificationMeta(
    'afterJson',
  );
  @override
  late final GeneratedColumn<String> afterJson = GeneratedColumn<String>(
    'after_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    targetId,
    action,
    beforeJson,
    afterJson,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_beforeJsonMeta);
    }
    if (data.containsKey('after_json')) {
      context.handle(
        _afterJsonMeta,
        afterJson.isAcceptableOrUnknown(data['after_json']!, _afterJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_afterJsonMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      )!,
      afterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_json'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final String id;
  final String matchId;
  final String targetId;
  final String action;
  final String beforeJson;
  final String afterJson;
  final String? reason;
  final DateTime createdAt;
  const AuditLog({
    required this.id,
    required this.matchId,
    required this.targetId,
    required this.action,
    required this.beforeJson,
    required this.afterJson,
    this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['target_id'] = Variable<String>(targetId);
    map['action'] = Variable<String>(action);
    map['before_json'] = Variable<String>(beforeJson);
    map['after_json'] = Variable<String>(afterJson);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      targetId: Value(targetId),
      action: Value(action),
      beforeJson: Value(beforeJson),
      afterJson: Value(afterJson),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      action: serializer.fromJson<String>(json['action']),
      beforeJson: serializer.fromJson<String>(json['beforeJson']),
      afterJson: serializer.fromJson<String>(json['afterJson']),
      reason: serializer.fromJson<String?>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'targetId': serializer.toJson<String>(targetId),
      'action': serializer.toJson<String>(action),
      'beforeJson': serializer.toJson<String>(beforeJson),
      'afterJson': serializer.toJson<String>(afterJson),
      'reason': serializer.toJson<String?>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AuditLog copyWith({
    String? id,
    String? matchId,
    String? targetId,
    String? action,
    String? beforeJson,
    String? afterJson,
    Value<String?> reason = const Value.absent(),
    DateTime? createdAt,
  }) => AuditLog(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    targetId: targetId ?? this.targetId,
    action: action ?? this.action,
    beforeJson: beforeJson ?? this.beforeJson,
    afterJson: afterJson ?? this.afterJson,
    reason: reason.present ? reason.value : this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      action: data.action.present ? data.action.value : this.action,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
      afterJson: data.afterJson.present ? data.afterJson.value : this.afterJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('targetId: $targetId, ')
          ..write('action: $action, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    targetId,
    action,
    beforeJson,
    afterJson,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.targetId == this.targetId &&
          other.action == this.action &&
          other.beforeJson == this.beforeJson &&
          other.afterJson == this.afterJson &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> targetId;
  final Value<String> action;
  final Value<String> beforeJson;
  final Value<String> afterJson;
  final Value<String?> reason;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.action = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    required String id,
    required String matchId,
    required String targetId,
    required String action,
    required String beforeJson,
    required String afterJson,
    this.reason = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       targetId = Value(targetId),
       action = Value(action),
       beforeJson = Value(beforeJson),
       afterJson = Value(afterJson),
       createdAt = Value(createdAt);
  static Insertable<AuditLog> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? targetId,
    Expression<String>? action,
    Expression<String>? beforeJson,
    Expression<String>? afterJson,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (targetId != null) 'target_id': targetId,
      if (action != null) 'action': action,
      if (beforeJson != null) 'before_json': beforeJson,
      if (afterJson != null) 'after_json': afterJson,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? targetId,
    Value<String>? action,
    Value<String>? beforeJson,
    Value<String>? afterJson,
    Value<String?>? reason,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      targetId: targetId ?? this.targetId,
      action: action ?? this.action,
      beforeJson: beforeJson ?? this.beforeJson,
      afterJson: afterJson ?? this.afterJson,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (afterJson.present) {
      map['after_json'] = Variable<String>(afterJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('targetId: $targetId, ')
          ..write('action: $action, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? valueJson, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayerAnalyticsSnapshotsTable extends PlayerAnalyticsSnapshots
    with TableInfo<$PlayerAnalyticsSnapshotsTable, PlayerAnalyticsSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerAnalyticsSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _opponentPlayerIdMeta = const VerificationMeta(
    'opponentPlayerId',
  );
  @override
  late final GeneratedColumn<String> opponentPlayerId = GeneratedColumn<String>(
    'opponent_player_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _playedAtUtcMeta = const VerificationMeta(
    'playedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> playedAtUtc = GeneratedColumn<DateTime>(
    'played_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerScoreMeta = const VerificationMeta(
    'playerScore',
  );
  @override
  late final GeneratedColumn<int> playerScore = GeneratedColumn<int>(
    'player_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opponentScoreMeta = const VerificationMeta(
    'opponentScore',
  );
  @override
  late final GeneratedColumn<int> opponentScore = GeneratedColumn<int>(
    'opponent_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldGoalMadeMeta = const VerificationMeta(
    'fieldGoalMade',
  );
  @override
  late final GeneratedColumn<int> fieldGoalMade = GeneratedColumn<int>(
    'field_goal_made',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldGoalAttemptsMeta = const VerificationMeta(
    'fieldGoalAttempts',
  );
  @override
  late final GeneratedColumn<int> fieldGoalAttempts = GeneratedColumn<int>(
    'field_goal_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freeThrowMadeMeta = const VerificationMeta(
    'freeThrowMade',
  );
  @override
  late final GeneratedColumn<int> freeThrowMade = GeneratedColumn<int>(
    'free_throw_made',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freeThrowAttemptsMeta = const VerificationMeta(
    'freeThrowAttempts',
  );
  @override
  late final GeneratedColumn<int> freeThrowAttempts = GeneratedColumn<int>(
    'free_throw_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackingCoverageMeta = const VerificationMeta(
    'trackingCoverage',
  );
  @override
  late final GeneratedColumn<String> trackingCoverage = GeneratedColumn<String>(
    'tracking_coverage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedLocationCountMeta =
      const VerificationMeta('confirmedLocationCount');
  @override
  late final GeneratedColumn<int> confirmedLocationCount = GeneratedColumn<int>(
    'confirmed_location_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatableLocationCountMeta =
      const VerificationMeta('locatableLocationCount');
  @override
  late final GeneratedColumn<int> locatableLocationCount = GeneratedColumn<int>(
    'locatable_location_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zoneDistributionJsonMeta =
      const VerificationMeta('zoneDistributionJson');
  @override
  late final GeneratedColumn<String> zoneDistributionJson =
      GeneratedColumn<String>(
        'zone_distribution_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _calculatorVersionMeta = const VerificationMeta(
    'calculatorVersion',
  );
  @override
  late final GeneratedColumn<int> calculatorVersion = GeneratedColumn<int>(
    'calculator_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSha256Meta = const VerificationMeta(
    'sourceSha256',
  );
  @override
  late final GeneratedColumn<String> sourceSha256 = GeneratedColumn<String>(
    'source_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    matchId,
    playerId,
    opponentPlayerId,
    playedAtUtc,
    playerScore,
    opponentScore,
    fieldGoalMade,
    fieldGoalAttempts,
    freeThrowMade,
    freeThrowAttempts,
    trackingCoverage,
    confirmedLocationCount,
    locatableLocationCount,
    zoneDistributionJson,
    calculatorVersion,
    sourceSha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_analytics_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerAnalyticsSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('opponent_player_id')) {
      context.handle(
        _opponentPlayerIdMeta,
        opponentPlayerId.isAcceptableOrUnknown(
          data['opponent_player_id']!,
          _opponentPlayerIdMeta,
        ),
      );
    }
    if (data.containsKey('played_at_utc')) {
      context.handle(
        _playedAtUtcMeta,
        playedAtUtc.isAcceptableOrUnknown(
          data['played_at_utc']!,
          _playedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playedAtUtcMeta);
    }
    if (data.containsKey('player_score')) {
      context.handle(
        _playerScoreMeta,
        playerScore.isAcceptableOrUnknown(
          data['player_score']!,
          _playerScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playerScoreMeta);
    }
    if (data.containsKey('opponent_score')) {
      context.handle(
        _opponentScoreMeta,
        opponentScore.isAcceptableOrUnknown(
          data['opponent_score']!,
          _opponentScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_opponentScoreMeta);
    }
    if (data.containsKey('field_goal_made')) {
      context.handle(
        _fieldGoalMadeMeta,
        fieldGoalMade.isAcceptableOrUnknown(
          data['field_goal_made']!,
          _fieldGoalMadeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fieldGoalMadeMeta);
    }
    if (data.containsKey('field_goal_attempts')) {
      context.handle(
        _fieldGoalAttemptsMeta,
        fieldGoalAttempts.isAcceptableOrUnknown(
          data['field_goal_attempts']!,
          _fieldGoalAttemptsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fieldGoalAttemptsMeta);
    }
    if (data.containsKey('free_throw_made')) {
      context.handle(
        _freeThrowMadeMeta,
        freeThrowMade.isAcceptableOrUnknown(
          data['free_throw_made']!,
          _freeThrowMadeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_freeThrowMadeMeta);
    }
    if (data.containsKey('free_throw_attempts')) {
      context.handle(
        _freeThrowAttemptsMeta,
        freeThrowAttempts.isAcceptableOrUnknown(
          data['free_throw_attempts']!,
          _freeThrowAttemptsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_freeThrowAttemptsMeta);
    }
    if (data.containsKey('tracking_coverage')) {
      context.handle(
        _trackingCoverageMeta,
        trackingCoverage.isAcceptableOrUnknown(
          data['tracking_coverage']!,
          _trackingCoverageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackingCoverageMeta);
    }
    if (data.containsKey('confirmed_location_count')) {
      context.handle(
        _confirmedLocationCountMeta,
        confirmedLocationCount.isAcceptableOrUnknown(
          data['confirmed_location_count']!,
          _confirmedLocationCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmedLocationCountMeta);
    }
    if (data.containsKey('locatable_location_count')) {
      context.handle(
        _locatableLocationCountMeta,
        locatableLocationCount.isAcceptableOrUnknown(
          data['locatable_location_count']!,
          _locatableLocationCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locatableLocationCountMeta);
    }
    if (data.containsKey('zone_distribution_json')) {
      context.handle(
        _zoneDistributionJsonMeta,
        zoneDistributionJson.isAcceptableOrUnknown(
          data['zone_distribution_json']!,
          _zoneDistributionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_zoneDistributionJsonMeta);
    }
    if (data.containsKey('calculator_version')) {
      context.handle(
        _calculatorVersionMeta,
        calculatorVersion.isAcceptableOrUnknown(
          data['calculator_version']!,
          _calculatorVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calculatorVersionMeta);
    }
    if (data.containsKey('source_sha256')) {
      context.handle(
        _sourceSha256Meta,
        sourceSha256.isAcceptableOrUnknown(
          data['source_sha256']!,
          _sourceSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId, playerId};
  @override
  PlayerAnalyticsSnapshotRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerAnalyticsSnapshotRow(
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      opponentPlayerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_player_id'],
      ),
      playedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at_utc'],
      )!,
      playerScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_score'],
      )!,
      opponentScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opponent_score'],
      )!,
      fieldGoalMade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}field_goal_made'],
      )!,
      fieldGoalAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}field_goal_attempts'],
      )!,
      freeThrowMade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_throw_made'],
      )!,
      freeThrowAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_throw_attempts'],
      )!,
      trackingCoverage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tracking_coverage'],
      )!,
      confirmedLocationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed_location_count'],
      )!,
      locatableLocationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}locatable_location_count'],
      )!,
      zoneDistributionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_distribution_json'],
      )!,
      calculatorVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calculator_version'],
      )!,
      sourceSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sha256'],
      )!,
    );
  }

  @override
  $PlayerAnalyticsSnapshotsTable createAlias(String alias) {
    return $PlayerAnalyticsSnapshotsTable(attachedDatabase, alias);
  }
}

class PlayerAnalyticsSnapshotRow extends DataClass
    implements Insertable<PlayerAnalyticsSnapshotRow> {
  final String matchId;
  final String playerId;
  final String? opponentPlayerId;
  final DateTime playedAtUtc;
  final int playerScore;
  final int opponentScore;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final String trackingCoverage;
  final int confirmedLocationCount;
  final int locatableLocationCount;
  final String zoneDistributionJson;
  final int calculatorVersion;
  final String sourceSha256;
  const PlayerAnalyticsSnapshotRow({
    required this.matchId,
    required this.playerId,
    this.opponentPlayerId,
    required this.playedAtUtc,
    required this.playerScore,
    required this.opponentScore,
    required this.fieldGoalMade,
    required this.fieldGoalAttempts,
    required this.freeThrowMade,
    required this.freeThrowAttempts,
    required this.trackingCoverage,
    required this.confirmedLocationCount,
    required this.locatableLocationCount,
    required this.zoneDistributionJson,
    required this.calculatorVersion,
    required this.sourceSha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['player_id'] = Variable<String>(playerId);
    if (!nullToAbsent || opponentPlayerId != null) {
      map['opponent_player_id'] = Variable<String>(opponentPlayerId);
    }
    map['played_at_utc'] = Variable<DateTime>(playedAtUtc);
    map['player_score'] = Variable<int>(playerScore);
    map['opponent_score'] = Variable<int>(opponentScore);
    map['field_goal_made'] = Variable<int>(fieldGoalMade);
    map['field_goal_attempts'] = Variable<int>(fieldGoalAttempts);
    map['free_throw_made'] = Variable<int>(freeThrowMade);
    map['free_throw_attempts'] = Variable<int>(freeThrowAttempts);
    map['tracking_coverage'] = Variable<String>(trackingCoverage);
    map['confirmed_location_count'] = Variable<int>(confirmedLocationCount);
    map['locatable_location_count'] = Variable<int>(locatableLocationCount);
    map['zone_distribution_json'] = Variable<String>(zoneDistributionJson);
    map['calculator_version'] = Variable<int>(calculatorVersion);
    map['source_sha256'] = Variable<String>(sourceSha256);
    return map;
  }

  PlayerAnalyticsSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return PlayerAnalyticsSnapshotsCompanion(
      matchId: Value(matchId),
      playerId: Value(playerId),
      opponentPlayerId: opponentPlayerId == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentPlayerId),
      playedAtUtc: Value(playedAtUtc),
      playerScore: Value(playerScore),
      opponentScore: Value(opponentScore),
      fieldGoalMade: Value(fieldGoalMade),
      fieldGoalAttempts: Value(fieldGoalAttempts),
      freeThrowMade: Value(freeThrowMade),
      freeThrowAttempts: Value(freeThrowAttempts),
      trackingCoverage: Value(trackingCoverage),
      confirmedLocationCount: Value(confirmedLocationCount),
      locatableLocationCount: Value(locatableLocationCount),
      zoneDistributionJson: Value(zoneDistributionJson),
      calculatorVersion: Value(calculatorVersion),
      sourceSha256: Value(sourceSha256),
    );
  }

  factory PlayerAnalyticsSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerAnalyticsSnapshotRow(
      matchId: serializer.fromJson<String>(json['matchId']),
      playerId: serializer.fromJson<String>(json['playerId']),
      opponentPlayerId: serializer.fromJson<String?>(json['opponentPlayerId']),
      playedAtUtc: serializer.fromJson<DateTime>(json['playedAtUtc']),
      playerScore: serializer.fromJson<int>(json['playerScore']),
      opponentScore: serializer.fromJson<int>(json['opponentScore']),
      fieldGoalMade: serializer.fromJson<int>(json['fieldGoalMade']),
      fieldGoalAttempts: serializer.fromJson<int>(json['fieldGoalAttempts']),
      freeThrowMade: serializer.fromJson<int>(json['freeThrowMade']),
      freeThrowAttempts: serializer.fromJson<int>(json['freeThrowAttempts']),
      trackingCoverage: serializer.fromJson<String>(json['trackingCoverage']),
      confirmedLocationCount: serializer.fromJson<int>(
        json['confirmedLocationCount'],
      ),
      locatableLocationCount: serializer.fromJson<int>(
        json['locatableLocationCount'],
      ),
      zoneDistributionJson: serializer.fromJson<String>(
        json['zoneDistributionJson'],
      ),
      calculatorVersion: serializer.fromJson<int>(json['calculatorVersion']),
      sourceSha256: serializer.fromJson<String>(json['sourceSha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'matchId': serializer.toJson<String>(matchId),
      'playerId': serializer.toJson<String>(playerId),
      'opponentPlayerId': serializer.toJson<String?>(opponentPlayerId),
      'playedAtUtc': serializer.toJson<DateTime>(playedAtUtc),
      'playerScore': serializer.toJson<int>(playerScore),
      'opponentScore': serializer.toJson<int>(opponentScore),
      'fieldGoalMade': serializer.toJson<int>(fieldGoalMade),
      'fieldGoalAttempts': serializer.toJson<int>(fieldGoalAttempts),
      'freeThrowMade': serializer.toJson<int>(freeThrowMade),
      'freeThrowAttempts': serializer.toJson<int>(freeThrowAttempts),
      'trackingCoverage': serializer.toJson<String>(trackingCoverage),
      'confirmedLocationCount': serializer.toJson<int>(confirmedLocationCount),
      'locatableLocationCount': serializer.toJson<int>(locatableLocationCount),
      'zoneDistributionJson': serializer.toJson<String>(zoneDistributionJson),
      'calculatorVersion': serializer.toJson<int>(calculatorVersion),
      'sourceSha256': serializer.toJson<String>(sourceSha256),
    };
  }

  PlayerAnalyticsSnapshotRow copyWith({
    String? matchId,
    String? playerId,
    Value<String?> opponentPlayerId = const Value.absent(),
    DateTime? playedAtUtc,
    int? playerScore,
    int? opponentScore,
    int? fieldGoalMade,
    int? fieldGoalAttempts,
    int? freeThrowMade,
    int? freeThrowAttempts,
    String? trackingCoverage,
    int? confirmedLocationCount,
    int? locatableLocationCount,
    String? zoneDistributionJson,
    int? calculatorVersion,
    String? sourceSha256,
  }) => PlayerAnalyticsSnapshotRow(
    matchId: matchId ?? this.matchId,
    playerId: playerId ?? this.playerId,
    opponentPlayerId: opponentPlayerId.present
        ? opponentPlayerId.value
        : this.opponentPlayerId,
    playedAtUtc: playedAtUtc ?? this.playedAtUtc,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    fieldGoalMade: fieldGoalMade ?? this.fieldGoalMade,
    fieldGoalAttempts: fieldGoalAttempts ?? this.fieldGoalAttempts,
    freeThrowMade: freeThrowMade ?? this.freeThrowMade,
    freeThrowAttempts: freeThrowAttempts ?? this.freeThrowAttempts,
    trackingCoverage: trackingCoverage ?? this.trackingCoverage,
    confirmedLocationCount:
        confirmedLocationCount ?? this.confirmedLocationCount,
    locatableLocationCount:
        locatableLocationCount ?? this.locatableLocationCount,
    zoneDistributionJson: zoneDistributionJson ?? this.zoneDistributionJson,
    calculatorVersion: calculatorVersion ?? this.calculatorVersion,
    sourceSha256: sourceSha256 ?? this.sourceSha256,
  );
  PlayerAnalyticsSnapshotRow copyWithCompanion(
    PlayerAnalyticsSnapshotsCompanion data,
  ) {
    return PlayerAnalyticsSnapshotRow(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      opponentPlayerId: data.opponentPlayerId.present
          ? data.opponentPlayerId.value
          : this.opponentPlayerId,
      playedAtUtc: data.playedAtUtc.present
          ? data.playedAtUtc.value
          : this.playedAtUtc,
      playerScore: data.playerScore.present
          ? data.playerScore.value
          : this.playerScore,
      opponentScore: data.opponentScore.present
          ? data.opponentScore.value
          : this.opponentScore,
      fieldGoalMade: data.fieldGoalMade.present
          ? data.fieldGoalMade.value
          : this.fieldGoalMade,
      fieldGoalAttempts: data.fieldGoalAttempts.present
          ? data.fieldGoalAttempts.value
          : this.fieldGoalAttempts,
      freeThrowMade: data.freeThrowMade.present
          ? data.freeThrowMade.value
          : this.freeThrowMade,
      freeThrowAttempts: data.freeThrowAttempts.present
          ? data.freeThrowAttempts.value
          : this.freeThrowAttempts,
      trackingCoverage: data.trackingCoverage.present
          ? data.trackingCoverage.value
          : this.trackingCoverage,
      confirmedLocationCount: data.confirmedLocationCount.present
          ? data.confirmedLocationCount.value
          : this.confirmedLocationCount,
      locatableLocationCount: data.locatableLocationCount.present
          ? data.locatableLocationCount.value
          : this.locatableLocationCount,
      zoneDistributionJson: data.zoneDistributionJson.present
          ? data.zoneDistributionJson.value
          : this.zoneDistributionJson,
      calculatorVersion: data.calculatorVersion.present
          ? data.calculatorVersion.value
          : this.calculatorVersion,
      sourceSha256: data.sourceSha256.present
          ? data.sourceSha256.value
          : this.sourceSha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerAnalyticsSnapshotRow(')
          ..write('matchId: $matchId, ')
          ..write('playerId: $playerId, ')
          ..write('opponentPlayerId: $opponentPlayerId, ')
          ..write('playedAtUtc: $playedAtUtc, ')
          ..write('playerScore: $playerScore, ')
          ..write('opponentScore: $opponentScore, ')
          ..write('fieldGoalMade: $fieldGoalMade, ')
          ..write('fieldGoalAttempts: $fieldGoalAttempts, ')
          ..write('freeThrowMade: $freeThrowMade, ')
          ..write('freeThrowAttempts: $freeThrowAttempts, ')
          ..write('trackingCoverage: $trackingCoverage, ')
          ..write('confirmedLocationCount: $confirmedLocationCount, ')
          ..write('locatableLocationCount: $locatableLocationCount, ')
          ..write('zoneDistributionJson: $zoneDistributionJson, ')
          ..write('calculatorVersion: $calculatorVersion, ')
          ..write('sourceSha256: $sourceSha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    matchId,
    playerId,
    opponentPlayerId,
    playedAtUtc,
    playerScore,
    opponentScore,
    fieldGoalMade,
    fieldGoalAttempts,
    freeThrowMade,
    freeThrowAttempts,
    trackingCoverage,
    confirmedLocationCount,
    locatableLocationCount,
    zoneDistributionJson,
    calculatorVersion,
    sourceSha256,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerAnalyticsSnapshotRow &&
          other.matchId == this.matchId &&
          other.playerId == this.playerId &&
          other.opponentPlayerId == this.opponentPlayerId &&
          other.playedAtUtc == this.playedAtUtc &&
          other.playerScore == this.playerScore &&
          other.opponentScore == this.opponentScore &&
          other.fieldGoalMade == this.fieldGoalMade &&
          other.fieldGoalAttempts == this.fieldGoalAttempts &&
          other.freeThrowMade == this.freeThrowMade &&
          other.freeThrowAttempts == this.freeThrowAttempts &&
          other.trackingCoverage == this.trackingCoverage &&
          other.confirmedLocationCount == this.confirmedLocationCount &&
          other.locatableLocationCount == this.locatableLocationCount &&
          other.zoneDistributionJson == this.zoneDistributionJson &&
          other.calculatorVersion == this.calculatorVersion &&
          other.sourceSha256 == this.sourceSha256);
}

class PlayerAnalyticsSnapshotsCompanion
    extends UpdateCompanion<PlayerAnalyticsSnapshotRow> {
  final Value<String> matchId;
  final Value<String> playerId;
  final Value<String?> opponentPlayerId;
  final Value<DateTime> playedAtUtc;
  final Value<int> playerScore;
  final Value<int> opponentScore;
  final Value<int> fieldGoalMade;
  final Value<int> fieldGoalAttempts;
  final Value<int> freeThrowMade;
  final Value<int> freeThrowAttempts;
  final Value<String> trackingCoverage;
  final Value<int> confirmedLocationCount;
  final Value<int> locatableLocationCount;
  final Value<String> zoneDistributionJson;
  final Value<int> calculatorVersion;
  final Value<String> sourceSha256;
  final Value<int> rowid;
  const PlayerAnalyticsSnapshotsCompanion({
    this.matchId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.opponentPlayerId = const Value.absent(),
    this.playedAtUtc = const Value.absent(),
    this.playerScore = const Value.absent(),
    this.opponentScore = const Value.absent(),
    this.fieldGoalMade = const Value.absent(),
    this.fieldGoalAttempts = const Value.absent(),
    this.freeThrowMade = const Value.absent(),
    this.freeThrowAttempts = const Value.absent(),
    this.trackingCoverage = const Value.absent(),
    this.confirmedLocationCount = const Value.absent(),
    this.locatableLocationCount = const Value.absent(),
    this.zoneDistributionJson = const Value.absent(),
    this.calculatorVersion = const Value.absent(),
    this.sourceSha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerAnalyticsSnapshotsCompanion.insert({
    required String matchId,
    required String playerId,
    this.opponentPlayerId = const Value.absent(),
    required DateTime playedAtUtc,
    required int playerScore,
    required int opponentScore,
    required int fieldGoalMade,
    required int fieldGoalAttempts,
    required int freeThrowMade,
    required int freeThrowAttempts,
    required String trackingCoverage,
    required int confirmedLocationCount,
    required int locatableLocationCount,
    required String zoneDistributionJson,
    required int calculatorVersion,
    required String sourceSha256,
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId),
       playerId = Value(playerId),
       playedAtUtc = Value(playedAtUtc),
       playerScore = Value(playerScore),
       opponentScore = Value(opponentScore),
       fieldGoalMade = Value(fieldGoalMade),
       fieldGoalAttempts = Value(fieldGoalAttempts),
       freeThrowMade = Value(freeThrowMade),
       freeThrowAttempts = Value(freeThrowAttempts),
       trackingCoverage = Value(trackingCoverage),
       confirmedLocationCount = Value(confirmedLocationCount),
       locatableLocationCount = Value(locatableLocationCount),
       zoneDistributionJson = Value(zoneDistributionJson),
       calculatorVersion = Value(calculatorVersion),
       sourceSha256 = Value(sourceSha256);
  static Insertable<PlayerAnalyticsSnapshotRow> custom({
    Expression<String>? matchId,
    Expression<String>? playerId,
    Expression<String>? opponentPlayerId,
    Expression<DateTime>? playedAtUtc,
    Expression<int>? playerScore,
    Expression<int>? opponentScore,
    Expression<int>? fieldGoalMade,
    Expression<int>? fieldGoalAttempts,
    Expression<int>? freeThrowMade,
    Expression<int>? freeThrowAttempts,
    Expression<String>? trackingCoverage,
    Expression<int>? confirmedLocationCount,
    Expression<int>? locatableLocationCount,
    Expression<String>? zoneDistributionJson,
    Expression<int>? calculatorVersion,
    Expression<String>? sourceSha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (playerId != null) 'player_id': playerId,
      if (opponentPlayerId != null) 'opponent_player_id': opponentPlayerId,
      if (playedAtUtc != null) 'played_at_utc': playedAtUtc,
      if (playerScore != null) 'player_score': playerScore,
      if (opponentScore != null) 'opponent_score': opponentScore,
      if (fieldGoalMade != null) 'field_goal_made': fieldGoalMade,
      if (fieldGoalAttempts != null) 'field_goal_attempts': fieldGoalAttempts,
      if (freeThrowMade != null) 'free_throw_made': freeThrowMade,
      if (freeThrowAttempts != null) 'free_throw_attempts': freeThrowAttempts,
      if (trackingCoverage != null) 'tracking_coverage': trackingCoverage,
      if (confirmedLocationCount != null)
        'confirmed_location_count': confirmedLocationCount,
      if (locatableLocationCount != null)
        'locatable_location_count': locatableLocationCount,
      if (zoneDistributionJson != null)
        'zone_distribution_json': zoneDistributionJson,
      if (calculatorVersion != null) 'calculator_version': calculatorVersion,
      if (sourceSha256 != null) 'source_sha256': sourceSha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerAnalyticsSnapshotsCompanion copyWith({
    Value<String>? matchId,
    Value<String>? playerId,
    Value<String?>? opponentPlayerId,
    Value<DateTime>? playedAtUtc,
    Value<int>? playerScore,
    Value<int>? opponentScore,
    Value<int>? fieldGoalMade,
    Value<int>? fieldGoalAttempts,
    Value<int>? freeThrowMade,
    Value<int>? freeThrowAttempts,
    Value<String>? trackingCoverage,
    Value<int>? confirmedLocationCount,
    Value<int>? locatableLocationCount,
    Value<String>? zoneDistributionJson,
    Value<int>? calculatorVersion,
    Value<String>? sourceSha256,
    Value<int>? rowid,
  }) {
    return PlayerAnalyticsSnapshotsCompanion(
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      opponentPlayerId: opponentPlayerId ?? this.opponentPlayerId,
      playedAtUtc: playedAtUtc ?? this.playedAtUtc,
      playerScore: playerScore ?? this.playerScore,
      opponentScore: opponentScore ?? this.opponentScore,
      fieldGoalMade: fieldGoalMade ?? this.fieldGoalMade,
      fieldGoalAttempts: fieldGoalAttempts ?? this.fieldGoalAttempts,
      freeThrowMade: freeThrowMade ?? this.freeThrowMade,
      freeThrowAttempts: freeThrowAttempts ?? this.freeThrowAttempts,
      trackingCoverage: trackingCoverage ?? this.trackingCoverage,
      confirmedLocationCount:
          confirmedLocationCount ?? this.confirmedLocationCount,
      locatableLocationCount:
          locatableLocationCount ?? this.locatableLocationCount,
      zoneDistributionJson: zoneDistributionJson ?? this.zoneDistributionJson,
      calculatorVersion: calculatorVersion ?? this.calculatorVersion,
      sourceSha256: sourceSha256 ?? this.sourceSha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (opponentPlayerId.present) {
      map['opponent_player_id'] = Variable<String>(opponentPlayerId.value);
    }
    if (playedAtUtc.present) {
      map['played_at_utc'] = Variable<DateTime>(playedAtUtc.value);
    }
    if (playerScore.present) {
      map['player_score'] = Variable<int>(playerScore.value);
    }
    if (opponentScore.present) {
      map['opponent_score'] = Variable<int>(opponentScore.value);
    }
    if (fieldGoalMade.present) {
      map['field_goal_made'] = Variable<int>(fieldGoalMade.value);
    }
    if (fieldGoalAttempts.present) {
      map['field_goal_attempts'] = Variable<int>(fieldGoalAttempts.value);
    }
    if (freeThrowMade.present) {
      map['free_throw_made'] = Variable<int>(freeThrowMade.value);
    }
    if (freeThrowAttempts.present) {
      map['free_throw_attempts'] = Variable<int>(freeThrowAttempts.value);
    }
    if (trackingCoverage.present) {
      map['tracking_coverage'] = Variable<String>(trackingCoverage.value);
    }
    if (confirmedLocationCount.present) {
      map['confirmed_location_count'] = Variable<int>(
        confirmedLocationCount.value,
      );
    }
    if (locatableLocationCount.present) {
      map['locatable_location_count'] = Variable<int>(
        locatableLocationCount.value,
      );
    }
    if (zoneDistributionJson.present) {
      map['zone_distribution_json'] = Variable<String>(
        zoneDistributionJson.value,
      );
    }
    if (calculatorVersion.present) {
      map['calculator_version'] = Variable<int>(calculatorVersion.value);
    }
    if (sourceSha256.present) {
      map['source_sha256'] = Variable<String>(sourceSha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerAnalyticsSnapshotsCompanion(')
          ..write('matchId: $matchId, ')
          ..write('playerId: $playerId, ')
          ..write('opponentPlayerId: $opponentPlayerId, ')
          ..write('playedAtUtc: $playedAtUtc, ')
          ..write('playerScore: $playerScore, ')
          ..write('opponentScore: $opponentScore, ')
          ..write('fieldGoalMade: $fieldGoalMade, ')
          ..write('fieldGoalAttempts: $fieldGoalAttempts, ')
          ..write('freeThrowMade: $freeThrowMade, ')
          ..write('freeThrowAttempts: $freeThrowAttempts, ')
          ..write('trackingCoverage: $trackingCoverage, ')
          ..write('confirmedLocationCount: $confirmedLocationCount, ')
          ..write('locatableLocationCount: $locatableLocationCount, ')
          ..write('zoneDistributionJson: $zoneDistributionJson, ')
          ..write('calculatorVersion: $calculatorVersion, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $MatchSeriesTable matchSeries = $MatchSeriesTable(this);
  late final $SeriesMatchesTable seriesMatches = $SeriesMatchesTable(this);
  late final $MatchParticipantsTable matchParticipants =
      $MatchParticipantsTable(this);
  late final $MatchClocksTable matchClocks = $MatchClocksTable(this);
  late final $ActiveSessionsTable activeSessions = $ActiveSessionsTable(this);
  late final $MatchEventsTable matchEvents = $MatchEventsTable(this);
  late final $ShotLocationsTable shotLocations = $ShotLocationsTable(this);
  late final $RuleTemplatesTable ruleTemplates = $RuleTemplatesTable(this);
  late final $PossessionSegmentsTable possessionSegments =
      $PossessionSegmentsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $PlayerAnalyticsSnapshotsTable playerAnalyticsSnapshots =
      $PlayerAnalyticsSnapshotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    matches,
    players,
    matchSeries,
    seriesMatches,
    matchParticipants,
    matchClocks,
    activeSessions,
    matchEvents,
    shotLocations,
    ruleTemplates,
    possessionSegments,
    auditLogs,
    appSettings,
    playerAnalyticsSnapshots,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_series', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_series', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series_matches', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series_matches', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_participants', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_participants', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_clocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('active_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_locations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_locations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('possession_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('possession_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('possession_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audit_logs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('player_analytics_snapshots', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('player_analytics_snapshots', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('player_analytics_snapshots', kind: UpdateKind.update),
      ],
    ),
  ]);
}

typedef $$MatchesTableCreateCompanionBuilder =
    MatchesCompanion Function({
      required String id,
      Value<String> lifecycle,
      Value<String> recordingMode,
      Value<String> trackingCoverage,
      required String ruleTemplateJson,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<bool> timerEnabled,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$MatchesTableUpdateCompanionBuilder =
    MatchesCompanion Function({
      Value<String> id,
      Value<String> lifecycle,
      Value<String> recordingMode,
      Value<String> trackingCoverage,
      Value<String> ruleTemplateJson,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<bool> timerEnabled,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$MatchesTableReferences
    extends BaseReferences<_$AppDatabase, $MatchesTable, Matche> {
  $$MatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SeriesMatchesTable, List<SeriesMatche>>
  _seriesMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesMatches,
    aliasName: 'matches__id__series_matches__match_id',
  );

  $$SeriesMatchesTableProcessedTableManager get seriesMatchesRefs {
    final manager = $$SeriesMatchesTableTableManager(
      $_db,
      $_db.seriesMatches,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchParticipantsTable, List<MatchParticipant>>
  _matchParticipantsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.matchParticipants,
        aliasName: 'matches__id__match_participants__match_id',
      );

  $$MatchParticipantsTableProcessedTableManager get matchParticipantsRefs {
    final manager = $$MatchParticipantsTableTableManager(
      $_db,
      $_db.matchParticipants,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _matchParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchClocksTable, List<MatchClock>>
  _matchClocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchClocks,
    aliasName: 'matches__id__match_clocks__match_id',
  );

  $$MatchClocksTableProcessedTableManager get matchClocksRefs {
    final manager = $$MatchClocksTableTableManager(
      $_db,
      $_db.matchClocks,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchClocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActiveSessionsTable, List<ActiveSession>>
  _activeSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.activeSessions,
    aliasName: 'matches__id__active_sessions__match_id',
  );

  $$ActiveSessionsTableProcessedTableManager get activeSessionsRefs {
    final manager = $$ActiveSessionsTableTableManager(
      $_db,
      $_db.activeSessions,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activeSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchEventsTable, List<MatchEventRow>>
  _matchEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEvents,
    aliasName: 'matches__id__match_events__match_id',
  );

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShotLocationsTable, List<ShotLocation>>
  _shotLocationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shotLocations,
    aliasName: 'matches__id__shot_locations__match_id',
  );

  $$ShotLocationsTableProcessedTableManager get shotLocationsRefs {
    final manager = $$ShotLocationsTableTableManager(
      $_db,
      $_db.shotLocations,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotLocationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PossessionSegmentsTable, List<PossessionSegment>>
  _possessionSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.possessionSegments,
        aliasName: 'matches__id__possession_segments__match_id',
      );

  $$PossessionSegmentsTableProcessedTableManager get possessionSegmentsRefs {
    final manager = $$PossessionSegmentsTableTableManager(
      $_db,
      $_db.possessionSegments,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _possessionSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AuditLogsTable, List<AuditLog>>
  _auditLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.auditLogs,
    aliasName: 'matches__id__audit_logs__match_id',
  );

  $$AuditLogsTableProcessedTableManager get auditLogsRefs {
    final manager = $$AuditLogsTableTableManager(
      $_db,
      $_db.auditLogs,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlayerAnalyticsSnapshotsTable,
    List<PlayerAnalyticsSnapshotRow>
  >
  _playerAnalyticsSnapshotsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playerAnalyticsSnapshots,
        aliasName: 'matches__id__player_analytics_snapshots__match_id',
      );

  $$PlayerAnalyticsSnapshotsTableProcessedTableManager
  get playerAnalyticsSnapshotsRefs {
    final manager = $$PlayerAnalyticsSnapshotsTableTableManager(
      $_db,
      $_db.playerAnalyticsSnapshots,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playerAnalyticsSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingMode => $composableBuilder(
    column: $table.recordingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleTemplateJson => $composableBuilder(
    column: $table.ruleTemplateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get timerEnabled => $composableBuilder(
    column: $table.timerEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> seriesMatchesRefs(
    Expression<bool> Function($$SeriesMatchesTableFilterComposer f) f,
  ) {
    final $$SeriesMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesMatches,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesMatchesTableFilterComposer(
            $db: $db,
            $table: $db.seriesMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchParticipantsRefs(
    Expression<bool> Function($$MatchParticipantsTableFilterComposer f) f,
  ) {
    final $$MatchParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchParticipants,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.matchParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchClocksRefs(
    Expression<bool> Function($$MatchClocksTableFilterComposer f) f,
  ) {
    final $$MatchClocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchClocks,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchClocksTableFilterComposer(
            $db: $db,
            $table: $db.matchClocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activeSessionsRefs(
    Expression<bool> Function($$ActiveSessionsTableFilterComposer f) f,
  ) {
    final $$ActiveSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activeSessions,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActiveSessionsTableFilterComposer(
            $db: $db,
            $table: $db.activeSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchEventsRefs(
    Expression<bool> Function($$MatchEventsTableFilterComposer f) f,
  ) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shotLocationsRefs(
    Expression<bool> Function($$ShotLocationsTableFilterComposer f) f,
  ) {
    final $$ShotLocationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotLocations,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotLocationsTableFilterComposer(
            $db: $db,
            $table: $db.shotLocations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> possessionSegmentsRefs(
    Expression<bool> Function($$PossessionSegmentsTableFilterComposer f) f,
  ) {
    final $$PossessionSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.possessionSegments,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PossessionSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.possessionSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> auditLogsRefs(
    Expression<bool> Function($$AuditLogsTableFilterComposer f) f,
  ) {
    final $$AuditLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditLogs,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditLogsTableFilterComposer(
            $db: $db,
            $table: $db.auditLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playerAnalyticsSnapshotsRefs(
    Expression<bool> Function($$PlayerAnalyticsSnapshotsTableFilterComposer f)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.matchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableFilterComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingMode => $composableBuilder(
    column: $table.recordingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleTemplateJson => $composableBuilder(
    column: $table.ruleTemplateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get timerEnabled => $composableBuilder(
    column: $table.timerEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get recordingMode => $composableBuilder(
    column: $table.recordingMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleTemplateJson => $composableBuilder(
    column: $table.ruleTemplateJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<bool> get timerEnabled => $composableBuilder(
    column: $table.timerEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> seriesMatchesRefs<T extends Object>(
    Expression<T> Function($$SeriesMatchesTableAnnotationComposer a) f,
  ) {
    final $$SeriesMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesMatches,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchParticipantsRefs<T extends Object>(
    Expression<T> Function($$MatchParticipantsTableAnnotationComposer a) f,
  ) {
    final $$MatchParticipantsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.matchParticipants,
          getReferencedColumn: (t) => t.matchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MatchParticipantsTableAnnotationComposer(
                $db: $db,
                $table: $db.matchParticipants,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> matchClocksRefs<T extends Object>(
    Expression<T> Function($$MatchClocksTableAnnotationComposer a) f,
  ) {
    final $$MatchClocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchClocks,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchClocksTableAnnotationComposer(
            $db: $db,
            $table: $db.matchClocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activeSessionsRefs<T extends Object>(
    Expression<T> Function($$ActiveSessionsTableAnnotationComposer a) f,
  ) {
    final $$ActiveSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activeSessions,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActiveSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.activeSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchEventsRefs<T extends Object>(
    Expression<T> Function($$MatchEventsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shotLocationsRefs<T extends Object>(
    Expression<T> Function($$ShotLocationsTableAnnotationComposer a) f,
  ) {
    final $$ShotLocationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotLocations,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotLocationsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotLocations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> possessionSegmentsRefs<T extends Object>(
    Expression<T> Function($$PossessionSegmentsTableAnnotationComposer a) f,
  ) {
    final $$PossessionSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.possessionSegments,
          getReferencedColumn: (t) => t.matchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PossessionSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.possessionSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> auditLogsRefs<T extends Object>(
    Expression<T> Function($$AuditLogsTableAnnotationComposer a) f,
  ) {
    final $$AuditLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditLogs,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playerAnalyticsSnapshotsRefs<T extends Object>(
    Expression<T> Function($$PlayerAnalyticsSnapshotsTableAnnotationComposer a)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.matchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchesTable,
          Matche,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (Matche, $$MatchesTableReferences),
          Matche,
          PrefetchHooks Function({
            bool seriesMatchesRefs,
            bool matchParticipantsRefs,
            bool matchClocksRefs,
            bool activeSessionsRefs,
            bool matchEventsRefs,
            bool shotLocationsRefs,
            bool possessionSegmentsRefs,
            bool auditLogsRefs,
            bool playerAnalyticsSnapshotsRefs,
          })
        > {
  $$MatchesTableTableManager(_$AppDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<String> recordingMode = const Value.absent(),
                Value<String> trackingCoverage = const Value.absent(),
                Value<String> ruleTemplateJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> timerEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion(
                id: id,
                lifecycle: lifecycle,
                recordingMode: recordingMode,
                trackingCoverage: trackingCoverage,
                ruleTemplateJson: ruleTemplateJson,
                createdAt: createdAt,
                startedAt: startedAt,
                endedAt: endedAt,
                timerEnabled: timerEnabled,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> lifecycle = const Value.absent(),
                Value<String> recordingMode = const Value.absent(),
                Value<String> trackingCoverage = const Value.absent(),
                required String ruleTemplateJson,
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> timerEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion.insert(
                id: id,
                lifecycle: lifecycle,
                recordingMode: recordingMode,
                trackingCoverage: trackingCoverage,
                ruleTemplateJson: ruleTemplateJson,
                createdAt: createdAt,
                startedAt: startedAt,
                endedAt: endedAt,
                timerEnabled: timerEnabled,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                seriesMatchesRefs = false,
                matchParticipantsRefs = false,
                matchClocksRefs = false,
                activeSessionsRefs = false,
                matchEventsRefs = false,
                shotLocationsRefs = false,
                possessionSegmentsRefs = false,
                auditLogsRefs = false,
                playerAnalyticsSnapshotsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (seriesMatchesRefs) db.seriesMatches,
                    if (matchParticipantsRefs) db.matchParticipants,
                    if (matchClocksRefs) db.matchClocks,
                    if (activeSessionsRefs) db.activeSessions,
                    if (matchEventsRefs) db.matchEvents,
                    if (shotLocationsRefs) db.shotLocations,
                    if (possessionSegmentsRefs) db.possessionSegments,
                    if (auditLogsRefs) db.auditLogs,
                    if (playerAnalyticsSnapshotsRefs)
                      db.playerAnalyticsSnapshots,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (seriesMatchesRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          SeriesMatche
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._seriesMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchParticipantsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          MatchParticipant
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._matchParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchParticipantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchClocksRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          MatchClock
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._matchClocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchClocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activeSessionsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          ActiveSession
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._activeSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).activeSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchEventsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          MatchEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._matchEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shotLocationsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          ShotLocation
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._shotLocationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).shotLocationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (possessionSegmentsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          PossessionSegment
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._possessionSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).possessionSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (auditLogsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          AuditLog
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._auditLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).auditLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playerAnalyticsSnapshotsRefs)
                        await $_getPrefetchedData<
                          Matche,
                          $MatchesTable,
                          PlayerAnalyticsSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._playerAnalyticsSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).playerAnalyticsSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchesTable,
      Matche,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (Matche, $$MatchesTableReferences),
      Matche,
      PrefetchHooks Function({
        bool seriesMatchesRefs,
        bool matchParticipantsRefs,
        bool matchClocksRefs,
        bool activeSessionsRefs,
        bool matchEventsRefs,
        bool shotLocationsRefs,
        bool possessionSegmentsRefs,
        bool auditLogsRefs,
        bool playerAnalyticsSnapshotsRefs,
      })
    >;
typedef $$PlayersTableCreateCompanionBuilder =
    PlayersCompanion Function({
      required String id,
      required String nickname,
      required DateTime createdAt,
      Value<String?> preferredSide,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$PlayersTableUpdateCompanionBuilder =
    PlayersCompanion Function({
      Value<String> id,
      Value<String> nickname,
      Value<DateTime> createdAt,
      Value<String?> preferredSide,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$PlayersTableReferences
    extends BaseReferences<_$AppDatabase, $PlayersTable, PlayerRow> {
  $$PlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MatchSeriesTable, List<MatchSeriesRow>>
  _seriesSlotATable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchSeries,
    aliasName: 'players__id__match_series__slot_a_player_profile_id',
  );

  $$MatchSeriesTableProcessedTableManager get seriesSlotA {
    final manager = $$MatchSeriesTableTableManager($_db, $_db.matchSeries)
        .filter(
          (f) =>
              f.slotAPlayerProfileId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_seriesSlotATable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchSeriesTable, List<MatchSeriesRow>>
  _seriesSlotBTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchSeries,
    aliasName: 'players__id__match_series__slot_b_player_profile_id',
  );

  $$MatchSeriesTableProcessedTableManager get seriesSlotB {
    final manager = $$MatchSeriesTableTableManager($_db, $_db.matchSeries)
        .filter(
          (f) =>
              f.slotBPlayerProfileId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_seriesSlotBTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchParticipantsTable, List<MatchParticipant>>
  _matchParticipantsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.matchParticipants,
        aliasName: 'players__id__match_participants__player_profile_id',
      );

  $$MatchParticipantsTableProcessedTableManager get matchParticipantsRefs {
    final manager =
        $$MatchParticipantsTableTableManager(
          $_db,
          $_db.matchParticipants,
        ).filter(
          (f) => f.playerProfileId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _matchParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlayerAnalyticsSnapshotsTable,
    List<PlayerAnalyticsSnapshotRow>
  >
  _playerAnalyticsSnapshotPlayersTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playerAnalyticsSnapshots,
        aliasName: 'players__id__player_analytics_snapshots__player_id',
      );

  $$PlayerAnalyticsSnapshotsTableProcessedTableManager
  get playerAnalyticsSnapshotPlayers {
    final manager = $$PlayerAnalyticsSnapshotsTableTableManager(
      $_db,
      $_db.playerAnalyticsSnapshots,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playerAnalyticsSnapshotPlayersTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlayerAnalyticsSnapshotsTable,
    List<PlayerAnalyticsSnapshotRow>
  >
  _playerAnalyticsSnapshotOpponentsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playerAnalyticsSnapshots,
        aliasName:
            'players__id__player_analytics_snapshots__opponent_player_id',
      );

  $$PlayerAnalyticsSnapshotsTableProcessedTableManager
  get playerAnalyticsSnapshotOpponents {
    final manager =
        $$PlayerAnalyticsSnapshotsTableTableManager(
          $_db,
          $_db.playerAnalyticsSnapshots,
        ).filter(
          (f) => f.opponentPlayerId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _playerAnalyticsSnapshotOpponentsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> seriesSlotA(
    Expression<bool> Function($$MatchSeriesTableFilterComposer f) f,
  ) {
    final $$MatchSeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.slotAPlayerProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableFilterComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesSlotB(
    Expression<bool> Function($$MatchSeriesTableFilterComposer f) f,
  ) {
    final $$MatchSeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.slotBPlayerProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableFilterComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchParticipantsRefs(
    Expression<bool> Function($$MatchParticipantsTableFilterComposer f) f,
  ) {
    final $$MatchParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchParticipants,
      getReferencedColumn: (t) => t.playerProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.matchParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playerAnalyticsSnapshotPlayers(
    Expression<bool> Function($$PlayerAnalyticsSnapshotsTableFilterComposer f)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableFilterComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> playerAnalyticsSnapshotOpponents(
    Expression<bool> Function($$PlayerAnalyticsSnapshotsTableFilterComposer f)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.opponentPlayerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableFilterComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> seriesSlotA<T extends Object>(
    Expression<T> Function($$MatchSeriesTableAnnotationComposer a) f,
  ) {
    final $$MatchSeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.slotAPlayerProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesSlotB<T extends Object>(
    Expression<T> Function($$MatchSeriesTableAnnotationComposer a) f,
  ) {
    final $$MatchSeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.slotBPlayerProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchParticipantsRefs<T extends Object>(
    Expression<T> Function($$MatchParticipantsTableAnnotationComposer a) f,
  ) {
    final $$MatchParticipantsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.matchParticipants,
          getReferencedColumn: (t) => t.playerProfileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MatchParticipantsTableAnnotationComposer(
                $db: $db,
                $table: $db.matchParticipants,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playerAnalyticsSnapshotPlayers<T extends Object>(
    Expression<T> Function($$PlayerAnalyticsSnapshotsTableAnnotationComposer a)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playerAnalyticsSnapshotOpponents<T extends Object>(
    Expression<T> Function($$PlayerAnalyticsSnapshotsTableAnnotationComposer a)
    f,
  ) {
    final $$PlayerAnalyticsSnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerAnalyticsSnapshots,
          getReferencedColumn: (t) => t.opponentPlayerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerAnalyticsSnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.playerAnalyticsSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          PlayerRow,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (PlayerRow, $$PlayersTableReferences),
          PlayerRow,
          PrefetchHooks Function({
            bool seriesSlotA,
            bool seriesSlotB,
            bool matchParticipantsRefs,
            bool playerAnalyticsSnapshotPlayers,
            bool playerAnalyticsSnapshotOpponents,
          })
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> preferredSide = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                nickname: nickname,
                createdAt: createdAt,
                preferredSide: preferredSide,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nickname,
                required DateTime createdAt,
                Value<String?> preferredSide = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                nickname: nickname,
                createdAt: createdAt,
                preferredSide: preferredSide,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                seriesSlotA = false,
                seriesSlotB = false,
                matchParticipantsRefs = false,
                playerAnalyticsSnapshotPlayers = false,
                playerAnalyticsSnapshotOpponents = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (seriesSlotA) db.matchSeries,
                    if (seriesSlotB) db.matchSeries,
                    if (matchParticipantsRefs) db.matchParticipants,
                    if (playerAnalyticsSnapshotPlayers)
                      db.playerAnalyticsSnapshots,
                    if (playerAnalyticsSnapshotOpponents)
                      db.playerAnalyticsSnapshots,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (seriesSlotA)
                        await $_getPrefetchedData<
                          PlayerRow,
                          $PlayersTable,
                          MatchSeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._seriesSlotATable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesSlotA,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.slotAPlayerProfileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesSlotB)
                        await $_getPrefetchedData<
                          PlayerRow,
                          $PlayersTable,
                          MatchSeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._seriesSlotBTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesSlotB,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.slotBPlayerProfileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchParticipantsRefs)
                        await $_getPrefetchedData<
                          PlayerRow,
                          $PlayersTable,
                          MatchParticipant
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._matchParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).matchParticipantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playerProfileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playerAnalyticsSnapshotPlayers)
                        await $_getPrefetchedData<
                          PlayerRow,
                          $PlayersTable,
                          PlayerAnalyticsSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._playerAnalyticsSnapshotPlayersTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).playerAnalyticsSnapshotPlayers,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playerAnalyticsSnapshotOpponents)
                        await $_getPrefetchedData<
                          PlayerRow,
                          $PlayersTable,
                          PlayerAnalyticsSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._playerAnalyticsSnapshotOpponentsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).playerAnalyticsSnapshotOpponents,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.opponentPlayerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      PlayerRow,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (PlayerRow, $$PlayersTableReferences),
      PlayerRow,
      PrefetchHooks Function({
        bool seriesSlotA,
        bool seriesSlotB,
        bool matchParticipantsRefs,
        bool playerAnalyticsSnapshotPlayers,
        bool playerAnalyticsSnapshotOpponents,
      })
    >;
typedef $$MatchSeriesTableCreateCompanionBuilder =
    MatchSeriesCompanion Function({
      required String id,
      required String slotAName,
      required String slotBName,
      Value<String?> slotAPlayerProfileId,
      Value<String?> slotBPlayerProfileId,
      Value<String> lifecycle,
      required DateTime createdAt,
      Value<DateTime?> closedAt,
      Value<int> nextGameNumber,
      Value<int> revision,
      required String defaultSetupJson,
      Value<String> lifecycleIntentsJson,
      Value<int> rowid,
    });
typedef $$MatchSeriesTableUpdateCompanionBuilder =
    MatchSeriesCompanion Function({
      Value<String> id,
      Value<String> slotAName,
      Value<String> slotBName,
      Value<String?> slotAPlayerProfileId,
      Value<String?> slotBPlayerProfileId,
      Value<String> lifecycle,
      Value<DateTime> createdAt,
      Value<DateTime?> closedAt,
      Value<int> nextGameNumber,
      Value<int> revision,
      Value<String> defaultSetupJson,
      Value<String> lifecycleIntentsJson,
      Value<int> rowid,
    });

final class $$MatchSeriesTableReferences
    extends BaseReferences<_$AppDatabase, $MatchSeriesTable, MatchSeriesRow> {
  $$MatchSeriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlayersTable _slotAPlayerProfileIdTable(_$AppDatabase db) => db
      .players
      .createAlias('match_series__slot_a_player_profile_id__players__id');

  $$PlayersTableProcessedTableManager? get slotAPlayerProfileId {
    final $_column = $_itemColumn<String>('slot_a_player_profile_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _slotAPlayerProfileIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _slotBPlayerProfileIdTable(_$AppDatabase db) => db
      .players
      .createAlias('match_series__slot_b_player_profile_id__players__id');

  $$PlayersTableProcessedTableManager? get slotBPlayerProfileId {
    final $_column = $_itemColumn<String>('slot_b_player_profile_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _slotBPlayerProfileIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SeriesMatchesTable, List<SeriesMatche>>
  _seriesMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesMatches,
    aliasName: 'match_series__id__series_matches__series_id',
  );

  $$SeriesMatchesTableProcessedTableManager get seriesMatchesRefs {
    final manager = $$SeriesMatchesTableTableManager(
      $_db,
      $_db.seriesMatches,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchSeriesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchSeriesTable> {
  $$MatchSeriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slotAName => $composableBuilder(
    column: $table.slotAName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slotBName => $composableBuilder(
    column: $table.slotBName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextGameNumber => $composableBuilder(
    column: $table.nextGameNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultSetupJson => $composableBuilder(
    column: $table.defaultSetupJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycleIntentsJson => $composableBuilder(
    column: $table.lifecycleIntentsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get slotAPlayerProfileId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotAPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get slotBPlayerProfileId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotBPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> seriesMatchesRefs(
    Expression<bool> Function($$SeriesMatchesTableFilterComposer f) f,
  ) {
    final $$SeriesMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesMatches,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesMatchesTableFilterComposer(
            $db: $db,
            $table: $db.seriesMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSeriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchSeriesTable> {
  $$MatchSeriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slotAName => $composableBuilder(
    column: $table.slotAName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slotBName => $composableBuilder(
    column: $table.slotBName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextGameNumber => $composableBuilder(
    column: $table.nextGameNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSetupJson => $composableBuilder(
    column: $table.defaultSetupJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycleIntentsJson => $composableBuilder(
    column: $table.lifecycleIntentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get slotAPlayerProfileId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotAPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get slotBPlayerProfileId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotBPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchSeriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchSeriesTable> {
  $$MatchSeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slotAName =>
      $composableBuilder(column: $table.slotAName, builder: (column) => column);

  GeneratedColumn<String> get slotBName =>
      $composableBuilder(column: $table.slotBName, builder: (column) => column);

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get nextGameNumber => $composableBuilder(
    column: $table.nextGameNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get defaultSetupJson => $composableBuilder(
    column: $table.defaultSetupJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycleIntentsJson => $composableBuilder(
    column: $table.lifecycleIntentsJson,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get slotAPlayerProfileId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotAPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get slotBPlayerProfileId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotBPlayerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> seriesMatchesRefs<T extends Object>(
    Expression<T> Function($$SeriesMatchesTableAnnotationComposer a) f,
  ) {
    final $$SeriesMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesMatches,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchSeriesTable,
          MatchSeriesRow,
          $$MatchSeriesTableFilterComposer,
          $$MatchSeriesTableOrderingComposer,
          $$MatchSeriesTableAnnotationComposer,
          $$MatchSeriesTableCreateCompanionBuilder,
          $$MatchSeriesTableUpdateCompanionBuilder,
          (MatchSeriesRow, $$MatchSeriesTableReferences),
          MatchSeriesRow,
          PrefetchHooks Function({
            bool slotAPlayerProfileId,
            bool slotBPlayerProfileId,
            bool seriesMatchesRefs,
          })
        > {
  $$MatchSeriesTableTableManager(_$AppDatabase db, $MatchSeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchSeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchSeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchSeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> slotAName = const Value.absent(),
                Value<String> slotBName = const Value.absent(),
                Value<String?> slotAPlayerProfileId = const Value.absent(),
                Value<String?> slotBPlayerProfileId = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int> nextGameNumber = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> defaultSetupJson = const Value.absent(),
                Value<String> lifecycleIntentsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchSeriesCompanion(
                id: id,
                slotAName: slotAName,
                slotBName: slotBName,
                slotAPlayerProfileId: slotAPlayerProfileId,
                slotBPlayerProfileId: slotBPlayerProfileId,
                lifecycle: lifecycle,
                createdAt: createdAt,
                closedAt: closedAt,
                nextGameNumber: nextGameNumber,
                revision: revision,
                defaultSetupJson: defaultSetupJson,
                lifecycleIntentsJson: lifecycleIntentsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String slotAName,
                required String slotBName,
                Value<String?> slotAPlayerProfileId = const Value.absent(),
                Value<String?> slotBPlayerProfileId = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int> nextGameNumber = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String defaultSetupJson,
                Value<String> lifecycleIntentsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchSeriesCompanion.insert(
                id: id,
                slotAName: slotAName,
                slotBName: slotBName,
                slotAPlayerProfileId: slotAPlayerProfileId,
                slotBPlayerProfileId: slotBPlayerProfileId,
                lifecycle: lifecycle,
                createdAt: createdAt,
                closedAt: closedAt,
                nextGameNumber: nextGameNumber,
                revision: revision,
                defaultSetupJson: defaultSetupJson,
                lifecycleIntentsJson: lifecycleIntentsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchSeriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                slotAPlayerProfileId = false,
                slotBPlayerProfileId = false,
                seriesMatchesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (seriesMatchesRefs) db.seriesMatches,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (slotAPlayerProfileId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.slotAPlayerProfileId,
                                    referencedTable:
                                        $$MatchSeriesTableReferences
                                            ._slotAPlayerProfileIdTable(db),
                                    referencedColumn:
                                        $$MatchSeriesTableReferences
                                            ._slotAPlayerProfileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (slotBPlayerProfileId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.slotBPlayerProfileId,
                                    referencedTable:
                                        $$MatchSeriesTableReferences
                                            ._slotBPlayerProfileIdTable(db),
                                    referencedColumn:
                                        $$MatchSeriesTableReferences
                                            ._slotBPlayerProfileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (seriesMatchesRefs)
                        await $_getPrefetchedData<
                          MatchSeriesRow,
                          $MatchSeriesTable,
                          SeriesMatche
                        >(
                          currentTable: table,
                          referencedTable: $$MatchSeriesTableReferences
                              ._seriesMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchSeriesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MatchSeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchSeriesTable,
      MatchSeriesRow,
      $$MatchSeriesTableFilterComposer,
      $$MatchSeriesTableOrderingComposer,
      $$MatchSeriesTableAnnotationComposer,
      $$MatchSeriesTableCreateCompanionBuilder,
      $$MatchSeriesTableUpdateCompanionBuilder,
      (MatchSeriesRow, $$MatchSeriesTableReferences),
      MatchSeriesRow,
      PrefetchHooks Function({
        bool slotAPlayerProfileId,
        bool slotBPlayerProfileId,
        bool seriesMatchesRefs,
      })
    >;
typedef $$SeriesMatchesTableCreateCompanionBuilder =
    SeriesMatchesCompanion Function({
      required String matchId,
      required String seriesId,
      required int gameNumber,
      required String slotASide,
      Value<int> rowid,
    });
typedef $$SeriesMatchesTableUpdateCompanionBuilder =
    SeriesMatchesCompanion Function({
      Value<String> matchId,
      Value<String> seriesId,
      Value<int> gameNumber,
      Value<String> slotASide,
      Value<int> rowid,
    });

final class $$SeriesMatchesTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesMatchesTable, SeriesMatche> {
  $$SeriesMatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('series_matches__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MatchSeriesTable _seriesIdTable(_$AppDatabase db) =>
      db.matchSeries.createAlias('series_matches__series_id__match_series__id');

  $$MatchSeriesTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<String>('series_id')!;

    final manager = $$MatchSeriesTableTableManager(
      $_db,
      $_db.matchSeries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SeriesMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesMatchesTable> {
  $$SeriesMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get gameNumber => $composableBuilder(
    column: $table.gameNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slotASide => $composableBuilder(
    column: $table.slotASide,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchSeriesTableFilterComposer get seriesId {
    final $$MatchSeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableFilterComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesMatchesTable> {
  $$SeriesMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get gameNumber => $composableBuilder(
    column: $table.gameNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slotASide => $composableBuilder(
    column: $table.slotASide,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchSeriesTableOrderingComposer get seriesId {
    final $$MatchSeriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableOrderingComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesMatchesTable> {
  $$SeriesMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get gameNumber => $composableBuilder(
    column: $table.gameNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slotASide =>
      $composableBuilder(column: $table.slotASide, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchSeriesTableAnnotationComposer get seriesId {
    final $$MatchSeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.matchSeries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSeries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesMatchesTable,
          SeriesMatche,
          $$SeriesMatchesTableFilterComposer,
          $$SeriesMatchesTableOrderingComposer,
          $$SeriesMatchesTableAnnotationComposer,
          $$SeriesMatchesTableCreateCompanionBuilder,
          $$SeriesMatchesTableUpdateCompanionBuilder,
          (SeriesMatche, $$SeriesMatchesTableReferences),
          SeriesMatche,
          PrefetchHooks Function({bool matchId, bool seriesId})
        > {
  $$SeriesMatchesTableTableManager(_$AppDatabase db, $SeriesMatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> matchId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int> gameNumber = const Value.absent(),
                Value<String> slotASide = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesMatchesCompanion(
                matchId: matchId,
                seriesId: seriesId,
                gameNumber: gameNumber,
                slotASide: slotASide,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String matchId,
                required String seriesId,
                required int gameNumber,
                required String slotASide,
                Value<int> rowid = const Value.absent(),
              }) => SeriesMatchesCompanion.insert(
                matchId: matchId,
                seriesId: seriesId,
                gameNumber: gameNumber,
                slotASide: slotASide,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SeriesMatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false, seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$SeriesMatchesTableReferences
                                    ._matchIdTable(db),
                                referencedColumn: $$SeriesMatchesTableReferences
                                    ._matchIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$SeriesMatchesTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn: $$SeriesMatchesTableReferences
                                    ._seriesIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SeriesMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesMatchesTable,
      SeriesMatche,
      $$SeriesMatchesTableFilterComposer,
      $$SeriesMatchesTableOrderingComposer,
      $$SeriesMatchesTableAnnotationComposer,
      $$SeriesMatchesTableCreateCompanionBuilder,
      $$SeriesMatchesTableUpdateCompanionBuilder,
      (SeriesMatche, $$SeriesMatchesTableReferences),
      SeriesMatche,
      PrefetchHooks Function({bool matchId, bool seriesId})
    >;
typedef $$MatchParticipantsTableCreateCompanionBuilder =
    MatchParticipantsCompanion Function({
      required String id,
      required String matchId,
      required String side,
      required String nameSnapshot,
      Value<String?> playerProfileId,
      Value<int> rowid,
    });
typedef $$MatchParticipantsTableUpdateCompanionBuilder =
    MatchParticipantsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> side,
      Value<String> nameSnapshot,
      Value<String?> playerProfileId,
      Value<int> rowid,
    });

final class $$MatchParticipantsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MatchParticipantsTable,
          MatchParticipant
        > {
  $$MatchParticipantsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('match_participants__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _playerProfileIdTable(_$AppDatabase db) => db.players
      .createAlias('match_participants__player_profile_id__players__id');

  $$PlayersTableProcessedTableManager? get playerProfileId {
    final $_column = $_itemColumn<String>('player_profile_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerProfileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchParticipantsTable> {
  $$MatchParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get playerProfileId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchParticipantsTable> {
  $$MatchParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get playerProfileId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchParticipantsTable> {
  $$MatchParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get playerProfileId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerProfileId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchParticipantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchParticipantsTable,
          MatchParticipant,
          $$MatchParticipantsTableFilterComposer,
          $$MatchParticipantsTableOrderingComposer,
          $$MatchParticipantsTableAnnotationComposer,
          $$MatchParticipantsTableCreateCompanionBuilder,
          $$MatchParticipantsTableUpdateCompanionBuilder,
          (MatchParticipant, $$MatchParticipantsTableReferences),
          MatchParticipant,
          PrefetchHooks Function({bool matchId, bool playerProfileId})
        > {
  $$MatchParticipantsTableTableManager(
    _$AppDatabase db,
    $MatchParticipantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchParticipantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchParticipantsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> side = const Value.absent(),
                Value<String> nameSnapshot = const Value.absent(),
                Value<String?> playerProfileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchParticipantsCompanion(
                id: id,
                matchId: matchId,
                side: side,
                nameSnapshot: nameSnapshot,
                playerProfileId: playerProfileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String side,
                required String nameSnapshot,
                Value<String?> playerProfileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchParticipantsCompanion.insert(
                id: id,
                matchId: matchId,
                side: side,
                nameSnapshot: nameSnapshot,
                playerProfileId: playerProfileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchParticipantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false, playerProfileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable:
                                    $$MatchParticipantsTableReferences
                                        ._matchIdTable(db),
                                referencedColumn:
                                    $$MatchParticipantsTableReferences
                                        ._matchIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (playerProfileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playerProfileId,
                                referencedTable:
                                    $$MatchParticipantsTableReferences
                                        ._playerProfileIdTable(db),
                                referencedColumn:
                                    $$MatchParticipantsTableReferences
                                        ._playerProfileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MatchParticipantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchParticipantsTable,
      MatchParticipant,
      $$MatchParticipantsTableFilterComposer,
      $$MatchParticipantsTableOrderingComposer,
      $$MatchParticipantsTableAnnotationComposer,
      $$MatchParticipantsTableCreateCompanionBuilder,
      $$MatchParticipantsTableUpdateCompanionBuilder,
      (MatchParticipant, $$MatchParticipantsTableReferences),
      MatchParticipant,
      PrefetchHooks Function({bool matchId, bool playerProfileId})
    >;
typedef $$MatchClocksTableCreateCompanionBuilder =
    MatchClocksCompanion Function({
      required String id,
      required String matchId,
      Value<String> mode,
      Value<String> phase,
      Value<int> accumulatedSeconds,
      Value<DateTime?> runningSinceUtc,
      Value<int?> regulationSeconds,
      Value<int> rowid,
    });
typedef $$MatchClocksTableUpdateCompanionBuilder =
    MatchClocksCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> mode,
      Value<String> phase,
      Value<int> accumulatedSeconds,
      Value<DateTime?> runningSinceUtc,
      Value<int?> regulationSeconds,
      Value<int> rowid,
    });

final class $$MatchClocksTableReferences
    extends BaseReferences<_$AppDatabase, $MatchClocksTable, MatchClock> {
  $$MatchClocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('match_clocks__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchClocksTableFilterComposer
    extends Composer<_$AppDatabase, $MatchClocksTable> {
  $$MatchClocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get runningSinceUtc => $composableBuilder(
    column: $table.runningSinceUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regulationSeconds => $composableBuilder(
    column: $table.regulationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchClocksTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchClocksTable> {
  $$MatchClocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get runningSinceUtc => $composableBuilder(
    column: $table.runningSinceUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regulationSeconds => $composableBuilder(
    column: $table.regulationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchClocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchClocksTable> {
  $$MatchClocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get runningSinceUtc => $composableBuilder(
    column: $table.runningSinceUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get regulationSeconds => $composableBuilder(
    column: $table.regulationSeconds,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchClocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchClocksTable,
          MatchClock,
          $$MatchClocksTableFilterComposer,
          $$MatchClocksTableOrderingComposer,
          $$MatchClocksTableAnnotationComposer,
          $$MatchClocksTableCreateCompanionBuilder,
          $$MatchClocksTableUpdateCompanionBuilder,
          (MatchClock, $$MatchClocksTableReferences),
          MatchClock,
          PrefetchHooks Function({bool matchId})
        > {
  $$MatchClocksTableTableManager(_$AppDatabase db, $MatchClocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchClocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchClocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchClocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<int> accumulatedSeconds = const Value.absent(),
                Value<DateTime?> runningSinceUtc = const Value.absent(),
                Value<int?> regulationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchClocksCompanion(
                id: id,
                matchId: matchId,
                mode: mode,
                phase: phase,
                accumulatedSeconds: accumulatedSeconds,
                runningSinceUtc: runningSinceUtc,
                regulationSeconds: regulationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                Value<String> mode = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<int> accumulatedSeconds = const Value.absent(),
                Value<DateTime?> runningSinceUtc = const Value.absent(),
                Value<int?> regulationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchClocksCompanion.insert(
                id: id,
                matchId: matchId,
                mode: mode,
                phase: phase,
                accumulatedSeconds: accumulatedSeconds,
                runningSinceUtc: runningSinceUtc,
                regulationSeconds: regulationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchClocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$MatchClocksTableReferences
                                    ._matchIdTable(db),
                                referencedColumn: $$MatchClocksTableReferences
                                    ._matchIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MatchClocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchClocksTable,
      MatchClock,
      $$MatchClocksTableFilterComposer,
      $$MatchClocksTableOrderingComposer,
      $$MatchClocksTableAnnotationComposer,
      $$MatchClocksTableCreateCompanionBuilder,
      $$MatchClocksTableUpdateCompanionBuilder,
      (MatchClock, $$MatchClocksTableReferences),
      MatchClock,
      PrefetchHooks Function({bool matchId})
    >;
typedef $$ActiveSessionsTableCreateCompanionBuilder =
    ActiveSessionsCompanion Function({
      Value<String> id,
      required String matchId,
      Value<DateTime> claimedAtUtc,
      Value<int> rowid,
    });
typedef $$ActiveSessionsTableUpdateCompanionBuilder =
    ActiveSessionsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<DateTime> claimedAtUtc,
      Value<int> rowid,
    });

final class $$ActiveSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $ActiveSessionsTable, ActiveSession> {
  $$ActiveSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('active_sessions__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActiveSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get claimedAtUtc => $composableBuilder(
    column: $table.claimedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get claimedAtUtc => $composableBuilder(
    column: $table.claimedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get claimedAtUtc => $composableBuilder(
    column: $table.claimedAtUtc,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveSessionsTable,
          ActiveSession,
          $$ActiveSessionsTableFilterComposer,
          $$ActiveSessionsTableOrderingComposer,
          $$ActiveSessionsTableAnnotationComposer,
          $$ActiveSessionsTableCreateCompanionBuilder,
          $$ActiveSessionsTableUpdateCompanionBuilder,
          (ActiveSession, $$ActiveSessionsTableReferences),
          ActiveSession,
          PrefetchHooks Function({bool matchId})
        > {
  $$ActiveSessionsTableTableManager(
    _$AppDatabase db,
    $ActiveSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<DateTime> claimedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSessionsCompanion(
                id: id,
                matchId: matchId,
                claimedAtUtc: claimedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String matchId,
                Value<DateTime> claimedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSessionsCompanion.insert(
                id: id,
                matchId: matchId,
                claimedAtUtc: claimedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActiveSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$ActiveSessionsTableReferences
                                    ._matchIdTable(db),
                                referencedColumn:
                                    $$ActiveSessionsTableReferences
                                        ._matchIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActiveSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveSessionsTable,
      ActiveSession,
      $$ActiveSessionsTableFilterComposer,
      $$ActiveSessionsTableOrderingComposer,
      $$ActiveSessionsTableAnnotationComposer,
      $$ActiveSessionsTableCreateCompanionBuilder,
      $$ActiveSessionsTableUpdateCompanionBuilder,
      (ActiveSession, $$ActiveSessionsTableReferences),
      ActiveSession,
      PrefetchHooks Function({bool matchId})
    >;
typedef $$MatchEventsTableCreateCompanionBuilder =
    MatchEventsCompanion Function({
      required String id,
      required String matchId,
      required String type,
      Value<String?> side,
      Value<int> points,
      Value<String?> outcome,
      Value<int?> matchClockPositionSeconds,
      required DateTime occurredAt,
      Value<String?> note,
      Value<String?> customLabel,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$MatchEventsTableUpdateCompanionBuilder =
    MatchEventsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> type,
      Value<String?> side,
      Value<int> points,
      Value<String?> outcome,
      Value<int?> matchClockPositionSeconds,
      Value<DateTime> occurredAt,
      Value<String?> note,
      Value<String?> customLabel,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$MatchEventsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchEventsTable, MatchEventRow> {
  $$MatchEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('match_events__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ShotLocationsTable, List<ShotLocation>>
  _shotLocationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shotLocations,
    aliasName: 'match_events__id__shot_locations__event_id',
  );

  $$ShotLocationsTableProcessedTableManager get shotLocationsRefs {
    final manager = $$ShotLocationsTableTableManager(
      $_db,
      $_db.shotLocations,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotLocationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PossessionSegmentsTable, List<PossessionSegment>>
  _startedPossessionSegmentsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.possessionSegments,
        aliasName: 'match_events__id__possession_segments__started_at_event_id',
      );

  $$PossessionSegmentsTableProcessedTableManager get startedPossessionSegments {
    final manager =
        $$PossessionSegmentsTableTableManager(
          $_db,
          $_db.possessionSegments,
        ).filter(
          (f) => f.startedAtEventId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _startedPossessionSegmentsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PossessionSegmentsTable, List<PossessionSegment>>
  _endedPossessionSegmentsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.possessionSegments,
        aliasName: 'match_events__id__possession_segments__ended_at_event_id',
      );

  $$PossessionSegmentsTableProcessedTableManager get endedPossessionSegments {
    final manager = $$PossessionSegmentsTableTableManager(
      $_db,
      $_db.possessionSegments,
    ).filter((f) => f.endedAtEventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _endedPossessionSegmentsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchEventsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchClockPositionSeconds => $composableBuilder(
    column: $table.matchClockPositionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customLabel => $composableBuilder(
    column: $table.customLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> shotLocationsRefs(
    Expression<bool> Function($$ShotLocationsTableFilterComposer f) f,
  ) {
    final $$ShotLocationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotLocations,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotLocationsTableFilterComposer(
            $db: $db,
            $table: $db.shotLocations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> startedPossessionSegments(
    Expression<bool> Function($$PossessionSegmentsTableFilterComposer f) f,
  ) {
    final $$PossessionSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.possessionSegments,
      getReferencedColumn: (t) => t.startedAtEventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PossessionSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.possessionSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> endedPossessionSegments(
    Expression<bool> Function($$PossessionSegmentsTableFilterComposer f) f,
  ) {
    final $$PossessionSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.possessionSegments,
      getReferencedColumn: (t) => t.endedAtEventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PossessionSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.possessionSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchClockPositionSeconds => $composableBuilder(
    column: $table.matchClockPositionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customLabel => $composableBuilder(
    column: $table.customLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get matchClockPositionSeconds => $composableBuilder(
    column: $table.matchClockPositionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get customLabel => $composableBuilder(
    column: $table.customLabel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> shotLocationsRefs<T extends Object>(
    Expression<T> Function($$ShotLocationsTableAnnotationComposer a) f,
  ) {
    final $$ShotLocationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotLocations,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotLocationsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotLocations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> startedPossessionSegments<T extends Object>(
    Expression<T> Function($$PossessionSegmentsTableAnnotationComposer a) f,
  ) {
    final $$PossessionSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.possessionSegments,
          getReferencedColumn: (t) => t.startedAtEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PossessionSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.possessionSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> endedPossessionSegments<T extends Object>(
    Expression<T> Function($$PossessionSegmentsTableAnnotationComposer a) f,
  ) {
    final $$PossessionSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.possessionSegments,
          getReferencedColumn: (t) => t.endedAtEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PossessionSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.possessionSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MatchEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchEventsTable,
          MatchEventRow,
          $$MatchEventsTableFilterComposer,
          $$MatchEventsTableOrderingComposer,
          $$MatchEventsTableAnnotationComposer,
          $$MatchEventsTableCreateCompanionBuilder,
          $$MatchEventsTableUpdateCompanionBuilder,
          (MatchEventRow, $$MatchEventsTableReferences),
          MatchEventRow,
          PrefetchHooks Function({
            bool matchId,
            bool shotLocationsRefs,
            bool startedPossessionSegments,
            bool endedPossessionSegments,
          })
        > {
  $$MatchEventsTableTableManager(_$AppDatabase db, $MatchEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> side = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> matchClockPositionSeconds = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> customLabel = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventsCompanion(
                id: id,
                matchId: matchId,
                type: type,
                side: side,
                points: points,
                outcome: outcome,
                matchClockPositionSeconds: matchClockPositionSeconds,
                occurredAt: occurredAt,
                note: note,
                customLabel: customLabel,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String type,
                Value<String?> side = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> matchClockPositionSeconds = const Value.absent(),
                required DateTime occurredAt,
                Value<String?> note = const Value.absent(),
                Value<String?> customLabel = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventsCompanion.insert(
                id: id,
                matchId: matchId,
                type: type,
                side: side,
                points: points,
                outcome: outcome,
                matchClockPositionSeconds: matchClockPositionSeconds,
                occurredAt: occurredAt,
                note: note,
                customLabel: customLabel,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                matchId = false,
                shotLocationsRefs = false,
                startedPossessionSegments = false,
                endedPossessionSegments = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (shotLocationsRefs) db.shotLocations,
                    if (startedPossessionSegments) db.possessionSegments,
                    if (endedPossessionSegments) db.possessionSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (matchId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchId,
                                    referencedTable:
                                        $$MatchEventsTableReferences
                                            ._matchIdTable(db),
                                    referencedColumn:
                                        $$MatchEventsTableReferences
                                            ._matchIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (shotLocationsRefs)
                        await $_getPrefetchedData<
                          MatchEventRow,
                          $MatchEventsTable,
                          ShotLocation
                        >(
                          currentTable: table,
                          referencedTable: $$MatchEventsTableReferences
                              ._shotLocationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotLocationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (startedPossessionSegments)
                        await $_getPrefetchedData<
                          MatchEventRow,
                          $MatchEventsTable,
                          PossessionSegment
                        >(
                          currentTable: table,
                          referencedTable: $$MatchEventsTableReferences
                              ._startedPossessionSegmentsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).startedPossessionSegments,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.startedAtEventId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (endedPossessionSegments)
                        await $_getPrefetchedData<
                          MatchEventRow,
                          $MatchEventsTable,
                          PossessionSegment
                        >(
                          currentTable: table,
                          referencedTable: $$MatchEventsTableReferences
                              ._endedPossessionSegmentsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).endedPossessionSegments,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.endedAtEventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MatchEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchEventsTable,
      MatchEventRow,
      $$MatchEventsTableFilterComposer,
      $$MatchEventsTableOrderingComposer,
      $$MatchEventsTableAnnotationComposer,
      $$MatchEventsTableCreateCompanionBuilder,
      $$MatchEventsTableUpdateCompanionBuilder,
      (MatchEventRow, $$MatchEventsTableReferences),
      MatchEventRow,
      PrefetchHooks Function({
        bool matchId,
        bool shotLocationsRefs,
        bool startedPossessionSegments,
        bool endedPossessionSegments,
      })
    >;
typedef $$ShotLocationsTableCreateCompanionBuilder =
    ShotLocationsCompanion Function({
      required String id,
      required String matchId,
      required String eventId,
      required double x,
      required double y,
      Value<bool> isConfirmed,
      Value<int> rowid,
    });
typedef $$ShotLocationsTableUpdateCompanionBuilder =
    ShotLocationsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> eventId,
      Value<double> x,
      Value<double> y,
      Value<bool> isConfirmed,
      Value<int> rowid,
    });

final class $$ShotLocationsTableReferences
    extends BaseReferences<_$AppDatabase, $ShotLocationsTable, ShotLocation> {
  $$ShotLocationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('shot_locations__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MatchEventsTable _eventIdTable(_$AppDatabase db) =>
      db.matchEvents.createAlias('shot_locations__event_id__match_events__id');

  $$MatchEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotLocationsTableFilterComposer
    extends Composer<_$AppDatabase, $ShotLocationsTable> {
  $$ShotLocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isConfirmed => $composableBuilder(
    column: $table.isConfirmed,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableFilterComposer get eventId {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotLocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShotLocationsTable> {
  $$ShotLocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isConfirmed => $composableBuilder(
    column: $table.isConfirmed,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableOrderingComposer get eventId {
    final $$MatchEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableOrderingComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotLocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShotLocationsTable> {
  $$ShotLocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<bool> get isConfirmed => $composableBuilder(
    column: $table.isConfirmed,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableAnnotationComposer get eventId {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotLocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShotLocationsTable,
          ShotLocation,
          $$ShotLocationsTableFilterComposer,
          $$ShotLocationsTableOrderingComposer,
          $$ShotLocationsTableAnnotationComposer,
          $$ShotLocationsTableCreateCompanionBuilder,
          $$ShotLocationsTableUpdateCompanionBuilder,
          (ShotLocation, $$ShotLocationsTableReferences),
          ShotLocation,
          PrefetchHooks Function({bool matchId, bool eventId})
        > {
  $$ShotLocationsTableTableManager(_$AppDatabase db, $ShotLocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotLocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotLocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotLocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<bool> isConfirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShotLocationsCompanion(
                id: id,
                matchId: matchId,
                eventId: eventId,
                x: x,
                y: y,
                isConfirmed: isConfirmed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String eventId,
                required double x,
                required double y,
                Value<bool> isConfirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShotLocationsCompanion.insert(
                id: id,
                matchId: matchId,
                eventId: eventId,
                x: x,
                y: y,
                isConfirmed: isConfirmed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotLocationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false, eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$ShotLocationsTableReferences
                                    ._matchIdTable(db),
                                referencedColumn: $$ShotLocationsTableReferences
                                    ._matchIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$ShotLocationsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$ShotLocationsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotLocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShotLocationsTable,
      ShotLocation,
      $$ShotLocationsTableFilterComposer,
      $$ShotLocationsTableOrderingComposer,
      $$ShotLocationsTableAnnotationComposer,
      $$ShotLocationsTableCreateCompanionBuilder,
      $$ShotLocationsTableUpdateCompanionBuilder,
      (ShotLocation, $$ShotLocationsTableReferences),
      ShotLocation,
      PrefetchHooks Function({bool matchId, bool eventId})
    >;
typedef $$RuleTemplatesTableCreateCompanionBuilder =
    RuleTemplatesCompanion Function({
      required String id,
      required String name,
      required String scoreButtonsJson,
      Value<int?> targetScore,
      Value<int?> timeLimitSeconds,
      Value<bool> winByTwo,
      Value<int?> foulLimit,
      Value<String> customEventTypesJson,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });
typedef $$RuleTemplatesTableUpdateCompanionBuilder =
    RuleTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> scoreButtonsJson,
      Value<int?> targetScore,
      Value<int?> timeLimitSeconds,
      Value<bool> winByTwo,
      Value<int?> foulLimit,
      Value<String> customEventTypesJson,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });

class $$RuleTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $RuleTemplatesTable> {
  $$RuleTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreButtonsJson => $composableBuilder(
    column: $table.scoreButtonsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get winByTwo => $composableBuilder(
    column: $table.winByTwo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foulLimit => $composableBuilder(
    column: $table.foulLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customEventTypesJson => $composableBuilder(
    column: $table.customEventTypesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleTemplatesTable> {
  $$RuleTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreButtonsJson => $composableBuilder(
    column: $table.scoreButtonsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get winByTwo => $composableBuilder(
    column: $table.winByTwo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foulLimit => $composableBuilder(
    column: $table.foulLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customEventTypesJson => $composableBuilder(
    column: $table.customEventTypesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleTemplatesTable> {
  $$RuleTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get scoreButtonsJson => $composableBuilder(
    column: $table.scoreButtonsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get winByTwo =>
      $composableBuilder(column: $table.winByTwo, builder: (column) => column);

  GeneratedColumn<int> get foulLimit =>
      $composableBuilder(column: $table.foulLimit, builder: (column) => column);

  GeneratedColumn<String> get customEventTypesJson => $composableBuilder(
    column: $table.customEventTypesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);
}

class $$RuleTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleTemplatesTable,
          RuleTemplateRow,
          $$RuleTemplatesTableFilterComposer,
          $$RuleTemplatesTableOrderingComposer,
          $$RuleTemplatesTableAnnotationComposer,
          $$RuleTemplatesTableCreateCompanionBuilder,
          $$RuleTemplatesTableUpdateCompanionBuilder,
          (
            RuleTemplateRow,
            BaseReferences<_$AppDatabase, $RuleTemplatesTable, RuleTemplateRow>,
          ),
          RuleTemplateRow,
          PrefetchHooks Function()
        > {
  $$RuleTemplatesTableTableManager(_$AppDatabase db, $RuleTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> scoreButtonsJson = const Value.absent(),
                Value<int?> targetScore = const Value.absent(),
                Value<int?> timeLimitSeconds = const Value.absent(),
                Value<bool> winByTwo = const Value.absent(),
                Value<int?> foulLimit = const Value.absent(),
                Value<String> customEventTypesJson = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleTemplatesCompanion(
                id: id,
                name: name,
                scoreButtonsJson: scoreButtonsJson,
                targetScore: targetScore,
                timeLimitSeconds: timeLimitSeconds,
                winByTwo: winByTwo,
                foulLimit: foulLimit,
                customEventTypesJson: customEventTypesJson,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String scoreButtonsJson,
                Value<int?> targetScore = const Value.absent(),
                Value<int?> timeLimitSeconds = const Value.absent(),
                Value<bool> winByTwo = const Value.absent(),
                Value<int?> foulLimit = const Value.absent(),
                Value<String> customEventTypesJson = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleTemplatesCompanion.insert(
                id: id,
                name: name,
                scoreButtonsJson: scoreButtonsJson,
                targetScore: targetScore,
                timeLimitSeconds: timeLimitSeconds,
                winByTwo: winByTwo,
                foulLimit: foulLimit,
                customEventTypesJson: customEventTypesJson,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleTemplatesTable,
      RuleTemplateRow,
      $$RuleTemplatesTableFilterComposer,
      $$RuleTemplatesTableOrderingComposer,
      $$RuleTemplatesTableAnnotationComposer,
      $$RuleTemplatesTableCreateCompanionBuilder,
      $$RuleTemplatesTableUpdateCompanionBuilder,
      (
        RuleTemplateRow,
        BaseReferences<_$AppDatabase, $RuleTemplatesTable, RuleTemplateRow>,
      ),
      RuleTemplateRow,
      PrefetchHooks Function()
    >;
typedef $$PossessionSegmentsTableCreateCompanionBuilder =
    PossessionSegmentsCompanion Function({
      required String id,
      required String matchId,
      required String side,
      required String startedAtEventId,
      Value<String?> endedAtEventId,
      Value<String?> reason,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$PossessionSegmentsTableUpdateCompanionBuilder =
    PossessionSegmentsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> side,
      Value<String> startedAtEventId,
      Value<String?> endedAtEventId,
      Value<String?> reason,
      Value<String> source,
      Value<int> rowid,
    });

final class $$PossessionSegmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PossessionSegmentsTable,
          PossessionSegment
        > {
  $$PossessionSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('possession_segments__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MatchEventsTable _startedAtEventIdTable(_$AppDatabase db) =>
      db.matchEvents.createAlias(
        'possession_segments__started_at_event_id__match_events__id',
      );

  $$MatchEventsTableProcessedTableManager get startedAtEventId {
    final $_column = $_itemColumn<String>('started_at_event_id')!;

    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_startedAtEventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MatchEventsTable _endedAtEventIdTable(_$AppDatabase db) => db
      .matchEvents
      .createAlias('possession_segments__ended_at_event_id__match_events__id');

  $$MatchEventsTableProcessedTableManager? get endedAtEventId {
    final $_column = $_itemColumn<String>('ended_at_event_id');
    if ($_column == null) return null;
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_endedAtEventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PossessionSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $PossessionSegmentsTable> {
  $$PossessionSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableFilterComposer get startedAtEventId {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableFilterComposer get endedAtEventId {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.endedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PossessionSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PossessionSegmentsTable> {
  $$PossessionSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableOrderingComposer get startedAtEventId {
    final $$MatchEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableOrderingComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableOrderingComposer get endedAtEventId {
    final $$MatchEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.endedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableOrderingComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PossessionSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PossessionSegmentsTable> {
  $$PossessionSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableAnnotationComposer get startedAtEventId {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MatchEventsTableAnnotationComposer get endedAtEventId {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.endedAtEventId,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PossessionSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PossessionSegmentsTable,
          PossessionSegment,
          $$PossessionSegmentsTableFilterComposer,
          $$PossessionSegmentsTableOrderingComposer,
          $$PossessionSegmentsTableAnnotationComposer,
          $$PossessionSegmentsTableCreateCompanionBuilder,
          $$PossessionSegmentsTableUpdateCompanionBuilder,
          (PossessionSegment, $$PossessionSegmentsTableReferences),
          PossessionSegment,
          PrefetchHooks Function({
            bool matchId,
            bool startedAtEventId,
            bool endedAtEventId,
          })
        > {
  $$PossessionSegmentsTableTableManager(
    _$AppDatabase db,
    $PossessionSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PossessionSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PossessionSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PossessionSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> side = const Value.absent(),
                Value<String> startedAtEventId = const Value.absent(),
                Value<String?> endedAtEventId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PossessionSegmentsCompanion(
                id: id,
                matchId: matchId,
                side: side,
                startedAtEventId: startedAtEventId,
                endedAtEventId: endedAtEventId,
                reason: reason,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String side,
                required String startedAtEventId,
                Value<String?> endedAtEventId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PossessionSegmentsCompanion.insert(
                id: id,
                matchId: matchId,
                side: side,
                startedAtEventId: startedAtEventId,
                endedAtEventId: endedAtEventId,
                reason: reason,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PossessionSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                matchId = false,
                startedAtEventId = false,
                endedAtEventId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (matchId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchId,
                                    referencedTable:
                                        $$PossessionSegmentsTableReferences
                                            ._matchIdTable(db),
                                    referencedColumn:
                                        $$PossessionSegmentsTableReferences
                                            ._matchIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (startedAtEventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.startedAtEventId,
                                    referencedTable:
                                        $$PossessionSegmentsTableReferences
                                            ._startedAtEventIdTable(db),
                                    referencedColumn:
                                        $$PossessionSegmentsTableReferences
                                            ._startedAtEventIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (endedAtEventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.endedAtEventId,
                                    referencedTable:
                                        $$PossessionSegmentsTableReferences
                                            ._endedAtEventIdTable(db),
                                    referencedColumn:
                                        $$PossessionSegmentsTableReferences
                                            ._endedAtEventIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PossessionSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PossessionSegmentsTable,
      PossessionSegment,
      $$PossessionSegmentsTableFilterComposer,
      $$PossessionSegmentsTableOrderingComposer,
      $$PossessionSegmentsTableAnnotationComposer,
      $$PossessionSegmentsTableCreateCompanionBuilder,
      $$PossessionSegmentsTableUpdateCompanionBuilder,
      (PossessionSegment, $$PossessionSegmentsTableReferences),
      PossessionSegment,
      PrefetchHooks Function({
        bool matchId,
        bool startedAtEventId,
        bool endedAtEventId,
      })
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      required String id,
      required String matchId,
      required String targetId,
      required String action,
      required String beforeJson,
      required String afterJson,
      Value<String?> reason,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> targetId,
      Value<String> action,
      Value<String> beforeJson,
      Value<String> afterJson,
      Value<String?> reason,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AuditLogsTableReferences
    extends BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog> {
  $$AuditLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias('audit_logs__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterJson =>
      $composableBuilder(column: $table.afterJson, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, $$AuditLogsTableReferences),
          AuditLog,
          PrefetchHooks Function({bool matchId})
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> beforeJson = const Value.absent(),
                Value<String> afterJson = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                matchId: matchId,
                targetId: targetId,
                action: action,
                beforeJson: beforeJson,
                afterJson: afterJson,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String targetId,
                required String action,
                required String beforeJson,
                required String afterJson,
                Value<String?> reason = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                matchId: matchId,
                targetId: targetId,
                action: action,
                beforeJson: beforeJson,
                afterJson: afterJson,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$AuditLogsTableReferences
                                    ._matchIdTable(db),
                                referencedColumn: $$AuditLogsTableReferences
                                    ._matchIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, $$AuditLogsTableReferences),
      AuditLog,
      PrefetchHooks Function({bool matchId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String valueJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$PlayerAnalyticsSnapshotsTableCreateCompanionBuilder =
    PlayerAnalyticsSnapshotsCompanion Function({
      required String matchId,
      required String playerId,
      Value<String?> opponentPlayerId,
      required DateTime playedAtUtc,
      required int playerScore,
      required int opponentScore,
      required int fieldGoalMade,
      required int fieldGoalAttempts,
      required int freeThrowMade,
      required int freeThrowAttempts,
      required String trackingCoverage,
      required int confirmedLocationCount,
      required int locatableLocationCount,
      required String zoneDistributionJson,
      required int calculatorVersion,
      required String sourceSha256,
      Value<int> rowid,
    });
typedef $$PlayerAnalyticsSnapshotsTableUpdateCompanionBuilder =
    PlayerAnalyticsSnapshotsCompanion Function({
      Value<String> matchId,
      Value<String> playerId,
      Value<String?> opponentPlayerId,
      Value<DateTime> playedAtUtc,
      Value<int> playerScore,
      Value<int> opponentScore,
      Value<int> fieldGoalMade,
      Value<int> fieldGoalAttempts,
      Value<int> freeThrowMade,
      Value<int> freeThrowAttempts,
      Value<String> trackingCoverage,
      Value<int> confirmedLocationCount,
      Value<int> locatableLocationCount,
      Value<String> zoneDistributionJson,
      Value<int> calculatorVersion,
      Value<String> sourceSha256,
      Value<int> rowid,
    });

final class $$PlayerAnalyticsSnapshotsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlayerAnalyticsSnapshotsTable,
          PlayerAnalyticsSnapshotRow
        > {
  $$PlayerAnalyticsSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) => db.matches
      .createAlias('player_analytics_snapshots__match_id__matches__id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _playerIdTable(_$AppDatabase db) => db.players
      .createAlias('player_analytics_snapshots__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _opponentPlayerIdTable(_$AppDatabase db) =>
      db.players.createAlias(
        'player_analytics_snapshots__opponent_player_id__players__id',
      );

  $$PlayersTableProcessedTableManager? get opponentPlayerId {
    final $_column = $_itemColumn<String>('opponent_player_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_opponentPlayerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayerAnalyticsSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerAnalyticsSnapshotsTable> {
  $$PlayerAnalyticsSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerScore => $composableBuilder(
    column: $table.playerScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get opponentScore => $composableBuilder(
    column: $table.opponentScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fieldGoalMade => $composableBuilder(
    column: $table.fieldGoalMade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fieldGoalAttempts => $composableBuilder(
    column: $table.fieldGoalAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freeThrowMade => $composableBuilder(
    column: $table.freeThrowMade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freeThrowAttempts => $composableBuilder(
    column: $table.freeThrowAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmedLocationCount => $composableBuilder(
    column: $table.confirmedLocationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get locatableLocationCount => $composableBuilder(
    column: $table.locatableLocationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneDistributionJson => $composableBuilder(
    column: $table.zoneDistributionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calculatorVersion => $composableBuilder(
    column: $table.calculatorVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get opponentPlayerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opponentPlayerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerAnalyticsSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerAnalyticsSnapshotsTable> {
  $$PlayerAnalyticsSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerScore => $composableBuilder(
    column: $table.playerScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get opponentScore => $composableBuilder(
    column: $table.opponentScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fieldGoalMade => $composableBuilder(
    column: $table.fieldGoalMade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fieldGoalAttempts => $composableBuilder(
    column: $table.fieldGoalAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freeThrowMade => $composableBuilder(
    column: $table.freeThrowMade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freeThrowAttempts => $composableBuilder(
    column: $table.freeThrowAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedLocationCount => $composableBuilder(
    column: $table.confirmedLocationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locatableLocationCount => $composableBuilder(
    column: $table.locatableLocationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneDistributionJson => $composableBuilder(
    column: $table.zoneDistributionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calculatorVersion => $composableBuilder(
    column: $table.calculatorVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get opponentPlayerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opponentPlayerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerAnalyticsSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerAnalyticsSnapshotsTable> {
  $$PlayerAnalyticsSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playerScore => $composableBuilder(
    column: $table.playerScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get opponentScore => $composableBuilder(
    column: $table.opponentScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fieldGoalMade => $composableBuilder(
    column: $table.fieldGoalMade,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fieldGoalAttempts => $composableBuilder(
    column: $table.fieldGoalAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freeThrowMade => $composableBuilder(
    column: $table.freeThrowMade,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freeThrowAttempts => $composableBuilder(
    column: $table.freeThrowAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackingCoverage => $composableBuilder(
    column: $table.trackingCoverage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confirmedLocationCount => $composableBuilder(
    column: $table.confirmedLocationCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get locatableLocationCount => $composableBuilder(
    column: $table.locatableLocationCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zoneDistributionJson => $composableBuilder(
    column: $table.zoneDistributionJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calculatorVersion => $composableBuilder(
    column: $table.calculatorVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get opponentPlayerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opponentPlayerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerAnalyticsSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerAnalyticsSnapshotsTable,
          PlayerAnalyticsSnapshotRow,
          $$PlayerAnalyticsSnapshotsTableFilterComposer,
          $$PlayerAnalyticsSnapshotsTableOrderingComposer,
          $$PlayerAnalyticsSnapshotsTableAnnotationComposer,
          $$PlayerAnalyticsSnapshotsTableCreateCompanionBuilder,
          $$PlayerAnalyticsSnapshotsTableUpdateCompanionBuilder,
          (
            PlayerAnalyticsSnapshotRow,
            $$PlayerAnalyticsSnapshotsTableReferences,
          ),
          PlayerAnalyticsSnapshotRow,
          PrefetchHooks Function({
            bool matchId,
            bool playerId,
            bool opponentPlayerId,
          })
        > {
  $$PlayerAnalyticsSnapshotsTableTableManager(
    _$AppDatabase db,
    $PlayerAnalyticsSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerAnalyticsSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlayerAnalyticsSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlayerAnalyticsSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> matchId = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String?> opponentPlayerId = const Value.absent(),
                Value<DateTime> playedAtUtc = const Value.absent(),
                Value<int> playerScore = const Value.absent(),
                Value<int> opponentScore = const Value.absent(),
                Value<int> fieldGoalMade = const Value.absent(),
                Value<int> fieldGoalAttempts = const Value.absent(),
                Value<int> freeThrowMade = const Value.absent(),
                Value<int> freeThrowAttempts = const Value.absent(),
                Value<String> trackingCoverage = const Value.absent(),
                Value<int> confirmedLocationCount = const Value.absent(),
                Value<int> locatableLocationCount = const Value.absent(),
                Value<String> zoneDistributionJson = const Value.absent(),
                Value<int> calculatorVersion = const Value.absent(),
                Value<String> sourceSha256 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerAnalyticsSnapshotsCompanion(
                matchId: matchId,
                playerId: playerId,
                opponentPlayerId: opponentPlayerId,
                playedAtUtc: playedAtUtc,
                playerScore: playerScore,
                opponentScore: opponentScore,
                fieldGoalMade: fieldGoalMade,
                fieldGoalAttempts: fieldGoalAttempts,
                freeThrowMade: freeThrowMade,
                freeThrowAttempts: freeThrowAttempts,
                trackingCoverage: trackingCoverage,
                confirmedLocationCount: confirmedLocationCount,
                locatableLocationCount: locatableLocationCount,
                zoneDistributionJson: zoneDistributionJson,
                calculatorVersion: calculatorVersion,
                sourceSha256: sourceSha256,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String matchId,
                required String playerId,
                Value<String?> opponentPlayerId = const Value.absent(),
                required DateTime playedAtUtc,
                required int playerScore,
                required int opponentScore,
                required int fieldGoalMade,
                required int fieldGoalAttempts,
                required int freeThrowMade,
                required int freeThrowAttempts,
                required String trackingCoverage,
                required int confirmedLocationCount,
                required int locatableLocationCount,
                required String zoneDistributionJson,
                required int calculatorVersion,
                required String sourceSha256,
                Value<int> rowid = const Value.absent(),
              }) => PlayerAnalyticsSnapshotsCompanion.insert(
                matchId: matchId,
                playerId: playerId,
                opponentPlayerId: opponentPlayerId,
                playedAtUtc: playedAtUtc,
                playerScore: playerScore,
                opponentScore: opponentScore,
                fieldGoalMade: fieldGoalMade,
                fieldGoalAttempts: fieldGoalAttempts,
                freeThrowMade: freeThrowMade,
                freeThrowAttempts: freeThrowAttempts,
                trackingCoverage: trackingCoverage,
                confirmedLocationCount: confirmedLocationCount,
                locatableLocationCount: locatableLocationCount,
                zoneDistributionJson: zoneDistributionJson,
                calculatorVersion: calculatorVersion,
                sourceSha256: sourceSha256,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayerAnalyticsSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({matchId = false, playerId = false, opponentPlayerId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (matchId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchId,
                                    referencedTable:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._matchIdTable(db),
                                    referencedColumn:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._matchIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (playerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.playerId,
                                    referencedTable:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._playerIdTable(db),
                                    referencedColumn:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._playerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (opponentPlayerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.opponentPlayerId,
                                    referencedTable:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._opponentPlayerIdTable(db),
                                    referencedColumn:
                                        $$PlayerAnalyticsSnapshotsTableReferences
                                            ._opponentPlayerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PlayerAnalyticsSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerAnalyticsSnapshotsTable,
      PlayerAnalyticsSnapshotRow,
      $$PlayerAnalyticsSnapshotsTableFilterComposer,
      $$PlayerAnalyticsSnapshotsTableOrderingComposer,
      $$PlayerAnalyticsSnapshotsTableAnnotationComposer,
      $$PlayerAnalyticsSnapshotsTableCreateCompanionBuilder,
      $$PlayerAnalyticsSnapshotsTableUpdateCompanionBuilder,
      (PlayerAnalyticsSnapshotRow, $$PlayerAnalyticsSnapshotsTableReferences),
      PlayerAnalyticsSnapshotRow,
      PrefetchHooks Function({
        bool matchId,
        bool playerId,
        bool opponentPlayerId,
      })
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$MatchSeriesTableTableManager get matchSeries =>
      $$MatchSeriesTableTableManager(_db, _db.matchSeries);
  $$SeriesMatchesTableTableManager get seriesMatches =>
      $$SeriesMatchesTableTableManager(_db, _db.seriesMatches);
  $$MatchParticipantsTableTableManager get matchParticipants =>
      $$MatchParticipantsTableTableManager(_db, _db.matchParticipants);
  $$MatchClocksTableTableManager get matchClocks =>
      $$MatchClocksTableTableManager(_db, _db.matchClocks);
  $$ActiveSessionsTableTableManager get activeSessions =>
      $$ActiveSessionsTableTableManager(_db, _db.activeSessions);
  $$MatchEventsTableTableManager get matchEvents =>
      $$MatchEventsTableTableManager(_db, _db.matchEvents);
  $$ShotLocationsTableTableManager get shotLocations =>
      $$ShotLocationsTableTableManager(_db, _db.shotLocations);
  $$RuleTemplatesTableTableManager get ruleTemplates =>
      $$RuleTemplatesTableTableManager(_db, _db.ruleTemplates);
  $$PossessionSegmentsTableTableManager get possessionSegments =>
      $$PossessionSegmentsTableTableManager(_db, _db.possessionSegments);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$PlayerAnalyticsSnapshotsTableTableManager get playerAnalyticsSnapshots =>
      $$PlayerAnalyticsSnapshotsTableTableManager(
        _db,
        _db.playerAnalyticsSnapshots,
      );
}
