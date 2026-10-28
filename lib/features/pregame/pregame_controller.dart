import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

const defaultRedPlayerName = '红方';
const defaultBluePlayerName = '蓝方';

/// The validation vocabulary used by both the pre-game controller and the
/// start surface. Keeping the errors typed means the widget can provide
/// localized copy without guessing from exception strings.
enum PregameValidationError {
  redParticipantRequired,
  blueParticipantRequired,
  duplicatePlayerProfile,
  redPlayerProfileMissing,
  bluePlayerProfileMissing,
  recordingModeRequired,
  countdownTimerRequired,
  invalidCountdownDuration,
}

String pregameValidationErrorMessage(PregameValidationError error) {
  return switch (error) {
    PregameValidationError.redParticipantRequired => '请输入红方姓名。',
    PregameValidationError.blueParticipantRequired => '请输入蓝方姓名。',
    PregameValidationError.duplicatePlayerProfile => '同一球员档案不能同时用于红方和蓝方。',
    PregameValidationError.redPlayerProfileMissing =>
      '红方所选球员档案已不存在，请重新选择或改用临时姓名。',
    PregameValidationError.bluePlayerProfileMissing =>
      '蓝方所选球员档案已不存在，请重新选择或改用临时姓名。',
    PregameValidationError.recordingModeRequired => '请选择记录模式后再开始比赛。',
    PregameValidationError.countdownTimerRequired => '倒计时必须先打开计时开关。',
    PregameValidationError.invalidCountdownDuration => '倒计时分钟数必须是 1 到 180 分钟。',
  };
}

class PregameValidationResult {
  const PregameValidationResult(this.errors);

  final List<PregameValidationError> errors;

  bool get isValid => errors.isEmpty;
}

class MatchSetup {
  const MatchSetup({
    required this.matchId,
    required this.redName,
    required this.blueName,
    required this.ruleTemplateId,
    this.ruleTemplateName,
    required this.targetScore,
    required this.timerEnabled,
    required this.timeLimitMinutes,
    required this.winByTwo,
    this.scoreButtons = const [1, 2, 3],
    this.foulLimit,
    this.possessionHintEnabled = false,
    this.possessionPolicy = PossessionPolicy.manual,
    this.customEventTypes = const [],
    this.redPlayerProfileId,
    this.bluePlayerProfileId,
    this.recordingMode = RecordingMode.simple,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.clockMode = ClockMode.countUp,
  });

  final String matchId;
  final String redName;
  final String blueName;
  final String? redPlayerProfileId;
  final String? bluePlayerProfileId;
  final String ruleTemplateId;
  final String? ruleTemplateName;
  final int? targetScore;
  final bool timerEnabled;
  final int timeLimitMinutes;
  final bool winByTwo;
  final List<int> scoreButtons;
  final int? foulLimit;
  final bool possessionHintEnabled;
  final PossessionPolicy possessionPolicy;
  final List<String> customEventTypes;
  final RecordingMode? recordingMode;
  final TrackingCoverage trackingCoverage;
  final ClockMode clockMode;
}

enum GoalScoringMode { free, target }

class PregameState {
  const PregameState({
    this.redName = defaultRedPlayerName,
    this.blueName = defaultBluePlayerName,
    this.redPlayerProfileId,
    this.bluePlayerProfileId,
    this.ruleTemplateId = 'free',
    this.timerEnabled = false,
    this.clockMode = ClockMode.countUp,
    this.goalScoringMode = GoalScoringMode.free,
    this.targetScore = 11,
    this.targetScoreOverridden = false,
    this.timeLimitMinutes = 10,
    this.countdownMinutesText = '10',
    this.countdownDurationInputInvalid = false,
    this.winByTwo = false,
    this.recordingMode = RecordingMode.simple,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.advancedExpanded = false,
  });

  final String redName;
  final String blueName;
  final String? redPlayerProfileId;
  final String? bluePlayerProfileId;
  final String ruleTemplateId;
  final bool timerEnabled;
  final ClockMode clockMode;
  final GoalScoringMode goalScoringMode;
  final int targetScore;
  final bool targetScoreOverridden;
  final int timeLimitMinutes;
  final String countdownMinutesText;
  final bool countdownDurationInputInvalid;
  final bool winByTwo;
  final RecordingMode? recordingMode;
  final TrackingCoverage trackingCoverage;
  final bool advancedExpanded;

