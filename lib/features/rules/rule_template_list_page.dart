import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/l10n/rule_template_localizations.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/rules/rule_template_editor_page.dart';

class RuleTemplateListPage extends StatefulWidget {
  const RuleTemplateListPage({required this.repository, super.key});

  final RuleTemplateRepository repository;

  @override
  State<RuleTemplateListPage> createState() => _RuleTemplateListPageState();
}

class _RuleTemplateListPageState extends State<RuleTemplateListPage> {
  var _streamKey = 0;

  @override
  void initState() {
    super.initState();
    unawaited(widget.repository.ensureBuiltIns());
  }

  Future<void> _retry() async {
    if (mounted) setState(() => _streamKey++);
    await widget.repository.ensureBuiltIns();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final canPop = Navigator.of(context).canPop();
    return EditorialScaffold(
      maxContentWidth: 960,
      masthead: EditorialMasthead(
        title: l10n.rulesTitle,
        leading: canPop
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
        trailing: EditorialTapTarget(
          key: const Key('rule-add-custom'),
          onPressed: () => _openEditor(context),
          tooltip: l10n.rulesCreate,
          label: l10n.rulesCreate,
          child: const Icon(Icons.add),
        ),
      ),
      body: StreamBuilder<List<RuleTemplate>>(
        key: ValueKey(_streamKey),
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StateViewport(
              child: EditorialErrorState(
                title: l10n.rulesLoadError,
                message: l10n.rulesLoadErrorBody,
                actionLabel: l10n.retryAction,
                onAction: _retry,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return _StateViewport(
              child: EditorialEmptyState(
                title: l10n.rulesEmptyTitle,
                message: l10n.rulesEmptyBody,
                actionLabel: l10n.rulesCreate,
                onAction: () => _openEditor(context),
                icon: Icons.rule_outlined,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final builtIn = RuleTemplateRepository.builtIns.any(
                (item) => item.id == template.id,
              );
              final name = localizedRuleTemplateName(template, l10n);
              final status = builtIn ? l10n.rulesBuiltIn : l10n.rulesCustom;
              final summary = _summary(template, l10n);
              return EditorialIndexRow(
                key: ValueKey('rule-template-${template.id}'),
                index: '${index + 1}'.padLeft(2, '0'),
                title: name,
                subtitle: summary,
                semanticLabel: builtIn ? '$name, $status, $summary' : null,
                trailing: _TemplateIdentity(builtIn: builtIn, label: status),
                onTap: builtIn ? null : () => _openEditor(context, template),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, [
    RuleTemplate? template,
  ]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RuleTemplateEditorPage(
          repository: widget.repository,
          template: template,
        ),
      ),
    );
  }

  static String _summary(RuleTemplate template, AppLocalizations l10n) {
    final values = <String>[
      l10n.rulesScoringButtons(template.scoreButtons.join('/')),
    ];
    if (template.targetScore != null) {
      values.add(l10n.rulesTarget(template.targetScore!));
    }
    if (template.timeLimitSeconds != null) {
      values.add(l10n.rulesMinutes(template.timeLimitSeconds! ~/ 60));
    }
    if (template.winByTwo) values.add(l10n.rulesWinByTwo);
    if (template.possessionHintEnabled) {
      values.add(l10n.rulePossessionHintTitle);
    }
    return values.join(' · ');
  }
}

class _TemplateIdentity extends StatelessWidget {
  const _TemplateIdentity({required this.builtIn, required this.label});

  final bool builtIn;
  final String label;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          builtIn ? Icons.lock_outline : Icons.edit_outlined,
          color: builtIn ? editorial.mutedInk : editorial.arenaAccent,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: editorial.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StateViewport extends StatelessWidget {
  const _StateViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
