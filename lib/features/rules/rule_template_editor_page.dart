import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

class RuleTemplateEditorPage extends StatefulWidget {
  const RuleTemplateEditorPage({
    required this.repository,
    this.template,
    super.key,
  });

  final RuleTemplateRepository repository;
  final RuleTemplate? template;

  @override
  State<RuleTemplateEditorPage> createState() => _RuleTemplateEditorPageState();
}

class _RuleTemplateEditorPageState extends State<RuleTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _timeLimit;
  late final TextEditingController _foulLimit;
  late final TextEditingController _scoreButtons;
  late final TextEditingController _eventTypes;
  late bool _possessionHint;
  late PossessionPolicy _possessionPolicy;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _name = TextEditingController(text: template?.name ?? '');
    _target = TextEditingController(
      text: template?.targetScore?.toString() ?? '',
    );
    _timeLimit = TextEditingController(
      text: template?.timeLimitSeconds == null
          ? ''
          : '${template!.timeLimitSeconds! ~/ 60}',
    );
    _foulLimit = TextEditingController(
      text: template?.foulLimit?.toString() ?? '',
    );
    _scoreButtons = TextEditingController(
      text: template?.scoreButtons.join(',') ?? '1,2,3',
    );
    _eventTypes = TextEditingController(
      text: template?.customEventTypes.join(',') ?? '',
    );
    _possessionHint = template?.possessionHintEnabled ?? false;
    _possessionPolicy = _possessionHint
        ? template?.possessionPolicy ?? PossessionPolicy.manual
        : PossessionPolicy.manual;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _target,
      _timeLimit,
      _foulLimit,
      _scoreButtons,
      _eventTypes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final canPop = Navigator.of(context).canPop();
    return EditorialScaffold(
      maxContentWidth: 760,
      masthead: EditorialMasthead(
        title: widget.template == null ? l10n.ruleNewTitle : l10n.ruleEditTitle,
        leading: canPop
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormSectionHeading(label: l10n.ruleNameLabel),
              const SizedBox(height: 16),
              _field(
                key: const Key('rule-name'),
                controller: _name,
                label: l10n.ruleNameLabel,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.ruleNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              _FormSectionHeading(label: l10n.ruleTargetLabel),
              const SizedBox(height: 16),
              _field(
                key: const Key('rule-target-score'),
                controller: _target,
                label: l10n.ruleTargetLabel,
                numeric: true,
                validator: (value) => _validateTarget(value, l10n),
              ),
              _field(
                key: const Key('rule-time-limit'),
                controller: _timeLimit,
                label: l10n.ruleTimeLimitLabel,
                numeric: true,
              ),
              _field(
                key: const Key('rule-foul-limit'),
                controller: _foulLimit,
                label: l10n.ruleFoulLimitLabel,
                numeric: true,
              ),
              const SizedBox(height: 12),
              _FormSectionHeading(label: l10n.ruleScoreButtonsLabel),
              const SizedBox(height: 16),
              _field(
                key: const Key('rule-score-buttons'),
                controller: _scoreButtons,
                label: l10n.ruleScoreButtonsLabel,
                validator: _validateScoreButtons,
              ),
              _field(
                key: const Key('rule-event-types'),
                controller: _eventTypes,
                label: l10n.ruleCustomLabelsLabel,
              ),
              const SizedBox(height: 12),
              _FormSectionHeading(label: l10n.rulePossessionHintTitle),
              const SizedBox(height: 8),
              _SpecToggle(
                key: const Key('rule-possession-hint'),
                value: _possessionHint,
                title: l10n.rulePossessionHintTitle,
                subtitle: l10n.rulePossessionHintSubtitle,
                onChanged: (value) => setState(() {
                  _possessionHint = value;
                  if (!value) _possessionPolicy = PossessionPolicy.manual;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PossessionPolicy>(
                key: const Key('rule-possession-policy'),
                initialValue: _possessionPolicy,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.rulePossessionPolicyLabel,
                  helperText: l10n.rulePossessionPolicyHelper,
                ),
                items: [
                  for (final policy in PossessionPolicy.values)
                    DropdownMenuItem(
                      value: policy,
                      child: Text(
                        _possessionPolicyLabel(policy, l10n),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _possessionHint
                    ? (value) {
                        if (value == null) return;
                        setState(() => _possessionPolicy = value);
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              Semantics(
                key: const Key('rule-save'),
                button: true,
                enabled: true,
                label: l10n.ruleSaveAction,
                onTap: _save,
                child: ExcludeSemantics(
                  child: EditorialTapTarget(
                    onPressed: _save,
                    tooltip: l10n.ruleSaveAction,
                    child: _SaveRuleAction(label: l10n.ruleSaveAction),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    bool numeric = false,
    String? Function(String?)? validator,
  }) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (numeric
                ? (value) => _validateOptionalPositive(value, label, l10n)
                : null),
      ),
    );
  }

  String? _validateOptionalPositive(
    String? value,
    String label,
    AppLocalizations l10n,
  ) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    return parsed == null || parsed <= 0
        ? l10n.rulePositiveInteger(label)
        : null;
  }

  String? _validateTarget(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    return parsed == null || parsed < 1 || parsed > 999
        ? l10n.pregameTargetScoreRange(1, 999)
        : null;
  }

  String? _validateScoreButtons(String? value) {
    final values = _parseNumbers(value ?? '');
    return values.isEmpty || values.any((item) => item <= 0)
        ? (AppLocalizations.of(context) ?? AppLocalizationsZh())
              .ruleAtLeastOneInteger
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final current = widget.template;
    await widget.repository.save(
      RuleTemplate(
        id: current?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        scoreButtons: _parseNumbers(_scoreButtons.text).toSet().toList()
          ..sort(),
        targetScore: _optionalInt(_target.text),
        timeLimitSeconds: _optionalInt(_timeLimit.text) == null
            ? null
            : _optionalInt(_timeLimit.text)! * 60,
        // Preserve existing custom fields while removing this option for new rules.
        winByTwo: current?.winByTwo ?? false,
        foulLimit: _optionalInt(_foulLimit.text),
        possessionHintEnabled: _possessionHint,
        possessionPolicy: _possessionHint
            ? _possessionPolicy
            : PossessionPolicy.manual,
        customEventTypes: _parseTextList(_eventTypes.text),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  static int? _optionalInt(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.parse(text);
  }

  static List<int> _parseNumbers(String value) => value
      .split(RegExp(r'[,，\s]+'))
      .where((item) => item.isNotEmpty)
      .map(int.tryParse)
      .whereType<int>()
      .toList();

  static List<String> _parseTextList(String value) => value
      .split(RegExp(r'[,，\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  static String _possessionPolicyLabel(
    PossessionPolicy policy,
    AppLocalizations l10n,
  ) {
    return switch (policy) {
      PossessionPolicy.manual => l10n.rulePolicyManual,
      PossessionPolicy.switchAfterMade => l10n.rulePolicySwitchAfterMade,
      PossessionPolicy.keepAfterMade => l10n.rulePolicyKeepAfterMade,
    };
  }
}

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        if (!largeText && constraints.maxWidth >= 360) {
          return EditorialSectionRule(label: label);
        }
        final editorial = editorialThemeOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: editorial.mutedInk,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Divider(color: editorial.rule),
          ],
        );
      },
    );
  }
}

class _SpecToggle extends StatelessWidget {
  const _SpecToggle({
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: editorial.rule)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        secondary: Icon(
          value ? Icons.check_box_outlined : Icons.check_box_outline_blank,
          color: value ? editorial.success : editorial.mutedInk,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        onChanged: onChanged,
      ),
    );
  }
}

class _SaveRuleAction extends StatelessWidget {
  const _SaveRuleAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final foreground = accessibleForegroundFor(editorial.arenaAccent);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      color: editorial.arenaAccent,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.save_outlined, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