  PregameState copyWith({
    String? redName,
    String? blueName,
    String? redPlayerProfileId,
    String? bluePlayerProfileId,
    bool clearRedPlayerProfileId = false,
    bool clearBluePlayerProfileId = false,
    String? ruleTemplateId,
    bool? timerEnabled,
    ClockMode? clockMode,
    GoalScoringMode? goalScoringMode,
    int? targetScore,
    bool? targetScoreOverridden,
    int? timeLimitMinutes,
    String? countdownMinutesText,
    bool? countdownDurationInputInvalid,
    bool? winByTwo,
    RecordingMode? recordingMode,
    bool clearRecordingMode = false,
    TrackingCoverage? trackingCoverage,
    bool? advancedExpanded,
  }) {
    return PregameState(
      redName: redName ?? this.redName,
      blueName: blueName ?? this.blueName,
      redPlayerProfileId: clearRedPlayerProfileId
          ? null
          : redPlayerProfileId ?? this.redPlayerProfileId,
      bluePlayerProfileId: clearBluePlayerProfileId
          ? null
          : bluePlayerProfileId ?? this.bluePlayerProfileId,
      ruleTemplateId: ruleTemplateId ?? this.ruleTemplateId,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      clockMode: clockMode ?? this.clockMode,
      goalScoringMode: goalScoringMode ?? this.goalScoringMode,
      targetScore: targetScore ?? this.targetScore,
      targetScoreOverridden:
          targetScoreOverridden ?? this.targetScoreOverridden,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      countdownMinutesText: countdownMinutesText ?? this.countdownMinutesText,
      countdownDurationInputInvalid:
          countdownDurationInputInvalid ?? this.countdownDurationInputInvalid,
      winByTwo: winByTwo ?? this.winByTwo,
      recordingMode: clearRecordingMode
          ? null
          : recordingMode ?? this.recordingMode,
      trackingCoverage: trackingCoverage ?? this.trackingCoverage,
      advancedExpanded: advancedExpanded ?? this.advancedExpanded,
    );
  }
}

class PregameController {
  static const minTargetScore = 1;
  static const maxTargetScore = 999;

  PregameController({
    PregameState state = const PregameState(),
    List<RuleTemplate> templates = const [],
    List<Player> players = const [],
    MatchSetupPreset? initialPreset,
    String Function()? matchIdFactory,
  }) : _state = state,
       _templates = List.of(templates),
       _players = List.of(players),
       _matchIdFactory = matchIdFactory ?? _newMatchId {
    if (initialPreset != null) applyPreset(initialPreset);
  }

  PregameState _state;
  List<RuleTemplate> _templates;
  List<Player> _players;
  RuleTemplate? _presetRules;
  final String Function() _matchIdFactory;

  PregameState get state => _state;

  List<Player> get players => List.unmodifiable(_players);

  List<RuleTemplate> get templates => List.unmodifiable([
    for (final template in _templates)
      if (template.id != _presetRules?.id) template,
    ?_presetRules,
  ]);

  RuleTemplate? get selectedRules =>
      templates.where((item) => item.id == _state.ruleTemplateId).firstOrNull;

  void applyPreset(MatchSetupPreset preset) {
    _presetRules = preset.rules;
    _state = PregameState(
      redName: preset.red.nameSnapshot,
      blueName: preset.blue.nameSnapshot,
      redPlayerProfileId: preset.red.playerId,
      bluePlayerProfileId: preset.blue.playerId,
      ruleTemplateId: preset.rules.id,
      timerEnabled: preset.timerEnabled,
      clockMode: preset.clockMode,
      goalScoringMode: preset.rules.targetScore == null
          ? GoalScoringMode.free
          : GoalScoringMode.target,
      targetScore: (preset.rules.targetScore ?? 11).clamp(
        minTargetScore,
        maxTargetScore,
      ),
      timeLimitMinutes: preset.timeLimitMinutes,
      countdownMinutesText: '${preset.timeLimitMinutes}',
      winByTwo: false,
    );
  }

