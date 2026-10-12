import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/l10n/rule_template_localizations.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

const _temporaryProfileId = '__temporary_profile__';

/// Kept as a page-level compatibility helper for route consumers; the
/// canonical human-readable validation vocabulary lives in the controller.
String pregameValidationErrorText(PregameValidationError error) {
  return pregameValidationErrorMessage(error);
}

String localizedPregameValidationErrorText(
  PregameValidationError error,
  AppLocalizations l10n,
) {
  return _validationText(error, l10n);
}

String _validationText(PregameValidationError error, AppLocalizations l10n) {
  return switch (error) {
    PregameValidationError.redParticipantRequired =>
      l10n.pregameValidationRedRequired,
    PregameValidationError.blueParticipantRequired =>
      l10n.pregameValidationBlueRequired,
    PregameValidationError.duplicatePlayerProfile =>
      l10n.pregameValidationDuplicateProfile,
    PregameValidationError.redPlayerProfileMissing =>
      l10n.pregameValidationRedMissing,
    PregameValidationError.bluePlayerProfileMissing =>
      l10n.pregameValidationBlueMissing,
    PregameValidationError.recordingModeRequired =>
      l10n.pregameValidationModeRequired,
    PregameValidationError.countdownTimerRequired =>
      l10n.pregameValidationCountdownRequired,
    PregameValidationError.invalidCountdownDuration =>
      l10n.pregameValidationCountdownDuration,
  };
}

class PregamePage extends StatefulWidget {
  const PregamePage({
    this.onStartMatch,
    this.players = const [],
    this.playersNotice,
    this.templates = RuleTemplateRepository.builtIns,
    this.onManageRules,
    this.initialPreset,
    this.onCreatePlayer,
    this.onCancel,
    super.key,
  });

  final FutureOr<void> Function(MatchSetup)? onStartMatch;
  final List<Player> players;
  final String? playersNotice;
  final List<RuleTemplate> templates;
  final VoidCallback? onManageRules;
  final MatchSetupPreset? initialPreset;
  final Future<Player> Function(String nickname)? onCreatePlayer;
  final VoidCallback? onCancel;

  @override
  State<PregamePage> createState() => _PregamePageState();
}

class _PregamePageState extends State<PregamePage> {
  late final PregameController _controller;
  late final TextEditingController _redNameController;
  late final TextEditingController _blueNameController;
  late final TextEditingController _countdownMinutesController;
  List<PregameValidationError> _validationErrors = const [];
  Locale? _defaultNamesLocale;
  bool _redNameUsesLocalizedDefault = true;
  bool _blueNameUsesLocalizedDefault = true;
  bool _starting = false;
  bool _editingTargetScore = false;
  bool _creatingPlayer = false;
  final List<Player> _createdPlayers = [];

  List<Player> get _availablePlayers => [
    ...widget.players,
    for (final player in _createdPlayers)
      if (widget.players.every((existing) => existing.id != player.id)) player,
  ];

  @override
  void initState() {
    super.initState();
    _controller = PregameController(
      templates: widget.templates,
      players: widget.players,
      initialPreset: widget.initialPreset,
    );
    if (widget.initialPreset != null) {
      _redNameUsesLocalizedDefault = false;
      _blueNameUsesLocalizedDefault = false;
    }
    _redNameController = TextEditingController(text: _controller.state.redName);
    _blueNameController = TextEditingController(
      text: _controller.state.blueName,
    );
    _countdownMinutesController = TextEditingController(
      text: _controller.state.countdownMinutesText,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_defaultNamesLocale == locale) return;
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    if (_redNameUsesLocalizedDefault) {
      _setLocalizedDefaultName(red: true, value: l10n.pregameRed);
    }
    if (_blueNameUsesLocalizedDefault) {
      _setLocalizedDefaultName(red: false, value: l10n.pregameBlue);
    }
    _defaultNamesLocale = locale;
  }

