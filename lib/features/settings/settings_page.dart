import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/settings/language_preferences.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/core/settings/theme_preferences.dart';
import 'package:hoopito/features/settings/settings_controller.dart';
import 'package:hoopito/features/settings/settings_error_message.dart';
import 'package:hoopito/features/settings/settings_action_tile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.controller,
    this.onOpenProject,
    this.onOpenData,
    this.onOpenUpdate,
    this.themeController,
    this.languageController,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback? onOpenProject;
  final VoidCallback? onOpenData;
  final VoidCallback? onOpenUpdate;
  final ThemePreferencesController? themeController;
  final LanguagePreferencesController? languageController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppLocalizations _localizations(BuildContext context) {
    return AppLocalizations.of(context) ?? AppLocalizationsZh();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.themeController?.addListener(_refresh);
    widget.languageController?.addListener(_refresh);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _scheduleLoad();
    }
    if (oldWidget.themeController != widget.themeController) {
      oldWidget.themeController?.removeListener(_refresh);
      widget.themeController?.addListener(_refresh);
    }
    if (oldWidget.languageController != widget.languageController) {
      oldWidget.languageController?.removeListener(_refresh);
      widget.languageController?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.themeController?.removeListener(_refresh);
    widget.languageController?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _scheduleLoad() {
    if (widget.controller.initialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.initialized) unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      await widget.controller.load();
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage(settingsFriendlyError(error, _localizations(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = _localizations(context);
    return EditorialScaffold(
      masthead: EditorialMasthead(
        title: l10n.settings,
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
      body: Column(
        children: [
          if (controller.busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
              children: [
                _SettingsSection(
                  title: l10n.settingsAppearanceSection,
                  children: [
                    _ThemeSettingTile(
                      icon: Icons.palette_outlined,
                      title: l10n.settingsThemeTitle,
                      subtitle: l10n.settingsThemeSubtitle,
                      controller: widget.themeController,
                      l10n: l10n,
                    ),
                    _MotionSettingTile(
                      icon: Icons.motion_photos_on_outlined,
                      title: l10n.settingsMotionTitle,
                      subtitle: l10n.settingsMotionSubtitle,
                      preference: controller.feedbackState.motion,
                      enabled: !controller.busy,
                      l10n: l10n,
                      onChanged: _setMotionPreference,
                    ),
                    _MotionPreview(
                      preference: controller.feedbackState.motion,
                      l10n: l10n,
                    ),
                  ],
                ),
                _SettingsSection(
                  title: l10n.settingsFeedbackSection,
                  children: [
                    _RuledControl(
                      child: SwitchListTile(
                        key: const Key('scoring-feedback-haptic-switch'),
                        minTileHeight: 64,
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.vibration),
                        title: Text(l10n.settingsHapticTitle),
                        subtitle: Text(
                          controller.feedbackState.haptic
                              ? l10n.settingsHapticEnabled
                              : l10n.settingsHapticDisabled,
                        ),
                        value: controller.feedbackState.haptic,
                        onChanged: controller.busy
                            ? null
                            : _setHapticFeedbackEnabled,
                      ),
                    ),
                    _RuledControl(
                      child: SwitchListTile(
                        key: const Key('scoring-feedback-sound-switch'),
                        minTileHeight: 64,
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: Text(l10n.settingsSoundTitle),
                        subtitle: Text(
                          controller.feedbackState.sound
                              ? l10n.settingsSoundEnabled
                              : l10n.settingsSoundDisabled,
                        ),
                        value: controller.feedbackState.sound,
                        onChanged: controller.busy
                            ? null
                            : _setSoundFeedbackEnabled,
                      ),
                    ),
                  ],
                ),
                if (widget.languageController != null)
                  _SettingsSection(
                    title: l10n.settingsLanguageSection,
                    children: [
                      _LanguageSettingTile(
                        icon: Icons.language_outlined,
                        title: l10n.settingsLanguageTitle,
                        subtitle: l10n.settingsLanguageSubtitle,
                        controller: widget.languageController,
                        l10n: l10n,
                      ),
                    ],
                  ),
                _SettingsSection(
                  title: l10n.settingsDataSection,
                  children: [
                    SettingsActionTile(
                      key: const Key('settings-data-row'),
                      icon: Icons.storage_outlined,
                      title: l10n.settingsDataManagementTitle,
                      subtitle: l10n.settingsDataManagementSubtitle,
                      onTap: widget.onOpenData,
                    ),
                  ],
                ),
                _SettingsSection(
                  title: l10n.settingsAboutSection,
                  children: [
                    SettingsActionTile(
                      key: const Key('settings-update-row'),
                      icon: Icons.system_update_outlined,
                      title: l10n.updateTitle,
                      subtitle: l10n.updateSubtitle,
                      onTap: widget.onOpenUpdate,
                    ),
                    SettingsActionTile(
                      key: const Key('settings-about-row'),
                      icon: Icons.info_outline,
                      title: l10n.settingsAboutTitle,
                      subtitle: l10n.settingsAboutSubtitle,
                      onTap: widget.onOpenProject,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setHapticFeedbackEnabled(bool enabled) async {
    final l10n = _localizations(context);
    try {
      await widget.controller.setHapticFeedbackEnabled(enabled);
      if (mounted) {
        _showMessage(
          enabled ? l10n.settingsHapticTurnedOn : l10n.settingsHapticTurnedOff,
        );
      }
    } on Object catch (error) {
      _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _setSoundFeedbackEnabled(bool enabled) async {
    final l10n = _localizations(context);
    try {
      await widget.controller.setSoundFeedbackEnabled(enabled);
      if (mounted) {
        _showMessage(
          enabled ? l10n.settingsSoundTurnedOn : l10n.settingsSoundTurnedOff,
        );
      }
    } on Object catch (error) {
      _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _setMotionPreference(MotionPreference preference) async {
    try {
      await widget.controller.setMotionPreference(preference);
    } on Object catch (error) {
      if (mounted) {
        _showMessage(settingsFriendlyError(error, _localizations(context)));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MotionSettingTile extends StatelessWidget {
  const _MotionSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.preference,
    required this.enabled,
    required this.l10n,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final MotionPreference preference;
  final bool enabled;
  final AppLocalizations l10n;
  final ValueChanged<MotionPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsControlRow(
      key: const Key('motion-preference-tile'),
      icon: icon,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      control: DropdownButtonHideUnderline(
        child: DropdownButton<MotionPreference>(
          key: const Key('motion-preference-dropdown'),
          value: preference,
          items: MotionPreference.values
              .map(
                (value) => DropdownMenuItem<MotionPreference>(
                  value: value,
                  child: Text(_motionPreferenceLabel(value, l10n)),
                ),
              )
              .toList(growable: false),
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
        ),
      ),
    );
  }
}

String _motionPreferenceLabel(
  MotionPreference preference,
  AppLocalizations l10n,
) {
  return switch (preference) {
    MotionPreference.standard => l10n.settingsMotionStandard,
    MotionPreference.reduced => l10n.settingsMotionReduced,
  };
}

class _MotionPreview extends StatefulWidget {
  const _MotionPreview({required this.preference, required this.l10n});

  final MotionPreference preference;
  final AppLocalizations l10n;

  @override
  State<_MotionPreview> createState() => _MotionPreviewState();
}

class _MotionPreviewState extends State<_MotionPreview> {
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(covariant _MotionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preference != widget.preference) {
      _settled = false;
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_settled) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final systemDisabled = media?.disableAnimations == true;
    final reduced =
        widget.preference == MotionPreference.reduced ||
        media?.accessibleNavigation == true;
    final motion = Theme.of(context).extension<HoopitoMotionTheme>();
    final duration = systemDisabled
        ? Duration.zero
        : reduced
        ? (motion?.reducedReveal ?? const Duration(milliseconds: 120))
        : (motion?.state ?? const Duration(milliseconds: 180));
    final settled = systemDisabled || _settled;
    final editorial = editorialThemeOf(context);
    return Semantics(
      label: widget.l10n.settingsMotionPreview,
      container: true,
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const Key('motion-preview'),
        duration: duration,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: settled
              ? editorial.teamBlue.withValues(alpha: 0.12)
              : editorial.surface,
          border: Border(
            left: BorderSide(color: editorial.teamBlue, width: 4),
            bottom: BorderSide(color: editorial.rule),
          ),
        ),
        child: AnimatedSlide(
          offset: reduced || settled ? Offset.zero : const Offset(-0.06, 0),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: reduced || settled ? 1 : 0.96,
            duration: duration,
            child: Row(
              children: [
                Icon(
                  settled ? Icons.check_circle_outline : Icons.circle_outlined,
                  color: editorial.teamBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reduced
                            ? widget.l10n.settingsMotionPreviewReduced
                            : widget.l10n.settingsMotionPreviewStandard,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: editorial.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.l10n.settingsMotionHelp,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: editorial.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSettingTile extends StatelessWidget {
  const _LanguageSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.l10n,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final LanguagePreferencesController? controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final languageController = controller;
    return _SettingsControlRow(
      key: const Key('language-preference-tile'),
      icon: icon,
      title: title,
      subtitle: subtitle,
      control: languageController == null
          ? null
          : DropdownButtonHideUnderline(
              child: DropdownButton<AppLanguagePreference>(
                key: const Key('language-preference-dropdown'),
                value: languageController.preference,
                items: AppLanguagePreference.values
                    .map(
                      (preference) => DropdownMenuItem<AppLanguagePreference>(
                        value: preference,
                        child: Text(_languagePreferenceLabel(preference, l10n)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (preference) {
                  if (preference != null) {
                    unawaited(languageController.setPreference(preference));
                  }
                },
              ),
            ),
    );
  }
}

String _languagePreferenceLabel(
  AppLanguagePreference preference,
  AppLocalizations l10n,
) {
  return switch (preference) {
    AppLanguagePreference.chinese => l10n.settingsLanguageChinese,
    AppLanguagePreference.english => l10n.settingsLanguageEnglish,
  };
}

class _ThemeSettingTile extends StatelessWidget {
  const _ThemeSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.l10n,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemePreferencesController? controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final themeController = controller;
    return _SettingsControlRow(
      key: const Key('theme-preference-tile'),
      icon: icon,
      title: title,
      subtitle: subtitle,
      control: themeController == null
          ? null
          : DropdownButtonHideUnderline(
              child: DropdownButton<AppThemePreference>(
                key: const Key('theme-preference-dropdown'),
                value: themeController.preference,
                items: AppThemePreference.values
                    .map(
                      (preference) => DropdownMenuItem<AppThemePreference>(
                        value: preference,
                        child: Text(_themePreferenceLabel(preference, l10n)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (preference) {
                  if (preference != null) {
                    unawaited(themeController.setPreference(preference));
                  }
                },
              ),
            ),
    );
  }
}

String _themePreferenceLabel(
  AppThemePreference preference,
  AppLocalizations l10n,
) {
  return switch (preference) {
    AppThemePreference.system => l10n.settingsThemeSystem,
    AppThemePreference.light => l10n.settingsThemeLight,
    AppThemePreference.dark => l10n.settingsThemeDark,
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSectionRule(label: title),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _RuledControl extends StatelessWidget {
  const _RuledControl({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: editorialThemeOf(context).rule)),
    ),
    child: child,
  );
}

class _SettingsControlRow extends StatelessWidget {
  const _SettingsControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.control,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? control;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560 || scale >= 1.6;
        final copy = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 48, height: 48, child: Icon(icon)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: enabled ? editorial.ink : editorial.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: editorial.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final target = control == null
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: control,
              );
        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: editorial.rule)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    if (target != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: target,
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    if (target != null) ...[const SizedBox(width: 12), target],
                  ],
                ),
        );
      },
    );
  }
}
