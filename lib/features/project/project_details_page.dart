import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/features/project/external_link_launcher.dart';

const hoopitoRepositoryUrl = 'https://github.com/x1a0Y4NGren/hoopito';
const hoopitoLicenseUrl = '$hoopitoRepositoryUrl/blob/main/LICENSE';
const hoopitoContributingUrl =
    '$hoopitoRepositoryUrl/blob/main/CONTRIBUTING.md';
const hoopitoIssuesUrl = '$hoopitoRepositoryUrl/issues';

class ProjectDetailsPage extends StatelessWidget {
  const ProjectDetailsPage({
    this.launcher = const ExternalLinkLauncher(),
    super.key,
  });

  final ExternalLinkLauncher launcher;

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launcher.open(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (AppLocalizations.of(context) ?? AppLocalizationsZh())
                .routeProjectLinkError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return EditorialScaffold(
      masthead: EditorialMasthead(
        title: l10n.settingsAboutSection,
        compact: true,
        leading: Navigator.canPop(context)
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                label: MaterialLocalizations.of(context).backButtonTooltip,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
        children: [
          Text(
            'Hoopito · 球豆',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: editorialThemeOf(context).ink,
              fontFamily: HoopitoTypography.displayFamily,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.projectTagline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: editorialThemeOf(context).mutedInk,
            ),
          ),
          const SizedBox(height: HoopitoSpacing.section),
          EditorialSectionRule(label: l10n.projectTitle),
          const SizedBox(height: 4),
          _PromiseTile(
            index: '01',
            icon: Icons.all_inclusive,
            title: l10n.projectFreeForever,
            detail: l10n.projectFreeForeverDetail,
          ),
          _PromiseTile(
            index: '02',
            icon: Icons.code,
            title: l10n.projectOpenSource,
            detail: l10n.projectOpenSourceDetail,
          ),
          _PromiseTile(
            index: '03',
            icon: Icons.offline_bolt_outlined,
            title: l10n.projectOffline,
            detail: l10n.projectOfflineDetail,
          ),
          _PromiseTile(
            index: '04',
            icon: Icons.shield_outlined,
            title: l10n.projectPrivacy,
            detail: l10n.projectPrivacyDetail,
          ),
          const SizedBox(height: HoopitoSpacing.section),
          EditorialSectionRule(label: l10n.projectOpen),
          const SizedBox(height: 4),
          _ProjectLink(
            index: '01',
            icon: Icons.code,
            label: l10n.projectGitHub,
            onTap: () => _open(context, hoopitoRepositoryUrl),
          ),
          _ProjectLink(
            index: '02',
            icon: Icons.balance_outlined,
            label: l10n.projectLicense,
            onTap: () => _open(context, hoopitoLicenseUrl),
          ),
          _ProjectLink(
            index: '03',
            icon: Icons.handshake_outlined,
            label: l10n.projectContribute,
            onTap: () => _open(context, hoopitoContributingUrl),
          ),
          _ProjectLink(
            index: '04',
            icon: Icons.bug_report_outlined,
            label: l10n.projectIssue,
            onTap: () => _open(context, hoopitoIssuesUrl),
          ),
        ],
      ),
    );
  }
}

class _PromiseTile extends StatelessWidget {
  const _PromiseTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String index;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: editorial.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              index,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: editorial.mutedInk,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox.square(
            dimension: 48,
            child: Icon(icon, color: editorial.ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: editorial.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: editorial.mutedInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectLink extends StatelessWidget {
  const _ProjectLink({
    required this.index,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String index;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Semantics(
      key: ValueKey('project-link-$label'),
      label: '$label, ${l10n.projectOpenBrowser}',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: EditorialIndexRow(
        index: index,
        title: label,
        trailing: SizedBox(
          width: 72,
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              const Icon(Icons.open_in_new, size: 20),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