  @override
  void didUpdateWidget(covariant PregamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templates != widget.templates) {
      _controller.setTemplates(widget.templates);
      _syncCountdownMinutesController();
    }
    if (oldWidget.players != widget.players) {
      // A repository stream can emit while this page is open. Updating the
      // available options must not recreate the controller or overwrite a
      // temporary name the user is currently typing.
      _controller.setPlayers(_availablePlayers);
    }
  }

  @override
  void dispose() {
    _redNameController.dispose();
    _blueNameController.dispose();
    _countdownMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final state = _controller.state;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return EditorialScaffold(
      maxContentWidth: 960,
      masthead: EditorialMasthead(
        title: l10n.pregameTitle,
        compact: true,
        leading: IconButton(
          key: const Key('pregame-cancel'),
          tooltip: l10n.cancelAction,
          onPressed: _starting ? null : _cancel,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.initialPreset != null) ...[
                      Text(
                        l10n.v2PresetApplied,
                        key: const Key('pregame-preset-notice'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _rulesSummary(l10n),
                      key: const Key('pregame-rules-summary'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    EditorialSectionRule(label: l10n.pregamePlayers),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _participantCard(
                            context,
                            red: true,
                            sideLabel: l10n.pregameRed,
                            profileKey: const Key('pregame-red-profile'),
                            nameKey: const Key('pregame-red-name'),
                            nameController: _redNameController,
                            selectedProfileId: state.redPlayerProfileId,
                            onProfileChanged: (value) =>
                                _selectProfile(true, value),
                            onNameChanged: (value) {
                              setState(() {
                                _redNameUsesLocalizedDefault = false;
                                _controller.setRedName(value);
                                _clearValidation();
                              });
                            },
                          ),
                          _participantCard(
                            context,
                            red: false,
                            sideLabel: l10n.pregameBlue,
                            profileKey: const Key('pregame-blue-profile'),
                            nameKey: const Key('pregame-blue-name'),
                            nameController: _blueNameController,
                            selectedProfileId: state.bluePlayerProfileId,
                            onProfileChanged: (value) =>
                                _selectProfile(false, value),
                            onNameChanged: (value) {
                              setState(() {
                                _blueNameUsesLocalizedDefault = false;
                                _controller.setBlueName(value);
                                _clearValidation();
                              });
                            },
                          ),
                        ];
                        if (constraints.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              cards[1],
                              const SizedBox(height: 12),
                              cards[0],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[1]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[0]),
                          ],
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        key: const Key('pregame-swap-sides'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _starting ? null : _swapSides,
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(l10n.v2SwapSides),
                      ),
                    ),
                    if (widget.playersNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.playersNotice!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('pregame-configuration-rail'),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: editorialThemeOf(context).arenaAccent,
                            width: 4,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyedSubtree(
                            key: const Key('pregame-rules-section'),
                            child: Semantics(
                              container: true,
                              label: l10n.pregameRuleTemplate,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  EditorialSectionRule(
                                    label: l10n.pregameRuleTemplate,
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: DropdownButtonFormField<String>(
                                      key: const Key('pregame-rule-template'),
                                      initialValue: state.ruleTemplateId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: l10n.pregameRuleTemplate,
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: [
                                        for (final template
                                            in _controller.templates)
                                          DropdownMenuItem(
                                            value: template.id,
                                            child: Text(
                                              _templateLabel(template, l10n),
                                            ),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _controller.setRuleTemplateId(value);
                                          _syncCountdownMinutesController();
                                          _clearValidation();
                                        });
                                      },
                                    ),
                                  ),
                                  if (widget.onManageRules != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextButton.icon(
                                          onPressed: widget.onManageRules,
                                          icon: const Icon(Icons.tune),
                                          label: Text(l10n.pregameManageRules),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _coverageChoices(l10n),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: const Key('pregame-clock-section'),
                            child: Semantics(
                              container: true,
                              label: l10n.pregameTimer,
                              child: ExpansionTile(
                                key: const Key('pregame-clock-settings'),
                                tilePadding: EdgeInsets.zero,
                                title: Text(l10n.pregameTimer),
                                subtitle: Text(
                                  state.timerEnabled
                                      ? state.clockMode == ClockMode.countdown
                                            ? '${l10n.pregameCountDown} · ${state.timeLimitMinutes} ${l10n.pregameMinutes}'
                                            : l10n.pregameCountUp
                                      : l10n.pregameTimerDisabled,
                                ),
                                maintainState: true,
                                children: [
                                  SwitchListTile(
                                    key: const Key('pregame-timer'),
                                    contentPadding: EdgeInsets.zero,
                                    value: state.timerEnabled,
                                    title: Text(l10n.pregameTimer),
                                    subtitle: Text(
                                      state.timerEnabled
                                          ? l10n.pregameTimerEnabled
                                          : l10n.pregameTimerDisabled,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _controller.setTimerEnabled(value);
                                        _clearValidation();
                                      });
                                    },
                                  ),
                                  if (state.timerEnabled) ...[
                                    const SizedBox(height: 4),
                                    _SectionLabel(text: l10n.pregameClockMode),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _SelectionButton<ClockMode>(
                                          key: const Key(
                                            'pregame-clock-count-up',
                                          ),
                                          label: l10n.pregameCountUp,
                                          selected:
                                              state.clockMode ==
                                              ClockMode.countUp,
                                          onPressed: () => _selectClockMode(
                                            ClockMode.countUp,
                                          ),
                                        ),
                                        _SelectionButton<ClockMode>(
                                          key: const Key(
                                            'pregame-clock-countdown',
                                          ),
                                          label: l10n.pregameCountDown,
                                          selected:
                                              state.clockMode ==
                                              ClockMode.countdown,
                                          onPressed: () => _selectClockMode(
                                            ClockMode.countdown,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (state.clockMode ==
                                        ClockMode.countdown) ...[
                                      const SizedBox(height: 12),
                                      TextField(
                                        key: const Key(
                                          'pregame-countdown-minutes',
                                        ),
                                        controller: _countdownMinutesController,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: false,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: l10n.pregameCountdownLabel,
                                          helperText:
                                              l10n.pregameCountdownHelper,
                                          suffixText: l10n.pregameMinutes,
                                          border: const OutlineInputBorder(),
                                          errorText: _countdownErrorText(
                                            state,
                                            l10n,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _controller.setCountdownMinutesText(
                                              value,
                                            );
                                            _clearValidation();
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: const Key('pregame-advanced-section'),
                            child: Semantics(
                              container: true,
                              label: l10n.pregameAdvanced,
                              child: ExpansionTile(
                                key: const Key('pregame-advanced'),
                                tilePadding: EdgeInsets.zero,
                                title: Text(l10n.pregameAdvanced),
                                initiallyExpanded: state.advancedExpanded,
                                maintainState: true,
                                onExpansionChanged:
                                    _controller.setAdvancedExpanded,
                                children: [
                                  SwitchListTile(
                                    key: const Key('pregame-win-by-two'),
                                    contentPadding: EdgeInsets.zero,
                                    value: state.winByTwo,
                                    title: Text(l10n.pregameWinByTwo),
                                    onChanged: (value) {
                                      setState(() {
                                        _controller.setWinByTwo(value);
                                        _clearValidation();
                                      });
                                    },
                                  ),
                                  _NumberSetting(
                                    label: l10n.pregameTargetScore,
                                    value: state.targetScore,
                                    onEdit: _editTargetScore,
                                    onChanged: (value) {
                                      setState(() {
                                        _controller.setTargetScore(value);
                                        _clearValidation();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_validationErrors.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _ValidationMessage(
                              key: const Key('pregame-validation'),
                              errors: _validationErrors,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const Key('pregame-start-match'),
                  onPressed: _starting || _creatingPlayer ? null : _startMatch,
                  child: _starting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.pregameStartMatch),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantCard(
    BuildContext context, {
    required bool red,
    required String sideLabel,
    required Key profileKey,
    required Key nameKey,
    required TextEditingController nameController,
    required String? selectedProfileId,
    required ValueChanged<String?> onProfileChanged,
    required ValueChanged<String> onNameChanged,
  }) {
    final editorial = editorialThemeOf(context);
    final teamColor = red ? editorial.teamRed : editorial.teamBlue;
    return EditorialSurface(
      key: Key(red ? 'pregame-red-card' : 'pregame-blue-card'),
      padding: EdgeInsets.zero,
      semanticLabel: sideLabel,
      color: teamColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: teamColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _ParticipantSetup(
              sideLabel: sideLabel,
              profileKey: profileKey,
              nameKey: nameKey,
              nameController: nameController,
              selectedProfileId: selectedProfileId,
              players: _availablePlayers,
              onProfileChanged: onProfileChanged,
              onNameChanged: onNameChanged,
              onCreatePlayer:
                  widget.onCreatePlayer == null || _starting || _creatingPlayer
                  ? null
                  : () => _createPlayer(red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverageChoices(AppLocalizations l10n) {
    final coverage = _controller.state.trackingCoverage;
    return Column(
      key: const Key('pregame-record-scope'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.v2CoverageTitle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SelectionButton<TrackingCoverage>(
              key: const Key('pregame-coverage-scores'),
              label: l10n.v2CoverageScores,
              selected: coverage == TrackingCoverage.scoresOnly,
              onPressed: () => _selectCoverage(TrackingCoverage.scoresOnly),
            ),
            _SelectionButton<TrackingCoverage>(
              key: const Key('pregame-coverage-shots'),
              label: l10n.v2CoverageComplete,
              selected: coverage == TrackingCoverage.shotAttempts,
              onPressed: () => _selectCoverage(TrackingCoverage.shotAttempts),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.v2CoverageHelp, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _rulesSummary(AppLocalizations l10n) {
    final state = _controller.state;
    final rules = _controller.selectedRules;
    final target = rules == null || state.targetScoreOverridden
        ? state.targetScore
        : rules.targetScore;
    final parts = [
      '${(rules?.scoreButtons ?? [1, 2, 3]).join(' / ')} ${l10n.pregamePoint}',
      if (target != null) l10n.rulesTarget(target),
      if (state.winByTwo) l10n.pregameWinByTwo,
    ];
    return '${l10n.v2RulesSummary}: ${parts.join(' · ')}';
  }

  void _selectCoverage(TrackingCoverage coverage) {
    if (_starting) return;
    setState(() {
      _controller.setTrackingCoverage(coverage);
      _clearValidation();
    });
  }

  void _swapSides() {
    setState(() {
      _controller.swapSides();
      _redNameUsesLocalizedDefault = false;
      _blueNameUsesLocalizedDefault = false;
      _redNameController.text = _controller.state.redName;
      _blueNameController.text = _controller.state.blueName;
      _clearValidation();
    });
  }

  void _cancel() {
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _createPlayer(bool red) async {
    final onCreate = widget.onCreatePlayer;
    if (onCreate == null || _creatingPlayer || _starting) return;
    setState(() => _creatingPlayer = true);
    final player = await showDialog<Player>(
      context: context,
      builder: (context) => _CreatePlayerDialog(
        initialName: red ? _redNameController.text : _blueNameController.text,
        onCreate: onCreate,
      ),
    );
    if (!mounted) return;
    setState(() {
      _creatingPlayer = false;
      if (player != null) {
        _createdPlayers.add(player);
        _controller.setPlayers(_availablePlayers);
      }
    });
    if (player != null) _selectProfile(red, player.id);
  }

  void _selectProfile(bool red, String? value) {
    final accepted = red
        ? _controller.selectRedProfile(value)
        : _controller.selectBlueProfile(value);
    if (!accepted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              (AppLocalizations.of(context) ?? AppLocalizationsZh())
                  .pregameProfileConflict,
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      return;
    }
    if (red) {
      _redNameUsesLocalizedDefault = false;
    } else {
      _blueNameUsesLocalizedDefault = false;
    }
    if (value != null) {
      final name = red ? _controller.state.redName : _controller.state.blueName;
      final controller = red ? _redNameController : _blueNameController;
      controller.value = controller.value.copyWith(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
        composing: TextRange.empty,
      );
    }
    setState(_clearValidation);
  }

  void _setLocalizedDefaultName({required bool red, required String value}) {
    if (red) {
      _controller.setRedName(value);
      _redNameController.value = _redNameController.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    } else {
      _controller.setBlueName(value);
      _blueNameController.value = _blueNameController.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
  }

  void _selectClockMode(ClockMode mode) {
    setState(() {
      _controller.setClockMode(mode);
      _clearValidation();
    });
  }

  Future<void> _startMatch() async {
    if (_starting || _creatingPlayer) return;
    if (_redNameController.text != _controller.state.redName) {
      _controller.setRedName(_redNameController.text);
    }
    if (_blueNameController.text != _controller.state.blueName) {
      _controller.setBlueName(_blueNameController.text);
    }
    final validation = _controller.validate();
    if (!validation.isValid) {
      setState(() => _validationErrors = validation.errors);
      return;
    }
    final onStart = widget.onStartMatch;
    if (onStart == null) return;
    setState(() {
      _validationErrors = const [];
      _starting = true;
    });
    try {
      await onStart(_controller.createMatchSetup());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (AppLocalizations.of(context) ?? AppLocalizationsZh())
                .v2StartFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _editTargetScore() async {
    if (_editingTargetScore || _starting) return;
    _editingTargetScore = true;
    try {
      final value = await showDialog<int>(
        context: context,
        builder: (_) =>
            _TargetScoreDialog(initialValue: _controller.state.targetScore),
      );
      if (!mounted || value == null) return;
      setState(() {
        _controller.setTargetScore(value);
        _clearValidation();
      });
    } finally {
      _editingTargetScore = false;
    }
  }

  void _clearValidation() {
    if (_validationErrors.isNotEmpty) _validationErrors = const [];
  }

  void _syncCountdownMinutesController() {
    final text = _controller.state.countdownMinutesText;
    if (_countdownMinutesController.text == text) return;
    _countdownMinutesController.value = _countdownMinutesController.value
        .copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
  }

  static String? _countdownErrorText(
    PregameState state,
    AppLocalizations l10n,
  ) {
    final parsed = int.tryParse(state.countdownMinutesText);
    if (state.countdownDurationInputInvalid ||
        parsed == null ||
        parsed != state.timeLimitMinutes ||
        state.timeLimitMinutes < 1 ||
        state.timeLimitMinutes > 180) {
      return l10n.pregameCountdownInvalid;
    }
    return null;
  }

  static String _templateLabel(RuleTemplate template, AppLocalizations l10n) {
    return switch (template.id) {
      'free' => l10n.pregameFreeScoring,
      'eleven_win_by_two' => l10n.pregameElevenPoint,
      'twenty_one' => l10n.pregameTwentyOnePoint,
      'timed_ten' => l10n.ruleBuiltInTimedTen,
      _ => localizedRuleTemplateName(template, l10n),
    };
  }
}

class _ParticipantSetup extends StatelessWidget {
  const _ParticipantSetup({
    required this.sideLabel,
    required this.profileKey,
    required this.nameKey,
    required this.nameController,
    required this.selectedProfileId,
    required this.players,
    required this.onProfileChanged,
    required this.onNameChanged,
    this.onCreatePlayer,
  });

  final String sideLabel;
  final Key profileKey;
  final Key nameKey;
  final TextEditingController nameController;
  final String? selectedProfileId;
  final List<Player> players;
  final ValueChanged<String?> onProfileChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onCreatePlayer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final profileItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _temporaryProfileId,
        child: Text(
          l10n.pregameTemporaryParticipant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      for (final player in players)
        DropdownMenuItem(
          value: player.id,
          child: Text(
            player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    if (selectedProfileId != null &&
        players.every((player) => player.id != selectedProfileId)) {
      profileItems.add(
        DropdownMenuItem(
          value: selectedProfileId,
          enabled: false,
          child: Text(
            l10n.pregameDeletedPlayer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(sideLabel, style: Theme.of(context).textTheme.titleSmall),
            if (onCreatePlayer != null)
              TextButton.icon(
                key: Key(
                  profileKey == const Key('pregame-red-profile')
                      ? 'pregame-red-create-player'
                      : 'pregame-blue-create-player',
                ),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onCreatePlayer,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(l10n.v2CreatePlayer),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.pregameParticipationMode,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: profileKey,
              value: selectedProfileId ?? _temporaryProfileId,
              isExpanded: true,
              items: profileItems,
              onChanged: (value) {
                if (value == null) return;
                onProfileChanged(value == _temporaryProfileId ? null : value);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: nameKey,
          controller: nameController,
          decoration: InputDecoration(
            labelText: selectedProfileId == null
                ? l10n.pregameTemporaryName(sideLabel)
                : l10n.pregameNameSnapshot(sideLabel),
            helperText: selectedProfileId == null
                ? null
                : l10n.pregameSnapshotHint,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          onChanged: onNameChanged,
        ),
      ],
    );
  }
}

class _CreatePlayerDialog extends StatefulWidget {
  const _CreatePlayerDialog({
    required this.initialName,
    required this.onCreate,
  });

  final String initialName;
  final Future<Player> Function(String nickname) onCreate;

  @override
  State<_CreatePlayerDialog> createState() => _CreatePlayerDialogState();
}

class _CreatePlayerDialogState extends State<_CreatePlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final player = await widget.onCreate(_nameController.text.trim());
      if (mounted) Navigator.of(context).pop(player);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.v2CreatePlayer),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('pregame-create-player-name'),
                controller: _nameController,
                autofocus: true,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: l10n.playerNicknameLabel,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.playerNicknameRequired
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.playerSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('pregame-create-player-cancel'),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            key: const Key('pregame-create-player-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.playerSaving : l10n.playerSaveTooltip),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SelectionButton<T> extends StatelessWidget {
  const _SelectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.errors, super.key});

  final List<PregameValidationError> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final messages = errors
        .map((error) => _validationText(error, l10n))
        .toList();
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: editorialThemeOf(context).danger, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final message in messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(message),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onEdit,
  });

  final String label;
  final VoidCallback onEdit;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                key: const Key('pregame-target-decrease'),
                tooltip: '$label −1',
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: value <= PregameController.minTargetScore
                    ? null
                    : () => onChanged(value - 1),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  excludeSemantics: true,
                  onTap: onEdit,
                  label: l10n.pregameEditTargetScore,
                  value: '$value${l10n.pregamePoint}',
                  child: OutlinedButton(
                    key: const Key('pregame-target-edit'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onEdit,
                    child: Text(
                      '$value${l10n.pregamePoint}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                key: const Key('pregame-target-increase'),
                tooltip: '$label +1',
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: value >= PregameController.maxTargetScore
                    ? null
                    : () => onChanged(value + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetScoreDialog extends StatefulWidget {
  const _TargetScoreDialog({required this.initialValue});

  final int initialValue;

  @override
  State<_TargetScoreDialog> createState() => _TargetScoreDialogState();
}

class _TargetScoreDialogState extends State<_TargetScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _inputController;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final text = '${widget.initialValue}';
    _inputController = TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_completed || ModalRoute.of(context)?.isCurrent != true) return;
    if (!_formKey.currentState!.validate()) return;
    _complete(int.parse(_inputController.text.trim()));
  }

  void _complete([int? value]) {
    if (_completed || ModalRoute.of(context)?.isCurrent != true) return;
    _completed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final rangeMessage = l10n.pregameTargetScoreRange(
      PregameController.minTargetScore,
      PregameController.maxTargetScore,
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minWidth: 320),
      scrollable: true,
      semanticLabel: l10n.pregameTargetScore,
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const Key('pregame-target-input'),
            controller: _inputController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.pregameTargetScore,
              helperText: rangeMessage,
              helperMaxLines: 3,
              errorMaxLines: 3,
            ),
            validator: (text) {
              final input = (text ?? '').trim();
              final value = int.tryParse(input);
              if (!RegExp(r'^[0-9]+$').hasMatch(input) ||
                  value == null ||
                  value < PregameController.minTargetScore ||
                  value > PregameController.maxTargetScore) {
                return rangeMessage;
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('pregame-target-cancel'),
          onPressed: _complete,
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          key: const Key('pregame-target-confirm'),
          onPressed: _submit,
          child: Text(l10n.pregameConfirmTargetScore),
        ),
      ],
    );
  }
}