  void swapSides() {
    _state = _state.copyWith(
      redName: _state.blueName,
      blueName: _state.redName,
      redPlayerProfileId: _state.bluePlayerProfileId,
      bluePlayerProfileId: _state.redPlayerProfileId,
      clearRedPlayerProfileId: _state.bluePlayerProfileId == null,
      clearBluePlayerProfileId: _state.redPlayerProfileId == null,
    );
  }

  void setTemplates(List<RuleTemplate> templates) {
    _templates = List.of(templates);
    if (selectedRules != null) return;
    final fallback =
        _templates.where((item) => item.id == 'free').firstOrNull ??
        _templates.firstOrNull;
    if (fallback != null) setRuleTemplateId(fallback.id);
  }

  /// Updates the available profile list without changing already selected
  /// name snapshots. A match records what was shown at start, not a live
  /// nickname lookup.
  void setPlayers(List<Player> players) {
    _players = List.of(players);
  }

  void setRedName(String value) {
    _state = _state.copyWith(
      redName: value.trim(),
      clearRedPlayerProfileId: true,
    );
  }

  void setBlueName(String value) {
    _state = _state.copyWith(
      blueName: value.trim(),
      clearBluePlayerProfileId: true,
    );
  }

  /// Selects a stable profile for the red side. A false return means the
  /// selection was not applied (unknown profile or already used by blue).
  bool selectRedProfile(String? profileId) {
    return _selectProfile(profileId, red: true);
  }

  /// Selects a stable profile for the blue side. A false return means the
  /// selection was not applied (unknown profile or already used by red).
  bool selectBlueProfile(String? profileId) {
    return _selectProfile(profileId, red: false);
  }

  bool setRedPlayerProfile(Player? player) {
    return selectRedProfile(player?.id);
  }

  bool setBluePlayerProfile(Player? player) {
    return selectBlueProfile(player?.id);
  }

  void setRuleTemplateId(String value) {
    final selected = templates.where((item) => item.id == value).firstOrNull;
    _state = _state.copyWith(
      ruleTemplateId: value,
      timerEnabled: selected?.timeLimitSeconds != null
          ? true
          : _state.timerEnabled,
      goalScoringMode: selected?.targetScore == null
          ? GoalScoringMode.free
          : GoalScoringMode.target,
      targetScore: (selected?.targetScore ?? _state.targetScore).clamp(
        minTargetScore,
        maxTargetScore,
      ),
      targetScoreOverridden: false,
      clockMode: selected?.timeLimitSeconds != null
          ? ClockMode.countdown
          : ClockMode.countUp,
      timeLimitMinutes: selected?.timeLimitSeconds == null
          ? _state.timeLimitMinutes
          : selected!.timeLimitSeconds! ~/ 60,
      countdownMinutesText: selected?.timeLimitSeconds == null
          ? _state.countdownMinutesText
          : '${selected!.timeLimitSeconds! ~/ 60}',
      countdownDurationInputInvalid: false,
      winByTwo: false,
    );
  }

  void setRecordingMode(RecordingMode value) {
    _state = _state.copyWith(recordingMode: value);
  }

  void clearRecordingMode() {
    _state = _state.copyWith(clearRecordingMode: true);
  }

  void setTrackingCoverage(TrackingCoverage value) {
    _state = _state.copyWith(trackingCoverage: value);
  }

  void setClockMode(ClockMode value) {
    _state = _state.copyWith(clockMode: value);
  }

  void setTimerEnabled(bool value) {
    _state = _state.copyWith(
      timerEnabled: value,
      clockMode: value ? _state.clockMode : ClockMode.countUp,
    );
  }

  void setGoalScoringMode(GoalScoringMode value) {
    _state = _state.copyWith(goalScoringMode: value);
  }

  void setTargetScore(int value) {
    _state = _state.copyWith(
      targetScore: value.clamp(minTargetScore, maxTargetScore),
      targetScoreOverridden: true,
    );
  }

  void setTimeLimitMinutes(int value) {
    _state = _state.copyWith(
      timeLimitMinutes: value,
      countdownMinutesText: '$value',
      countdownDurationInputInvalid: false,
    );
  }

