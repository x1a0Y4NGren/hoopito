import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

/// Built-in rule records keep stable ids and backwards-compatible stored names.
/// The UI resolves those ids to the active locale instead of rendering the
/// seed-language name saved in the database.
String localizedRuleTemplateName(RuleTemplate template, AppLocalizations l10n) {
  return switch (template.id) {
    'free' => l10n.ruleBuiltInFreeScoring,
    'eleven_win_by_two' => l10n.ruleBuiltInElevenWinByTwo,
    'twenty_one' => l10n.ruleBuiltInTwentyOne,
    'timed_ten' => l10n.ruleBuiltInTimedTen,
    _ => template.name,
  };
}

/// Localizes a built-in name that was persisted before the current locale was
/// selected. Custom rule names are returned unchanged.
String localizedStoredRuleTemplateName(
  String storedName,
  AppLocalizations l10n,
) {
  return switch (storedName.trim()) {
    '自由计分' || 'Free scoring' || 'Free' => l10n.ruleBuiltInFreeScoring,
    '11 分制（领先 2 分）' || '11 points (win by 2)' => l10n.ruleBuiltInElevenWinByTwo,
    '11 分制' || '11 points' => l10n.pregameElevenPoint,
    '21 分制' || '21 points' => l10n.ruleBuiltInTwentyOne,
    '10 分钟计时' || '10-minute timed' => l10n.ruleBuiltInTimedTen,
    _ => storedName,
  };
}