  void setCountdownMinutesText(String value) {
    final parsed = int.tryParse(value);
    _state = _state.copyWith(
      countdownMinutesText: value,
      timeLimitMinutes: parsed ?? _state.timeLimitMinutes,
      countdownDurationInputInvalid: value.trim().isEmpty || parsed == null,
    );
  }

  void setAdvancedExpanded(bool value) {
    _state = _state.copyWith(advancedExpanded: value);
  }

  PregameValidationResult validate() {
    final errors = <PregameValidationError>[];
    if (_state.redName.trim().isEmpty) {
      errors.add(PregameValidationError.redParticipantRequired);
    }
    if (_state.blueName.trim().isEmpty) {
      errors.add(PregameValidationError.blueParticipantRequired);
    }
    if (_state.redPlayerProfileId != null &&
        _state.redPlayerProfileId == _state.bluePlayerProfileId) {
      errors.add(PregameValidationError.duplicatePlayerProfile);
    }
    if (_state.redPlayerProfileId != null &&
        _findPlayer(_state.redPlayerProfileId!) == null) {
      errors.add(PregameValidationError.redPlayerProfileMissing);
    }
    if (_state.bluePlayerProfileId != null &&
        _findPlayer(_state.bluePlayerProfileId!) == null) {
      errors.add(PregameValidationError.bluePlayerProfileMissing);
    }
    if (_state.clockMode == ClockMode.countdown) {
      if (!_state.timerEnabled) {
        errors.add(PregameValidationError.countdownTimerRequired);
      }
      final parsed = int.tryParse(_state.countdownMinutesText);
      if (_state.countdownDurationInputInvalid ||
          parsed == null ||
          parsed != _state.timeLimitMinutes ||
          _state.timeLimitMinutes < 1 ||
          _state.timeLimitMinutes > 180) {
        errors.add(PregameValidationError.invalidCountdownDuration);
      }
    }
    return PregameValidationResult(List.unmodifiable(errors));
  }

  MatchSetup createMatchSetup() {
    final selected = selectedRules;
    return MatchSetup(
      matchId: _matchIdFactory(),
      redName: _state.redName,
      blueName: _state.blueName,
      redPlayerProfileId: _state.redPlayerProfileId,
      bluePlayerProfileId: _state.bluePlayerProfileId,
      ruleTemplateId: _state.ruleTemplateId,
      ruleTemplateName: selected?.name,
      targetScore: _state.goalScoringMode == GoalScoringMode.target
          ? _state.targetScore
          : null,
      timerEnabled: _state.timerEnabled,
      timeLimitMinutes: _state.timeLimitMinutes,
      winByTwo: false,
      scoreButtons: selected?.scoreButtons ?? const [1, 2, 3],
      foulLimit: selected?.foulLimit,
      possessionHintEnabled: selected?.possessionHintEnabled ?? false,
      possessionPolicy: selected?.possessionPolicy ?? PossessionPolicy.manual,
      customEventTypes: selected?.customEventTypes ?? const [],
      recordingMode: _state.recordingMode ?? RecordingMode.simple,
      trackingCoverage: _state.trackingCoverage,
      clockMode: _state.clockMode,
    );
  }

  bool _selectProfile(String? profileId, {required bool red}) {
    if (profileId == null) {
      _state = red
          ? _state.copyWith(clearRedPlayerProfileId: true)
          : _state.copyWith(clearBluePlayerProfileId: true);
      return true;
    }
    final player = _findPlayer(profileId);
    if (player == null) return false;
    final otherId = red
        ? _state.bluePlayerProfileId
        : _state.redPlayerProfileId;
    if (otherId == profileId) return false;
    _state = red
        ? _state.copyWith(
            redName: player.nickname,
            redPlayerProfileId: player.id,
          )
        : _state.copyWith(
            blueName: player.nickname,
            bluePlayerProfileId: player.id,
          );
    return true;
  }

  Player? _findPlayer(String id) {
    return _players.where((player) => player.id == id).firstOrNull;
  }

  static String _newMatchId() =>
      'match-${DateTime.now().microsecondsSinceEpoch}';
}
