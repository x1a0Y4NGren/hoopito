import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @v2Saving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存'**
  String get v2Saving;

  /// No description provided for @v2Saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存到本机'**
  String get v2Saved;

  /// No description provided for @v2SaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get v2SaveFailed;

  /// No description provided for @v2LastAction.
  ///
  /// In zh, this message translates to:
  /// **'上次操作'**
  String get v2LastAction;

  /// No description provided for @v2GrowthChartRange.
  ///
  /// In zh, this message translates to:
  /// **'显示最近 {count} 场，共 {total} 场'**
  String v2GrowthChartRange(int count, int total);

  /// No description provided for @v2SafetyWriteError.
  ///
  /// In zh, this message translates to:
  /// **'未能保存并验证替换前的安全副本，本机数据未替换。请检查存储空间后重试。'**
  String get v2SafetyWriteError;

  /// No description provided for @v2SafetyLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取安全副本，请重试。'**
  String get v2SafetyLoadError;

  /// No description provided for @v2BackupRows.
  ///
  /// In zh, this message translates to:
  /// **'行'**
  String get v2BackupRows;

  /// No description provided for @v2BackupCapacityError.
  ///
  /// In zh, this message translates to:
  /// **'备份超过支持容量（当前 {measured}，上限 {limit}）。原数据已保留。'**
  String v2BackupCapacityError(String measured, String limit);

  /// No description provided for @v2SwapSides.
  ///
  /// In zh, this message translates to:
  /// **'交换双方'**
  String get v2SwapSides;

  /// No description provided for @v2PresetApplied.
  ///
  /// In zh, this message translates to:
  /// **'已沿用双方和规则，还可以调整'**
  String get v2PresetApplied;

  /// No description provided for @v2RulesSummary.
  ///
  /// In zh, this message translates to:
  /// **'规则概览'**
  String get v2RulesSummary;

  /// No description provided for @v2StartFailed.
  ///
  /// In zh, this message translates to:
  /// **'比赛未能开始，请重试。'**
  String get v2StartFailed;

  /// No description provided for @v2PointsDifference.
  ///
  /// In zh, this message translates to:
  /// **'最近两场得分差值'**
  String get v2PointsDifference;

  /// No description provided for @v2MarginDifference.
  ///
  /// In zh, this message translates to:
  /// **'最近两场分差变化'**
  String get v2MarginDifference;

  /// No description provided for @v2Matches.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get v2Matches;

  /// No description provided for @v2RecentMatches.
  ///
  /// In zh, this message translates to:
  /// **'最近三场'**
  String get v2RecentMatches;

  /// No description provided for @v2RecentPreset.
  ///
  /// In zh, this message translates to:
  /// **'沿用上场设置'**
  String get v2RecentPreset;

  /// No description provided for @v2Result.
  ///
  /// In zh, this message translates to:
  /// **'赛果'**
  String get v2Result;

  /// No description provided for @v2Rematch.
  ///
  /// In zh, this message translates to:
  /// **'再来一场'**
  String get v2Rematch;

  /// No description provided for @v2Share.
  ///
  /// In zh, this message translates to:
  /// **'分享战报'**
  String get v2Share;

  /// No description provided for @v2Replay.
  ///
  /// In zh, this message translates to:
  /// **'完整复盘'**
  String get v2Replay;

  /// No description provided for @v2CoverageTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录范围'**
  String get v2CoverageTitle;

  /// No description provided for @v2CoverageScores.
  ///
  /// In zh, this message translates to:
  /// **'主要记分'**
  String get v2CoverageScores;

  /// No description provided for @v2CoverageComplete.
  ///
  /// In zh, this message translates to:
  /// **'记录全部投篮与罚球'**
  String get v2CoverageComplete;

  /// No description provided for @v2CoverageHelp.
  ///
  /// In zh, this message translates to:
  /// **'主要记分不显示命中率。完整记录需记下每次投篮和罚球，包括未命中。'**
  String get v2CoverageHelp;

  /// No description provided for @v2CorrectCoverage.
  ///
  /// In zh, this message translates to:
  /// **'纠正记录范围'**
  String get v2CorrectCoverage;

  /// No description provided for @v2CoverageReason.
  ///
  /// In zh, this message translates to:
  /// **'记录范围纠正'**
  String get v2CoverageReason;

  /// No description provided for @v2FieldGoalPercentage.
  ///
  /// In zh, this message translates to:
  /// **'运动战命中率'**
  String get v2FieldGoalPercentage;

  /// No description provided for @v2FreeThrowPercentage.
  ///
  /// In zh, this message translates to:
  /// **'罚球命中率'**
  String get v2FreeThrowPercentage;

  /// No description provided for @v2RecordedSample.
  ///
  /// In zh, this message translates to:
  /// **'以下图表仅表示已记录的样本'**
  String get v2RecordedSample;

  /// No description provided for @v2LocationScope.
  ///
  /// In zh, this message translates to:
  /// **'已确认运动战落点 / 已记录运动战出手'**
  String get v2LocationScope;

  /// No description provided for @v2SavePlayer.
  ///
  /// In zh, this message translates to:
  /// **'保存到球员档案'**
  String get v2SavePlayer;

  /// No description provided for @v2CreatePlayer.
  ///
  /// In zh, this message translates to:
  /// **'新建球员档案'**
  String get v2CreatePlayer;

  /// No description provided for @v2SelectPlayer.
  ///
  /// In zh, this message translates to:
  /// **'选择已有球员'**
  String get v2SelectPlayer;

  /// No description provided for @v2PlayerSaved.
  ///
  /// In zh, this message translates to:
  /// **'已关联球员档案，本场姓名不变'**
  String get v2PlayerSaved;

  /// No description provided for @v2Retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get v2Retry;

  /// No description provided for @v2GuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'快速上手'**
  String get v2GuideTitle;

  /// No description provided for @v2GuideScore.
  ///
  /// In zh, this message translates to:
  /// **'直接记分'**
  String get v2GuideScore;

  /// No description provided for @v2GuideScoreBody.
  ///
  /// In zh, this message translates to:
  /// **'点双方的 +1、+2、+3 即可记分。'**
  String get v2GuideScoreBody;

  /// No description provided for @v2GuideLocation.
  ///
  /// In zh, this message translates to:
  /// **'记落点和未命中'**
  String get v2GuideLocation;

  /// No description provided for @v2GuideLocationBody.
  ///
  /// In zh, this message translates to:
  /// **'可以先点球场再记分，也可以记分后在 10 秒内补落点。未命中也能记。'**
  String get v2GuideLocationBody;

  /// No description provided for @v2GuideUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销和结束比赛'**
  String get v2GuideUndo;

  /// No description provided for @v2GuideUndoBody.
  ///
  /// In zh, this message translates to:
  /// **'点撤销可退回上一步。打完后，点顶部结束比赛，再确认这场投篮是否记全。'**
  String get v2GuideUndoBody;

  /// No description provided for @v2GuideSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get v2GuideSkip;

  /// No description provided for @v2GuideNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get v2GuideNext;

  /// No description provided for @v2GuideDone.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get v2GuideDone;

  /// No description provided for @v2AbandonedMatch.
  ///
  /// In zh, this message translates to:
  /// **'比赛未完赛'**
  String get v2AbandonedMatch;

  /// No description provided for @v2AbandonedMatchHelp.
  ///
  /// In zh, this message translates to:
  /// **'已保存的记录仍可复盘；本场不计入已完成比赛统计。'**
  String get v2AbandonedMatchHelp;

  /// No description provided for @v2SafetyTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复安全副本'**
  String get v2SafetyTitle;

  /// No description provided for @v2SafetyHelp.
  ///
  /// In zh, this message translates to:
  /// **'安全副本是替换前自动保存的本机数据备份，保留最近两份，可在这里恢复。恢复前也会先保存并验证当前数据的副本。'**
  String get v2SafetyHelp;

  /// No description provided for @v2SafetyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚无安全副本'**
  String get v2SafetyEmpty;

  /// No description provided for @v2SafetyRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复这份副本'**
  String get v2SafetyRestore;

  /// No description provided for @v2SafetyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'这份副本将替换全部本机数据。球豆会先保存并验证当前数据的安全副本，失败就不会替换。请先结束正在进行的比赛。'**
  String get v2SafetyConfirm;

  /// No description provided for @v2GrowthSample.
  ///
  /// In zh, this message translates to:
  /// **'按比赛顺序显示运动战命中率；空缺表示记录不完整或无出手。'**
  String get v2GrowthSample;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'球豆'**
  String get appName;

  /// No description provided for @startScoring.
  ///
  /// In zh, this message translates to:
  /// **'开始计分'**
  String get startScoring;

  /// No description provided for @replayHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get replayHistory;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @projectDetails.
  ///
  /// In zh, this message translates to:
  /// **'项目详情'**
  String get projectDetails;

  /// No description provided for @ruleTargetReached.
  ///
  /// In zh, this message translates to:
  /// **'已达到目标分，要结束还是继续？'**
  String get ruleTargetReached;

  /// No description provided for @ruleWinByTwoRequired.
  ///
  /// In zh, this message translates to:
  /// **'已达到目标分，还要领先 2 分才能赢，请继续比赛。'**
  String get ruleWinByTwoRequired;

  /// No description provided for @ruleMatchPoint.
  ///
  /// In zh, this message translates to:
  /// **'赛点'**
  String get ruleMatchPoint;

  /// No description provided for @rulePossessionSuggested.
  ///
  /// In zh, this message translates to:
  /// **'球权建议'**
  String get rulePossessionSuggested;

  /// No description provided for @ruleFoulLimit.
  ///
  /// In zh, this message translates to:
  /// **'{side}犯规已达 {limit} 次上限'**
  String ruleFoulLimit(Object limit, Object side);

  /// No description provided for @finishOrContinueOvertime.
  ///
  /// In zh, this message translates to:
  /// **'常规时间结束，请确认结束或进入加时'**
  String get finishOrContinueOvertime;

  /// No description provided for @matchDecisionTitle.
  ///
  /// In zh, this message translates to:
  /// **'比赛决策'**
  String get matchDecisionTitle;

  /// No description provided for @continueMatch.
  ///
  /// In zh, this message translates to:
  /// **'继续比赛'**
  String get continueMatch;

  /// No description provided for @finishMatch.
  ///
  /// In zh, this message translates to:
  /// **'结束比赛'**
  String get finishMatch;

  /// No description provided for @confirmFinalScoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认最终比分'**
  String get confirmFinalScoreTitle;

  /// No description provided for @confirmFinalScoreBody.
  ///
  /// In zh, this message translates to:
  /// **'结束后将锁定当前比分并关闭进行中的比赛。'**
  String get confirmFinalScoreBody;

  /// No description provided for @finalScoreLine.
  ///
  /// In zh, this message translates to:
  /// **'{redName} {redScore} : {blueScore} {blueName}'**
  String finalScoreLine(
    Object blueName,
    Object blueScore,
    Object redName,
    Object redScore,
  );

  /// No description provided for @cancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelAction;

  /// No description provided for @actionFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请重试。'**
  String get actionFailedRetry;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近比赛'**
  String get historyTitle;

  /// No description provided for @historyHomeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回主页'**
  String get historyHomeTooltip;

  /// No description provided for @replayExitToScoringTooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回计分'**
  String get replayExitToScoringTooltip;

  /// No description provided for @replayExitToHistoryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回历史'**
  String get replayExitToHistoryTooltip;

  /// No description provided for @historySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索球员或比赛'**
  String get historySearchHint;

  /// No description provided for @historyCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get historyCompleted;

  /// No description provided for @historyArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get historyArchived;

  /// No description provided for @historyAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get historyAll;

  /// No description provided for @historyResetFilters.
  ///
  /// In zh, this message translates to:
  /// **'重置筛选'**
  String get historyResetFilters;

  /// No description provided for @historyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无比赛记录'**
  String get historyEmpty;

  /// No description provided for @historyEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'完成一场比赛后，记录会显示在这里。'**
  String get historyEmptyDescription;

  /// No description provided for @historyActiveMatch.
  ///
  /// In zh, this message translates to:
  /// **'进行中的比赛'**
  String get historyActiveMatch;

  /// No description provided for @historyResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get historyResume;

  /// No description provided for @historyActions.
  ///
  /// In zh, this message translates to:
  /// **'比赛操作'**
  String get historyActions;

  /// No description provided for @historyArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get historyArchive;

  /// No description provided for @historyUnarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get historyUnarchive;

  /// No description provided for @historyDeletePermanently.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get historyDeletePermanently;

  /// No description provided for @historyDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久删除比赛？'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'这场比赛及其事件、投篮落点和操作记录都会永久删除，无法恢复。'**
  String get historyDeleteBody;

  /// No description provided for @historyLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get historyLoadMore;

  /// No description provided for @historyMoreFilters.
  ///
  /// In zh, this message translates to:
  /// **'更多筛选'**
  String get historyMoreFilters;

  /// No description provided for @historyAdvancedTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级筛选'**
  String get historyAdvancedTitle;

  /// No description provided for @historyRuleLabel.
  ///
  /// In zh, this message translates to:
  /// **'规则名称'**
  String get historyRuleLabel;

  /// No description provided for @historyRecordingModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'记录模式'**
  String get historyRecordingModeLabel;

  /// No description provided for @historyAllModes.
  ///
  /// In zh, this message translates to:
  /// **'全部模式'**
  String get historyAllModes;

  /// No description provided for @historySimpleMode.
  ///
  /// In zh, this message translates to:
  /// **'简洁记录'**
  String get historySimpleMode;

  /// No description provided for @historyDetailedMode.
  ///
  /// In zh, this message translates to:
  /// **'详细记录'**
  String get historyDetailedMode;

  /// No description provided for @historyStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get historyStartDate;

  /// No description provided for @historyEndDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get historyEndDate;

  /// No description provided for @historyClearDates.
  ///
  /// In zh, this message translates to:
  /// **'清除日期'**
  String get historyClearDates;

  /// No description provided for @historyApplyFilters.
  ///
  /// In zh, this message translates to:
  /// **'应用筛选'**
  String get historyApplyFilters;

  /// No description provided for @historyLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法加载比赛记录。'**
  String get historyLoadError;

  /// No description provided for @historyRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get historyRetry;

  /// No description provided for @historyRule.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get historyRule;

  /// No description provided for @historyDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get historyDuration;

  /// No description provided for @historyResult.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get historyResult;

  /// No description provided for @historyDraw.
  ///
  /// In zh, this message translates to:
  /// **'平局'**
  String get historyDraw;

  /// No description provided for @historyWinner.
  ///
  /// In zh, this message translates to:
  /// **'胜者：{winnerName}'**
  String historyWinner(Object winnerName);

  /// No description provided for @historyLocationCompleteness.
  ///
  /// In zh, this message translates to:
  /// **'落点记录比例'**
  String get historyLocationCompleteness;

  /// No description provided for @replayTitle.
  ///
  /// In zh, this message translates to:
  /// **'比赛复盘'**
  String get replayTitle;

  /// No description provided for @replayExportTooltip.
  ///
  /// In zh, this message translates to:
  /// **'导出复盘图'**
  String get replayExportTooltip;

  /// No description provided for @replayAuditTooltip.
  ///
  /// In zh, this message translates to:
  /// **'操作记录'**
  String get replayAuditTooltip;

  /// No description provided for @replayEditMode.
  ///
  /// In zh, this message translates to:
  /// **'编辑模式'**
  String get replayEditMode;

  /// No description provided for @replayReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅查看'**
  String get replayReadOnly;

  /// No description provided for @replayFinished.
  ///
  /// In zh, this message translates to:
  /// **'终场'**
  String get replayFinished;

  /// No description provided for @replayInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get replayInProgress;

  /// No description provided for @replayExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'复盘分享图'**
  String get replayExportTitle;

  /// No description provided for @replayExportDescription.
  ///
  /// In zh, this message translates to:
  /// **'将落点图和比赛分析合成一张本地图片'**
  String get replayExportDescription;

  /// No description provided for @replayClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get replayClose;

  /// No description provided for @replayGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get replayGenerating;

  /// No description provided for @replayGenerateShare.
  ///
  /// In zh, this message translates to:
  /// **'生成并分享'**
  String get replayGenerateShare;

  /// No description provided for @replayExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片生成或分享失败，请重试'**
  String get replayExportFailed;

  /// No description provided for @replayExportAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'本场分析'**
  String get replayExportAnalysis;

  /// No description provided for @replayExportShotLocations.
  ///
  /// In zh, this message translates to:
  /// **'落点记录'**
  String get replayExportShotLocations;

  /// No description provided for @replayExportShootingPercentage.
  ///
  /// In zh, this message translates to:
  /// **'投篮命中率'**
  String get replayExportShootingPercentage;

  /// No description provided for @replayExportLeadChanges.
  ///
  /// In zh, this message translates to:
  /// **'领先变化'**
  String get replayExportLeadChanges;

  /// No description provided for @replayExportLargestLead.
  ///
  /// In zh, this message translates to:
  /// **'最大领先'**
  String get replayExportLargestLead;

  /// No description provided for @replayExportKeyMoments.
  ///
  /// In zh, this message translates to:
  /// **'关键节点'**
  String get replayExportKeyMoments;

  /// No description provided for @replayNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get replayNoData;

  /// No description provided for @replayExportLeadChangesValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String replayExportLeadChangesValue(Object count);

  /// No description provided for @replayExportKeyMomentsValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String replayExportKeyMomentsValue(Object count);

  /// No description provided for @replayCourt.
  ///
  /// In zh, this message translates to:
  /// **'落点图'**
  String get replayCourt;

  /// No description provided for @replaySaveLocation.
  ///
  /// In zh, this message translates to:
  /// **'保存落点'**
  String get replaySaveLocation;

  /// No description provided for @replayOverview.
  ///
  /// In zh, this message translates to:
  /// **'总览'**
  String get replayOverview;

  /// No description provided for @replayDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get replayDuration;

  /// No description provided for @replayScoringEvents.
  ///
  /// In zh, this message translates to:
  /// **'得分记录'**
  String get replayScoringEvents;

  /// No description provided for @replayFouls.
  ///
  /// In zh, this message translates to:
  /// **'犯规'**
  String get replayFouls;

  /// No description provided for @replayLocationCompleteness.
  ///
  /// In zh, this message translates to:
  /// **'落点记录比例'**
  String get replayLocationCompleteness;

  /// No description provided for @replayPossession.
  ///
  /// In zh, this message translates to:
  /// **'球权记录'**
  String get replayPossession;

  /// No description provided for @replayFinishedBoundary.
  ///
  /// In zh, this message translates to:
  /// **'比赛已结束'**
  String get replayFinishedBoundary;

  /// No description provided for @replayInProgressBoundary.
  ///
  /// In zh, this message translates to:
  /// **'比赛未完成'**
  String get replayInProgressBoundary;

  /// No description provided for @replayNoPossession.
  ///
  /// In zh, this message translates to:
  /// **'暂无球权记录'**
  String get replayNoPossession;

  /// No description provided for @replayPossessionManual.
  ///
  /// In zh, this message translates to:
  /// **'人工'**
  String get replayPossessionManual;

  /// No description provided for @replayPossessionSuggested.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get replayPossessionSuggested;

  /// No description provided for @replayPossessionCurrent.
  ///
  /// In zh, this message translates to:
  /// **'未记录结束时间'**
  String get replayPossessionCurrent;

  /// No description provided for @replayPossessionEnded.
  ///
  /// In zh, this message translates to:
  /// **'结束 {time}'**
  String replayPossessionEnded(Object time);

  /// No description provided for @replayPossessionReason.
  ///
  /// In zh, this message translates to:
  /// **'原因：{reason}'**
  String replayPossessionReason(Object reason);

  /// No description provided for @replayNoReason.
  ///
  /// In zh, this message translates to:
  /// **'未填写原因'**
  String get replayNoReason;

  /// No description provided for @replaySuggestedReason.
  ///
  /// In zh, this message translates to:
  /// **'命中后根据规则建议球权'**
  String get replaySuggestedReason;

  /// No description provided for @replayTimeline.
  ///
  /// In zh, this message translates to:
  /// **'比赛记录'**
  String get replayTimeline;

  /// No description provided for @replayFilters.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get replayFilters;

  /// No description provided for @replayNoEvents.
  ///
  /// In zh, this message translates to:
  /// **'没有符合筛选条件的记录'**
  String get replayNoEvents;

  /// No description provided for @replayFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get replayFilterAll;

  /// No description provided for @replayFilterScores.
  ///
  /// In zh, this message translates to:
  /// **'得分'**
  String get replayFilterScores;

  /// No description provided for @replayFilterFouls.
  ///
  /// In zh, this message translates to:
  /// **'犯规'**
  String get replayFilterFouls;

  /// No description provided for @replayFilterMisses.
  ///
  /// In zh, this message translates to:
  /// **'未中'**
  String get replayFilterMisses;

  /// No description provided for @replayFilterOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get replayFilterOther;

  /// No description provided for @replayFilterBoth.
  ///
  /// In zh, this message translates to:
  /// **'双方'**
  String get replayFilterBoth;

  /// No description provided for @replayFilterRed.
  ///
  /// In zh, this message translates to:
  /// **'红方'**
  String get replayFilterRed;

  /// No description provided for @replayFilterBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝方'**
  String get replayFilterBlue;

  /// No description provided for @replayFilterShowDeleted.
  ///
  /// In zh, this message translates to:
  /// **'显示已删除'**
  String get replayFilterShowDeleted;

  /// No description provided for @replayFilterHideDeleted.
  ///
  /// In zh, this message translates to:
  /// **'隐藏已删除'**
  String get replayFilterHideDeleted;

  /// No description provided for @replayFilterMade.
  ///
  /// In zh, this message translates to:
  /// **'命中'**
  String get replayFilterMade;

  /// No description provided for @replayFilterMissed.
  ///
  /// In zh, this message translates to:
  /// **'未中'**
  String get replayFilterMissed;

  /// No description provided for @replayFilterPoints.
  ///
  /// In zh, this message translates to:
  /// **'分值'**
  String get replayFilterPoints;

  /// No description provided for @replayActionScore.
  ///
  /// In zh, this message translates to:
  /// **'+{points} 分'**
  String replayActionScore(Object points);

  /// No description provided for @replayActionFoul.
  ///
  /// In zh, this message translates to:
  /// **'犯规'**
  String get replayActionFoul;

  /// No description provided for @replayActionMiss.
  ///
  /// In zh, this message translates to:
  /// **'投篮未中'**
  String get replayActionMiss;

  /// No description provided for @replayActionRecord.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get replayActionRecord;

  /// No description provided for @replayMatchSide.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get replayMatchSide;

  /// No description provided for @replayDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get replayDeleted;

  /// No description provided for @replayClockPosition.
  ///
  /// In zh, this message translates to:
  /// **'比赛时钟 {seconds} 秒'**
  String replayClockPosition(Object seconds);

  /// No description provided for @replayEditorTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑记录'**
  String get replayEditorTitle;

  /// No description provided for @replayEditorSide.
  ///
  /// In zh, this message translates to:
  /// **'所属方'**
  String get replayEditorSide;

  /// No description provided for @replayEditorEventKind.
  ///
  /// In zh, this message translates to:
  /// **'记录类型'**
  String get replayEditorEventKind;

  /// No description provided for @replayEditorPoints.
  ///
  /// In zh, this message translates to:
  /// **'分值'**
  String get replayEditorPoints;

  /// No description provided for @replayEditorOutcome.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get replayEditorOutcome;

  /// No description provided for @replayEditorNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get replayEditorNote;

  /// No description provided for @replayEditorCustomLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义标签'**
  String get replayEditorCustomLabel;

  /// No description provided for @replayEditorClock.
  ///
  /// In zh, this message translates to:
  /// **'比赛时钟位置（秒）'**
  String get replayEditorClock;

  /// No description provided for @replayEditorLocationX.
  ///
  /// In zh, this message translates to:
  /// **'落点 X'**
  String get replayEditorLocationX;

  /// No description provided for @replayEditorLocationY.
  ///
  /// In zh, this message translates to:
  /// **'落点 Y'**
  String get replayEditorLocationY;

  /// No description provided for @replayLocationEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存落点修改'**
  String get replayLocationEditTitle;

  /// No description provided for @replayLocationSaveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get replayLocationSaveAction;

  /// No description provided for @replayEditorReason.
  ///
  /// In zh, this message translates to:
  /// **'修改原因（可选）'**
  String get replayEditorReason;

  /// No description provided for @replayEditorDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get replayEditorDelete;

  /// No description provided for @replayEditorRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get replayEditorRestore;

  /// No description provided for @replayEditorSave.
  ///
  /// In zh, this message translates to:
  /// **'保存修改'**
  String get replayEditorSave;

  /// No description provided for @replayEditorSaveNote.
  ///
  /// In zh, this message translates to:
  /// **'保存备注'**
  String get replayEditorSaveNote;

  /// No description provided for @replayEditorInvalidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效数字。'**
  String get replayEditorInvalidNumber;

  /// No description provided for @replayEditorLocationRange.
  ///
  /// In zh, this message translates to:
  /// **'落点数值必须在 0 到 1 之间。'**
  String get replayEditorLocationRange;

  /// No description provided for @replayEditorDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这条记录？'**
  String get replayEditorDeleteTitle;

  /// No description provided for @replayEditorDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后，这条记录不再计入比分和统计，操作记录会保留。之后可显示已删除记录，再将它恢复。'**
  String get replayEditorDeleteBody;

  /// No description provided for @replayEditorConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get replayEditorConfirmDelete;

  /// No description provided for @replayEditorRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复这条记录？'**
  String get replayEditorRestoreTitle;

  /// No description provided for @replayEditorRestoreBody.
  ///
  /// In zh, this message translates to:
  /// **'恢复后，这条记录会重新计入比分和统计。'**
  String get replayEditorRestoreBody;

  /// No description provided for @replayEditorConfirmRestore.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get replayEditorConfirmRestore;

  /// No description provided for @replayAuditTitle.
  ///
  /// In zh, this message translates to:
  /// **'操作记录'**
  String get replayAuditTitle;

  /// No description provided for @replayAuditEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无操作记录'**
  String get replayAuditEmpty;

  /// No description provided for @replayAuditReason.
  ///
  /// In zh, this message translates to:
  /// **'原因：{reason}'**
  String replayAuditReason(Object reason);

  /// No description provided for @replayAuditNoReason.
  ///
  /// In zh, this message translates to:
  /// **'未填写原因'**
  String get replayAuditNoReason;

  /// No description provided for @replayAuditActionCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get replayAuditActionCreate;

  /// No description provided for @replayAuditActionUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get replayAuditActionUndo;

  /// No description provided for @replayAuditActionEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get replayAuditActionEdit;

  /// No description provided for @replayAuditActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get replayAuditActionDelete;

  /// No description provided for @replayAuditActionImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get replayAuditActionImport;

  /// No description provided for @replayAuditActionRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get replayAuditActionRestore;

  /// No description provided for @replayAuditActionCommand.
  ///
  /// In zh, this message translates to:
  /// **'执行操作'**
  String get replayAuditActionCommand;

  /// No description provided for @replayAuditActionLocate.
  ///
  /// In zh, this message translates to:
  /// **'设置落点'**
  String get replayAuditActionLocate;

  /// No description provided for @replayAuditActionPossession.
  ///
  /// In zh, this message translates to:
  /// **'更新球权'**
  String get replayAuditActionPossession;

  /// No description provided for @replayAuditActionPossessionSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议球权'**
  String get replayAuditActionPossessionSuggestion;

  /// No description provided for @replayAuditActionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知操作'**
  String get replayAuditActionUnknown;

  /// No description provided for @replayAuditTargetEvent.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get replayAuditTargetEvent;

  /// No description provided for @replayAuditTargetLocation.
  ///
  /// In zh, this message translates to:
  /// **'落点'**
  String get replayAuditTargetLocation;

  /// No description provided for @replayAuditTargetMatch.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get replayAuditTargetMatch;

  /// No description provided for @replayAuditTargetCommand.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get replayAuditTargetCommand;

  /// No description provided for @replayAuditFieldType.
  ///
  /// In zh, this message translates to:
  /// **'记录类型'**
  String get replayAuditFieldType;

  /// No description provided for @replayAuditFieldSide.
  ///
  /// In zh, this message translates to:
  /// **'所属方'**
  String get replayAuditFieldSide;

  /// No description provided for @replayAuditFieldPoints.
  ///
  /// In zh, this message translates to:
  /// **'分数'**
  String get replayAuditFieldPoints;

  /// No description provided for @replayAuditFieldOutcome.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get replayAuditFieldOutcome;

  /// No description provided for @replayAuditFieldNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get replayAuditFieldNote;

  /// No description provided for @replayAuditFieldCustomLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义标签'**
  String get replayAuditFieldCustomLabel;

  /// No description provided for @replayAuditFieldClock.
  ///
  /// In zh, this message translates to:
  /// **'比赛时钟'**
  String get replayAuditFieldClock;

  /// No description provided for @replayAuditFieldDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get replayAuditFieldDeleted;

  /// No description provided for @replayAuditFieldX.
  ///
  /// In zh, this message translates to:
  /// **'落点 X'**
  String get replayAuditFieldX;

  /// No description provided for @replayAuditFieldY.
  ///
  /// In zh, this message translates to:
  /// **'落点 Y'**
  String get replayAuditFieldY;

  /// No description provided for @replayAuditValueNone.
  ///
  /// In zh, this message translates to:
  /// **'—'**
  String get replayAuditValueNone;

  /// No description provided for @replayAuditValueDeleted.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get replayAuditValueDeleted;

  /// No description provided for @replayAuditValueActive.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get replayAuditValueActive;

  /// No description provided for @replayAnalyticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'比赛分析'**
  String get replayAnalyticsTitle;

  /// No description provided for @replayAnalyticsLeadChanges.
  ///
  /// In zh, this message translates to:
  /// **'领先变化'**
  String get replayAnalyticsLeadChanges;

  /// No description provided for @replayAnalyticsLargestLead.
  ///
  /// In zh, this message translates to:
  /// **'最大领先'**
  String get replayAnalyticsLargestLead;

  /// No description provided for @replayAnalyticsShootingPercentage.
  ///
  /// In zh, this message translates to:
  /// **'投篮命中率'**
  String get replayAnalyticsShootingPercentage;

  /// No description provided for @replayAnalyticsKeyMoments.
  ///
  /// In zh, this message translates to:
  /// **'关键时刻'**
  String get replayAnalyticsKeyMoments;

  /// No description provided for @replayAnalyticsNoAttempts.
  ///
  /// In zh, this message translates to:
  /// **'暂无出手'**
  String get replayAnalyticsNoAttempts;

  /// No description provided for @replayAnalyticsScoringFlow.
  ///
  /// In zh, this message translates to:
  /// **'比分走势'**
  String get replayAnalyticsScoringFlow;

  /// No description provided for @replayAnalyticsNoScoringEvents.
  ///
  /// In zh, this message translates to:
  /// **'本场暂无得分记录'**
  String get replayAnalyticsNoScoringEvents;

  /// No description provided for @replayAnalyticsKeyPossessions.
  ///
  /// In zh, this message translates to:
  /// **'关键回合'**
  String get replayAnalyticsKeyPossessions;

  /// No description provided for @replayAnalyticsNoKeyPossessions.
  ///
  /// In zh, this message translates to:
  /// **'本场暂无关键回合'**
  String get replayAnalyticsNoKeyPossessions;

  /// No description provided for @replayAnalyticsScoreSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{side} 得 {points} 分，{redScore} 比 {blueScore}'**
  String replayAnalyticsScoreSemantics(
    Object blueScore,
    Object points,
    Object redScore,
    Object side,
  );

  /// No description provided for @replayAnalyticsTie.
  ///
  /// In zh, this message translates to:
  /// **'扳平比分'**
  String get replayAnalyticsTie;

  /// No description provided for @replayAnalyticsOvertake.
  ///
  /// In zh, this message translates to:
  /// **'完成反超'**
  String get replayAnalyticsOvertake;

  /// No description provided for @replayAnalyticsMatchPoint.
  ///
  /// In zh, this message translates to:
  /// **'到达赛点'**
  String get replayAnalyticsMatchPoint;

  /// No description provided for @replayAnalyticsScoringRun.
  ///
  /// In zh, this message translates to:
  /// **'连续得分'**
  String get replayAnalyticsScoringRun;

  /// No description provided for @replayAnalyticsShotRecord.
  ///
  /// In zh, this message translates to:
  /// **'投篮记录'**
  String get replayAnalyticsShotRecord;

  /// No description provided for @replayAnalyticsRecordedAttempts.
  ///
  /// In zh, this message translates to:
  /// **'记录的出手'**
  String get replayAnalyticsRecordedAttempts;

  /// No description provided for @replayAnalyticsIncompleteShooting.
  ///
  /// In zh, this message translates to:
  /// **'记录不完整，暂不显示命中率'**
  String get replayAnalyticsIncompleteShooting;

  /// No description provided for @replayAnalyticsFieldGoals.
  ///
  /// In zh, this message translates to:
  /// **'投篮'**
  String get replayAnalyticsFieldGoals;

  /// No description provided for @replayAnalyticsFreeThrows.
  ///
  /// In zh, this message translates to:
  /// **'罚球'**
  String get replayAnalyticsFreeThrows;

  /// No description provided for @replayAnalyticsFouls.
  ///
  /// In zh, this message translates to:
  /// **'犯规'**
  String get replayAnalyticsFouls;

  /// No description provided for @replayAnalyticsPossessions.
  ///
  /// In zh, this message translates to:
  /// **'球权'**
  String get replayAnalyticsPossessions;

  /// No description provided for @replayAnalyticsTrackingCoverage.
  ///
  /// In zh, this message translates to:
  /// **'记录范围'**
  String get replayAnalyticsTrackingCoverage;

  /// No description provided for @replayAnalyticsLocationCoverage.
  ///
  /// In zh, this message translates to:
  /// **'位置覆盖'**
  String get replayAnalyticsLocationCoverage;

  /// No description provided for @replayAnalyticsShotZones.
  ///
  /// In zh, this message translates to:
  /// **'出手区域'**
  String get replayAnalyticsShotZones;

  /// No description provided for @replayAnalyticsZoneRestrictedArea.
  ///
  /// In zh, this message translates to:
  /// **'篮下'**
  String get replayAnalyticsZoneRestrictedArea;

  /// No description provided for @replayAnalyticsZonePaint.
  ///
  /// In zh, this message translates to:
  /// **'油漆区'**
  String get replayAnalyticsZonePaint;

  /// No description provided for @replayAnalyticsZoneMidRange.
  ///
  /// In zh, this message translates to:
  /// **'中距离'**
  String get replayAnalyticsZoneMidRange;

  /// No description provided for @replayAnalyticsZoneCornerThree.
  ///
  /// In zh, this message translates to:
  /// **'底角三分'**
  String get replayAnalyticsZoneCornerThree;

  /// No description provided for @replayAnalyticsZoneWingThree.
  ///
  /// In zh, this message translates to:
  /// **'侧翼三分'**
  String get replayAnalyticsZoneWingThree;

  /// No description provided for @replayAnalyticsZoneTopThree.
  ///
  /// In zh, this message translates to:
  /// **'弧顶三分'**
  String get replayAnalyticsZoneTopThree;

  /// No description provided for @replayAnalyticsZoneUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知区域'**
  String get replayAnalyticsZoneUnknown;

  /// No description provided for @replayAnalyticsTrackingNone.
  ///
  /// In zh, this message translates to:
  /// **'无记录'**
  String get replayAnalyticsTrackingNone;

  /// No description provided for @replayAnalyticsTrackingScoresOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅记录得分'**
  String get replayAnalyticsTrackingScoresOnly;

  /// No description provided for @replayAnalyticsTrackingShotAttempts.
  ///
  /// In zh, this message translates to:
  /// **'记录出手结果'**
  String get replayAnalyticsTrackingShotAttempts;

  /// No description provided for @replayAnalyticsTrackingLocations.
  ///
  /// In zh, this message translates to:
  /// **'记录出手与位置'**
  String get replayAnalyticsTrackingLocations;

  /// No description provided for @replayAnalyticsTrackingFull.
  ///
  /// In zh, this message translates to:
  /// **'记录完整'**
  String get replayAnalyticsTrackingFull;

  /// No description provided for @playerAnalyticsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'查看球员分析'**
  String get playerAnalyticsTooltip;

  /// No description provided for @playerAnalyticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'球员分析'**
  String get playerAnalyticsTitle;

  /// No description provided for @playerAnalyticsWindow.
  ///
  /// In zh, this message translates to:
  /// **'统计时段'**
  String get playerAnalyticsWindow;

  /// No description provided for @playerAnalyticsSevenDays.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天'**
  String get playerAnalyticsSevenDays;

  /// No description provided for @playerAnalyticsThirtyDays.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天'**
  String get playerAnalyticsThirtyDays;

  /// No description provided for @playerAnalyticsNinetyDays.
  ///
  /// In zh, this message translates to:
  /// **'近 90 天'**
  String get playerAnalyticsNinetyDays;

  /// No description provided for @playerAnalyticsAllTime.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get playerAnalyticsAllTime;

  /// No description provided for @playerAnalyticsOpponent.
  ///
  /// In zh, this message translates to:
  /// **'对手'**
  String get playerAnalyticsOpponent;

  /// No description provided for @playerAnalyticsAllOpponents.
  ///
  /// In zh, this message translates to:
  /// **'所有对手'**
  String get playerAnalyticsAllOpponents;

  /// No description provided for @playerAnalyticsGrowth.
  ///
  /// In zh, this message translates to:
  /// **'成长趋势'**
  String get playerAnalyticsGrowth;

  /// No description provided for @playerAnalyticsRecentChange.
  ///
  /// In zh, this message translates to:
  /// **'近期变化'**
  String get playerAnalyticsRecentChange;

  /// No description provided for @playerAnalyticsAveragePoints.
  ///
  /// In zh, this message translates to:
  /// **'场均得分'**
  String get playerAnalyticsAveragePoints;

  /// No description provided for @playerAnalyticsAverageMargin.
  ///
  /// In zh, this message translates to:
  /// **'场均分差'**
  String get playerAnalyticsAverageMargin;

  /// No description provided for @playerAnalyticsRecord.
  ///
  /// In zh, this message translates to:
  /// **'胜负战绩'**
  String get playerAnalyticsRecord;

  /// No description provided for @playerAnalyticsMatches.
  ///
  /// In zh, this message translates to:
  /// **'场'**
  String get playerAnalyticsMatches;

  /// No description provided for @playerAnalyticsWins.
  ///
  /// In zh, this message translates to:
  /// **'胜'**
  String get playerAnalyticsWins;

  /// No description provided for @playerAnalyticsShootingTrend.
  ///
  /// In zh, this message translates to:
  /// **'投篮趋势'**
  String get playerAnalyticsShootingTrend;

  /// No description provided for @playerAnalyticsFieldGoals.
  ///
  /// In zh, this message translates to:
  /// **'投篮'**
  String get playerAnalyticsFieldGoals;

  /// No description provided for @playerAnalyticsFreeThrows.
  ///
  /// In zh, this message translates to:
  /// **'罚球'**
  String get playerAnalyticsFreeThrows;

  /// No description provided for @playerAnalyticsRecordedShots.
  ///
  /// In zh, this message translates to:
  /// **'记录出手'**
  String get playerAnalyticsRecordedShots;

  /// No description provided for @playerAnalyticsNoReliablePercentage.
  ///
  /// In zh, this message translates to:
  /// **'暂无可显示的投篮命中率，需要记录完整且有运动战出手的比赛。'**
  String get playerAnalyticsNoReliablePercentage;

  /// No description provided for @playerAnalyticsZoneHeatmap.
  ///
  /// In zh, this message translates to:
  /// **'出手区域'**
  String get playerAnalyticsZoneHeatmap;

  /// No description provided for @playerAnalyticsNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'该周期暂无已完成比赛'**
  String get playerAnalyticsNoMatches;

  /// No description provided for @playerAnalyticsNoTrend.
  ///
  /// In zh, this message translates to:
  /// **'暂无足够的趋势数据'**
  String get playerAnalyticsNoTrend;

  /// No description provided for @playerAnalyticsOpponentNone.
  ///
  /// In zh, this message translates to:
  /// **'不限对手'**
  String get playerAnalyticsOpponentNone;

  /// No description provided for @playerAnalyticsLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取分析数据'**
  String get playerAnalyticsLoadError;

  /// No description provided for @playerAnalyticsLoadErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'无法读取球员分析，请重试。'**
  String get playerAnalyticsLoadErrorBody;

  /// No description provided for @playerAnalyticsNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到球员'**
  String get playerAnalyticsNotFound;

  /// No description provided for @playerAnalyticsNotFoundBody.
  ///
  /// In zh, this message translates to:
  /// **'该球员档案可能已被删除。'**
  String get playerAnalyticsNotFoundBody;

  /// No description provided for @playerAnalyticsRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get playerAnalyticsRetry;

  /// No description provided for @playerComparisonOpen.
  ///
  /// In zh, this message translates to:
  /// **'比较'**
  String get playerComparisonOpen;

  /// No description provided for @playerComparisonTitle.
  ///
  /// In zh, this message translates to:
  /// **'球员比较'**
  String get playerComparisonTitle;

  /// No description provided for @playerComparisonMode.
  ///
  /// In zh, this message translates to:
  /// **'比较方式'**
  String get playerComparisonMode;

  /// No description provided for @playerComparisonMatchMode.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get playerComparisonMatchMode;

  /// No description provided for @playerComparisonWindowMode.
  ///
  /// In zh, this message translates to:
  /// **'时段'**
  String get playerComparisonWindowMode;

  /// No description provided for @playerComparisonMatchModeHint.
  ///
  /// In zh, this message translates to:
  /// **'选择该球员的两场已完成比赛进行比较。'**
  String get playerComparisonMatchModeHint;

  /// No description provided for @playerComparisonWindowModeHint.
  ///
  /// In zh, this message translates to:
  /// **'比较相邻且不重叠的两个时段，后一时段截止于打开此页面时。'**
  String get playerComparisonWindowModeHint;

  /// No description provided for @playerComparisonBaseline.
  ///
  /// In zh, this message translates to:
  /// **'参照数据'**
  String get playerComparisonBaseline;

  /// No description provided for @playerComparisonCurrent.
  ///
  /// In zh, this message translates to:
  /// **'比较数据'**
  String get playerComparisonCurrent;

  /// No description provided for @playerComparisonDifference.
  ///
  /// In zh, this message translates to:
  /// **'差值'**
  String get playerComparisonDifference;

  /// No description provided for @playerComparisonSelectBaseline.
  ///
  /// In zh, this message translates to:
  /// **'选择参照比赛'**
  String get playerComparisonSelectBaseline;

  /// No description provided for @playerComparisonSelectCurrent.
  ///
  /// In zh, this message translates to:
  /// **'选择比较比赛'**
  String get playerComparisonSelectCurrent;

  /// No description provided for @playerComparisonSwap.
  ///
  /// In zh, this message translates to:
  /// **'交换两场比赛'**
  String get playerComparisonSwap;

  /// No description provided for @playerComparisonChooseGame.
  ///
  /// In zh, this message translates to:
  /// **'选择比赛'**
  String get playerComparisonChooseGame;

  /// No description provided for @playerComparisonLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在比较'**
  String get playerComparisonLoading;

  /// No description provided for @playerComparisonLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取比较数据'**
  String get playerComparisonLoadError;

  /// No description provided for @playerComparisonLoadErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'无法读取比赛比较，请重试。'**
  String get playerComparisonLoadErrorBody;

  /// No description provided for @playerComparisonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get playerComparisonRetry;

  /// No description provided for @playerComparisonNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'暂无可比较比赛'**
  String get playerComparisonNoMatches;

  /// No description provided for @playerComparisonNoMatchesBody.
  ///
  /// In zh, this message translates to:
  /// **'先用该球员档案完成一场比赛，再来比较。'**
  String get playerComparisonNoMatchesBody;

  /// No description provided for @playerComparisonNeedTwoMatches.
  ///
  /// In zh, this message translates to:
  /// **'至少需要两场比赛'**
  String get playerComparisonNeedTwoMatches;

  /// No description provided for @playerComparisonNeedTwoMatchesBody.
  ///
  /// In zh, this message translates to:
  /// **'再用该球员档案完成一场比赛，即可比较两场比赛；现在也可以比较时段数据。'**
  String get playerComparisonNeedTwoMatchesBody;

  /// No description provided for @playerComparisonEmptyWindows.
  ///
  /// In zh, this message translates to:
  /// **'两个时段都没有比赛'**
  String get playerComparisonEmptyWindows;

  /// No description provided for @playerComparisonEmptyWindowsBody.
  ///
  /// In zh, this message translates to:
  /// **'试试更长的时段，或取消对手筛选。'**
  String get playerComparisonEmptyWindowsBody;

  /// No description provided for @playerComparisonBaselineEmpty.
  ///
  /// In zh, this message translates to:
  /// **'参照时段没有比赛。'**
  String get playerComparisonBaselineEmpty;

  /// No description provided for @playerComparisonCurrentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'比较时段没有比赛。'**
  String get playerComparisonCurrentEmpty;

  /// No description provided for @playerComparisonSummary.
  ///
  /// In zh, this message translates to:
  /// **'数据对比'**
  String get playerComparisonSummary;

  /// No description provided for @playerComparisonResult.
  ///
  /// In zh, this message translates to:
  /// **'胜负'**
  String get playerComparisonResult;

  /// No description provided for @playerComparisonMatchCount.
  ///
  /// In zh, this message translates to:
  /// **'场次'**
  String get playerComparisonMatchCount;

  /// No description provided for @playerComparisonWinRate.
  ///
  /// In zh, this message translates to:
  /// **'胜率'**
  String get playerComparisonWinRate;

  /// No description provided for @playerComparisonPoints.
  ///
  /// In zh, this message translates to:
  /// **'得分'**
  String get playerComparisonPoints;

  /// No description provided for @playerComparisonPointsPerGame.
  ///
  /// In zh, this message translates to:
  /// **'场均得分'**
  String get playerComparisonPointsPerGame;

  /// No description provided for @playerComparisonMargin.
  ///
  /// In zh, this message translates to:
  /// **'分差'**
  String get playerComparisonMargin;

  /// No description provided for @playerComparisonMarginPerGame.
  ///
  /// In zh, this message translates to:
  /// **'场均分差'**
  String get playerComparisonMarginPerGame;

  /// No description provided for @playerComparisonFieldGoalsMade.
  ///
  /// In zh, this message translates to:
  /// **'运动战命中'**
  String get playerComparisonFieldGoalsMade;

  /// No description provided for @playerComparisonFieldGoalAttempts.
  ///
  /// In zh, this message translates to:
  /// **'运动战出手'**
  String get playerComparisonFieldGoalAttempts;

  /// No description provided for @playerComparisonFieldGoalPercentage.
  ///
  /// In zh, this message translates to:
  /// **'运动战命中率'**
  String get playerComparisonFieldGoalPercentage;

  /// No description provided for @playerComparisonFreeThrowsMade.
  ///
  /// In zh, this message translates to:
  /// **'罚球命中'**
  String get playerComparisonFreeThrowsMade;

  /// No description provided for @playerComparisonFreeThrowAttempts.
  ///
  /// In zh, this message translates to:
  /// **'罚球出手'**
  String get playerComparisonFreeThrowAttempts;

  /// No description provided for @playerComparisonFreeThrowPercentage.
  ///
  /// In zh, this message translates to:
  /// **'罚球命中率'**
  String get playerComparisonFreeThrowPercentage;

  /// No description provided for @playerComparisonLocationCoverage.
  ///
  /// In zh, this message translates to:
  /// **'落点记录比例'**
  String get playerComparisonLocationCoverage;

  /// No description provided for @playerComparisonConfirmedZones.
  ///
  /// In zh, this message translates to:
  /// **'已确认落点的区域分布'**
  String get playerComparisonConfirmedZones;

  /// No description provided for @playerComparisonConfirmedZonesNote.
  ///
  /// In zh, this message translates to:
  /// **'各区域占比只按已确认的运动战落点计算。'**
  String get playerComparisonConfirmedZonesNote;

  /// No description provided for @playerComparisonIncrease.
  ///
  /// In zh, this message translates to:
  /// **'增加'**
  String get playerComparisonIncrease;

  /// No description provided for @playerComparisonDecrease.
  ///
  /// In zh, this message translates to:
  /// **'减少'**
  String get playerComparisonDecrease;

  /// No description provided for @playerComparisonEqual.
  ///
  /// In zh, this message translates to:
  /// **'持平'**
  String get playerComparisonEqual;

  /// No description provided for @playerComparisonInsufficientData.
  ///
  /// In zh, this message translates to:
  /// **'数据不足'**
  String get playerComparisonInsufficientData;

  /// No description provided for @playerComparisonWin.
  ///
  /// In zh, this message translates to:
  /// **'胜'**
  String get playerComparisonWin;

  /// No description provided for @playerComparisonLoss.
  ///
  /// In zh, this message translates to:
  /// **'负'**
  String get playerComparisonLoss;

  /// No description provided for @playerComparisonTie.
  ///
  /// In zh, this message translates to:
  /// **'平'**
  String get playerComparisonTie;

  /// No description provided for @playerComparisonPercentagePoints.
  ///
  /// In zh, this message translates to:
  /// **'个百分点'**
  String get playerComparisonPercentagePoints;

  /// No description provided for @replayMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get replayMoreActions;

  /// No description provided for @legacyBootstrapTitle.
  ///
  /// In zh, this message translates to:
  /// **'球豆数据兼容性检查'**
  String get legacyBootstrapTitle;

  /// No description provided for @legacyBootstrapHeadline.
  ///
  /// In zh, this message translates to:
  /// **'无法打开旧版 v0.1 数据'**
  String get legacyBootstrapHeadline;

  /// No description provided for @legacyBootstrapBody.
  ///
  /// In zh, this message translates to:
  /// **'旧版数据库{version}与当前版本不兼容。原文件会保持原样，球豆不会自动转换、删除或清空它。请先导出或备份旧文件，再用当前版本新建本地数据。'**
  String legacyBootstrapBody(Object version);

  /// No description provided for @bootstrapFailureBody.
  ///
  /// In zh, this message translates to:
  /// **'本地记录暂时打不开，现有数据没有改动。请稍后重试，或新建本地数据库。'**
  String get bootstrapFailureBody;

  /// No description provided for @entryPreparingRecords.
  ///
  /// In zh, this message translates to:
  /// **'正在打开本地记录…'**
  String get entryPreparingRecords;

  /// No description provided for @settingsDefaultSection.
  ///
  /// In zh, this message translates to:
  /// **'默认值'**
  String get settingsDefaultSection;

  /// No description provided for @settingsDefaultRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认计分规则'**
  String get settingsDefaultRuleTitle;

  /// No description provided for @settingsDefaultRuleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前沿用赛前设置'**
  String get settingsDefaultRuleSubtitle;

  /// No description provided for @settingsRulesSection.
  ///
  /// In zh, this message translates to:
  /// **'比赛规则'**
  String get settingsRulesSection;

  /// No description provided for @settingsRulesTemplateTitle.
  ///
  /// In zh, this message translates to:
  /// **'规则模板'**
  String get settingsRulesTemplateTitle;

  /// No description provided for @settingsRulesTemplateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'内置模板与自定义比赛规则'**
  String get settingsRulesTemplateSubtitle;

  /// No description provided for @settingsFeedbackSection.
  ///
  /// In zh, this message translates to:
  /// **'计分反馈'**
  String get settingsFeedbackSection;

  /// No description provided for @settingsHapticTitle.
  ///
  /// In zh, this message translates to:
  /// **'振动反馈'**
  String get settingsHapticTitle;

  /// No description provided for @settingsHapticEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get settingsHapticEnabled;

  /// No description provided for @settingsHapticDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get settingsHapticDisabled;

  /// No description provided for @settingsSoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'操作音效'**
  String get settingsSoundTitle;

  /// No description provided for @settingsSoundEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get settingsSoundEnabled;

  /// No description provided for @settingsSoundDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get settingsSoundDisabled;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用界面语言'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择浅色、深色或跟随系统'**
  String get settingsThemeSubtitle;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsMotionTitle.
  ///
  /// In zh, this message translates to:
  /// **'动效'**
  String get settingsMotionTitle;

  /// No description provided for @settingsMotionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用标准动效，或减少动画'**
  String get settingsMotionSubtitle;

  /// No description provided for @settingsMotionStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准动效'**
  String get settingsMotionStandard;

  /// No description provided for @settingsMotionReduced.
  ///
  /// In zh, this message translates to:
  /// **'减少动效'**
  String get settingsMotionReduced;

  /// No description provided for @settingsMotionHelp.
  ///
  /// In zh, this message translates to:
  /// **'减少动效会缩短过渡，关闭装饰性动画。'**
  String get settingsMotionHelp;

  /// No description provided for @settingsMotionPreview.
  ///
  /// In zh, this message translates to:
  /// **'动效预览'**
  String get settingsMotionPreview;

  /// No description provided for @settingsMotionPreviewStandard.
  ///
  /// In zh, this message translates to:
  /// **'预览：标准动效'**
  String get settingsMotionPreviewStandard;

  /// No description provided for @settingsMotionPreviewReduced.
  ///
  /// In zh, this message translates to:
  /// **'预览：减少动效'**
  String get settingsMotionPreviewReduced;

  /// No description provided for @settingsDataSection.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsDataSection;

  /// No description provided for @settingsDataManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据与备份'**
  String get settingsDataManagementTitle;

  /// No description provided for @settingsDataManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出数据、恢复备份、设置自动备份'**
  String get settingsDataManagementSubtitle;

  /// No description provided for @settingsManualDataSection.
  ///
  /// In zh, this message translates to:
  /// **'导出与恢复'**
  String get settingsManualDataSection;

  /// No description provided for @settingsAutomaticBackupSection.
  ///
  /// In zh, this message translates to:
  /// **'自动备份设置'**
  String get settingsAutomaticBackupSection;

  /// No description provided for @settingsExportDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get settingsExportDataTitle;

  /// No description provided for @settingsExportDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'JSON 备份可恢复数据，CSV 文件可用于分析'**
  String get settingsExportDataSubtitle;

  /// No description provided for @settingsExportDataDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择导出格式'**
  String get settingsExportDataDialogTitle;

  /// No description provided for @settingsStatisticsSection.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get settingsStatisticsSection;

  /// No description provided for @settingsStatisticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'基于本地比赛事件计算'**
  String get settingsStatisticsSubtitle;

  /// No description provided for @settingsBackupSection.
  ///
  /// In zh, this message translates to:
  /// **'备份与导出'**
  String get settingsBackupSection;

  /// No description provided for @settingsExportBackupTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出完整备份'**
  String get settingsExportBackupTitle;

  /// No description provided for @settingsExportBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'JSON 文件，包含比赛、球员、规则、事件和设置'**
  String get settingsExportBackupSubtitle;

  /// No description provided for @settingsExportBackupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已打开分享界面，可保存或发送备份文件'**
  String get settingsExportBackupSuccess;

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreSubtitleMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并备份，或先备份当前数据再完整替换'**
  String get settingsRestoreSubtitleMerge;

  /// No description provided for @settingsRestoreSubtitleBlocked.
  ///
  /// In zh, this message translates to:
  /// **'比赛进行中可以合并；替换数据需先结束比赛'**
  String get settingsRestoreSubtitleBlocked;

  /// No description provided for @settingsExportCsvTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV'**
  String get settingsExportCsvTitle;

  /// No description provided for @settingsExportCsvSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出 3 个文件：比赛列表、事件列表和球员统计'**
  String get settingsExportCsvSubtitle;

  /// No description provided for @settingsExportCsvSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已打开分享界面，可保存 3 个 CSV 文件'**
  String get settingsExportCsvSuccess;

  /// No description provided for @settingsAutomaticBackupTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get settingsAutomaticBackupTitle;

  /// No description provided for @settingsAutomaticBackupEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get settingsAutomaticBackupEnabled;

  /// No description provided for @settingsAutomaticBackupDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get settingsAutomaticBackupDisabled;

  /// No description provided for @settingsBackupDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份位置'**
  String get settingsBackupDirectoryTitle;

  /// No description provided for @settingsBackupDirectoryPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择自动备份文件夹'**
  String get settingsBackupDirectoryPickerTitle;

  /// No description provided for @settingsBackupDirectoryUnselected.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择，只会访问你选择的文件夹'**
  String get settingsBackupDirectoryUnselected;

  /// No description provided for @settingsBackupNowTitle.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get settingsBackupNowTitle;

  /// No description provided for @settingsBackupNever.
  ///
  /// In zh, this message translates to:
  /// **'还没有手动或自动备份记录'**
  String get settingsBackupNever;

  /// No description provided for @settingsBackupLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次备份成功：{date} {time}'**
  String settingsBackupLastSuccess(Object date, Object time);

  /// No description provided for @settingsBackupRetentionTitle.
  ///
  /// In zh, this message translates to:
  /// **'保留几份自动备份'**
  String get settingsBackupRetentionTitle;

  /// No description provided for @settingsBackupRetentionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只清理多余的球豆自动备份，手动备份和安全副本不受影响'**
  String get settingsBackupRetentionSubtitle;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get settingsPrivacySection;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地数据'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'个人数据保存在本机，球豆不会上传'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsExperimentalSection.
  ///
  /// In zh, this message translates to:
  /// **'实验功能'**
  String get settingsExperimentalSection;

  /// No description provided for @settingsExperimentalTitle.
  ///
  /// In zh, this message translates to:
  /// **'实验功能开关'**
  String get settingsExperimentalTitle;

  /// No description provided for @settingsExperimentalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可用实验功能'**
  String get settingsExperimentalSubtitle;

  /// No description provided for @settingsDiagnosticsSection.
  ///
  /// In zh, this message translates to:
  /// **'开发诊断'**
  String get settingsDiagnosticsSection;

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'诊断信息'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有诊断数据'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @settingsProjectSection.
  ///
  /// In zh, this message translates to:
  /// **'项目详情'**
  String get settingsProjectSection;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于球豆'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSection.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'永久免费开源，查看许可证与贡献方式'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsRestoreDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何恢复备份？'**
  String get settingsRestoreDialogTitle;

  /// No description provided for @settingsRestorePickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择球豆备份'**
  String get settingsRestorePickerTitle;

  /// No description provided for @settingsMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'合并导入（推荐）'**
  String get settingsMergeTitle;

  /// No description provided for @settingsMergeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'保留本机设置和正在进行的比赛。冲突记录会另存，不会覆盖本机记录；不会仅因昵称相同就合并球员。'**
  String get settingsMergeSubtitle;

  /// No description provided for @settingsReplaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'替换本机数据'**
  String get settingsReplaceTitle;

  /// No description provided for @settingsReplaceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先备份并验证当前数据，再用所选备份替换全部本机数据；失败则保留原数据'**
  String get settingsReplaceSubtitle;

  /// No description provided for @settingsReplaceBlocked.
  ///
  /// In zh, this message translates to:
  /// **'请先结束正在进行的比赛'**
  String get settingsReplaceBlocked;

  /// No description provided for @settingsReplaceConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'替换全部本机数据？'**
  String get settingsReplaceConfirmTitle;

  /// No description provided for @settingsReplaceConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'备份文件验证通过后，球豆会先保存并验证当前数据的备份（安全副本），再用所选备份替换全部本机数据。任一步失败都不会替换。请先结束正在进行的比赛。'**
  String get settingsReplaceConfirmBody;

  /// No description provided for @settingsReplaceConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'选择备份'**
  String get settingsReplaceConfirmAction;

  /// No description provided for @settingsRestoreNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择备份文件'**
  String get settingsRestoreNotSelected;

  /// No description provided for @settingsMergeCompleted.
  ///
  /// In zh, this message translates to:
  /// **'备份已合并，本机设置和正在进行的比赛保持不变'**
  String get settingsMergeCompleted;

  /// No description provided for @settingsReplaceCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已用备份替换本机数据，自动备份位置已重置'**
  String get settingsReplaceCompleted;

  /// No description provided for @settingsDirectoryUpdated.
  ///
  /// In zh, this message translates to:
  /// **'自动备份位置已更新'**
  String get settingsDirectoryUpdated;

  /// No description provided for @settingsDirectoryNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择文件夹'**
  String get settingsDirectoryNotSelected;

  /// No description provided for @settingsAutomaticBackupNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未选择文件夹，自动备份保持关闭'**
  String get settingsAutomaticBackupNotConfigured;

  /// No description provided for @settingsAutomaticBackupTurnedOn.
  ///
  /// In zh, this message translates to:
  /// **'自动备份已开启'**
  String get settingsAutomaticBackupTurnedOn;

  /// No description provided for @settingsAutomaticBackupTurnedOff.
  ///
  /// In zh, this message translates to:
  /// **'自动备份已关闭'**
  String get settingsAutomaticBackupTurnedOff;

  /// No description provided for @settingsHapticTurnedOn.
  ///
  /// In zh, this message translates to:
  /// **'振动反馈已开启'**
  String get settingsHapticTurnedOn;

  /// No description provided for @settingsHapticTurnedOff.
  ///
  /// In zh, this message translates to:
  /// **'振动反馈已关闭'**
  String get settingsHapticTurnedOff;

  /// No description provided for @settingsSoundTurnedOn.
  ///
  /// In zh, this message translates to:
  /// **'操作音效已开启'**
  String get settingsSoundTurnedOn;

  /// No description provided for @settingsSoundTurnedOff.
  ///
  /// In zh, this message translates to:
  /// **'操作音效已关闭'**
  String get settingsSoundTurnedOff;

  /// No description provided for @settingsBackupWritten.
  ///
  /// In zh, this message translates to:
  /// **'备份已保存到所选文件夹'**
  String get settingsBackupWritten;

  /// No description provided for @settingsRetentionUpdated.
  ///
  /// In zh, this message translates to:
  /// **'将保留最近 {count} 份自动备份'**
  String settingsRetentionUpdated(Object count);

  /// No description provided for @settingsErrorChecksum.
  ///
  /// In zh, this message translates to:
  /// **'备份校验失败，文件可能已损坏或被修改'**
  String get settingsErrorChecksum;

  /// No description provided for @settingsErrorFutureVersion.
  ///
  /// In zh, this message translates to:
  /// **'这份备份来自较新版本，请更新球豆后再试'**
  String get settingsErrorFutureVersion;

  /// No description provided for @settingsErrorInvalidBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份内容无效，现有数据未被修改'**
  String get settingsErrorInvalidBackup;

  /// No description provided for @settingsErrorMerge.
  ///
  /// In zh, this message translates to:
  /// **'备份合并失败，本机数据未被修改'**
  String get settingsErrorMerge;

  /// No description provided for @settingsErrorDirectoryRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先选择自动备份文件夹'**
  String get settingsErrorDirectoryRequired;

  /// No description provided for @settingsErrorDirectoryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法保存到所选文件夹，请重新选择'**
  String get settingsErrorDirectoryUnavailable;

  /// No description provided for @settingsErrorBackupWrite.
  ///
  /// In zh, this message translates to:
  /// **'备份未能保存，请重新选择备份文件夹后再试'**
  String get settingsErrorBackupWrite;

  /// No description provided for @settingsErrorRestoreBlocked.
  ///
  /// In zh, this message translates to:
  /// **'请先结束正在进行的比赛'**
  String get settingsErrorRestoreBlocked;

  /// No description provided for @settingsErrorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请稍后重试'**
  String get settingsErrorGeneric;

  /// No description provided for @playerAnalyticsNoLocationData.
  ///
  /// In zh, this message translates to:
  /// **'暂无落点数据'**
  String get playerAnalyticsNoLocationData;

  /// No description provided for @homePlayersTooltip.
  ///
  /// In zh, this message translates to:
  /// **'球员'**
  String get homePlayersTooltip;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeSettingsTooltip;

  /// No description provided for @homeProjectTooltip.
  ///
  /// In zh, this message translates to:
  /// **'项目详情'**
  String get homeProjectTooltip;

  /// No description provided for @homeActiveMatch.
  ///
  /// In zh, this message translates to:
  /// **'进行中的比赛'**
  String get homeActiveMatch;

  /// No description provided for @homeClockNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未开启计时'**
  String get homeClockNotConfigured;

  /// No description provided for @homeClockRegulationExpired.
  ///
  /// In zh, this message translates to:
  /// **'常规时间结束'**
  String get homeClockRegulationExpired;

  /// No description provided for @homeClockRunning.
  ///
  /// In zh, this message translates to:
  /// **'计时进行中'**
  String get homeClockRunning;

  /// No description provided for @homeClockPaused.
  ///
  /// In zh, this message translates to:
  /// **'计时已暂停'**
  String get homeClockPaused;

  /// No description provided for @homeLastPersistedUnknown.
  ///
  /// In zh, this message translates to:
  /// **'上次保存时间未知'**
  String get homeLastPersistedUnknown;

  /// No description provided for @homeLastPersisted.
  ///
  /// In zh, this message translates to:
  /// **'最近保存：{date}'**
  String homeLastPersisted(Object date);

  /// No description provided for @homeResumeMatch.
  ///
  /// In zh, this message translates to:
  /// **'继续比赛'**
  String get homeResumeMatch;

  /// No description provided for @homeAbandonMatch.
  ///
  /// In zh, this message translates to:
  /// **'放弃比赛'**
  String get homeAbandonMatch;

  /// No description provided for @homeAbandonTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃这场比赛？'**
  String get homeAbandonTitle;

  /// No description provided for @homeAbandonBody.
  ///
  /// In zh, this message translates to:
  /// **'比赛记录仍会保留，但不能再从主页继续这场比赛。'**
  String get homeAbandonBody;

  /// No description provided for @homeConfirmAbandon.
  ///
  /// In zh, this message translates to:
  /// **'确认放弃'**
  String get homeConfirmAbandon;

  /// No description provided for @homeActiveMatchBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已有进行中的比赛，请先继续或放弃它。'**
  String get homeActiveMatchBlocked;

  /// No description provided for @homeVersus.
  ///
  /// In zh, this message translates to:
  /// **'对阵'**
  String get homeVersus;

  /// No description provided for @playersTitle.
  ///
  /// In zh, this message translates to:
  /// **'球员'**
  String get playersTitle;

  /// No description provided for @playersCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建球员'**
  String get playersCreate;

  /// No description provided for @playersEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑球员'**
  String get playersEdit;

  /// No description provided for @playersEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有保存的球员'**
  String get playersEmptyTitle;

  /// No description provided for @playersEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'不保存档案也能直接比赛。保存后，下次选人更方便。'**
  String get playersEmptyBody;

  /// No description provided for @playersLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取球员'**
  String get playersLoadError;

  /// No description provided for @playersLoadErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'本地球员数据暂时无法打开。'**
  String get playersLoadErrorBody;

  /// No description provided for @retryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryAction;

  /// No description provided for @playersPreferredRed.
  ///
  /// In zh, this message translates to:
  /// **'偏好红方'**
  String get playersPreferredRed;

  /// No description provided for @playersPreferredBlue.
  ///
  /// In zh, this message translates to:
  /// **'偏好蓝方'**
  String get playersPreferredBlue;

  /// No description provided for @playersPreferredUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置偏好方'**
  String get playersPreferredUnset;

  /// No description provided for @playerSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试。'**
  String get playerSaveFailed;

  /// No description provided for @playerDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除球员？'**
  String get playerDeleteTitle;

  /// No description provided for @playerDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'只会删除此球员档案，不会删除已有比赛记录。'**
  String get playerDeleteBody;

  /// No description provided for @deleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAction;

  /// No description provided for @playerDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请重试。'**
  String get playerDeleteFailed;

  /// No description provided for @playerNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建球员'**
  String get playerNewTitle;

  /// No description provided for @playerEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑球员'**
  String get playerEditTitle;

  /// No description provided for @playerDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除球员'**
  String get playerDeleteTooltip;

  /// No description provided for @playerSaveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存球员'**
  String get playerSaveTooltip;

  /// No description provided for @playerOpenError.
  ///
  /// In zh, this message translates to:
  /// **'无法打开球员档案'**
  String get playerOpenError;

  /// No description provided for @playerOpenErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'无法打开该球员档案，请重试。'**
  String get playerOpenErrorBody;

  /// No description provided for @playerNicknameLabel.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get playerNicknameLabel;

  /// No description provided for @playerNicknameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入球员昵称'**
  String get playerNicknameRequired;

  /// No description provided for @playerPreferredSide.
  ///
  /// In zh, this message translates to:
  /// **'偏好方'**
  String get playerPreferredSide;

  /// No description provided for @playerSideAny.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get playerSideAny;

  /// No description provided for @playerSideRed.
  ///
  /// In zh, this message translates to:
  /// **'红方'**
  String get playerSideRed;

  /// No description provided for @playerSideBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝方'**
  String get playerSideBlue;

  /// No description provided for @playerNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get playerNoteLabel;

  /// No description provided for @playerNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'打法、习惯或需要记住的信息'**
  String get playerNoteHint;

  /// No description provided for @playerSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get playerSaving;

  /// No description provided for @rulesTitle.
  ///
  /// In zh, this message translates to:
  /// **'规则模板'**
  String get rulesTitle;

  /// No description provided for @rulesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无规则模板'**
  String get rulesEmptyTitle;

  /// No description provided for @rulesEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'创建一套常用规则，下场比赛直接选。'**
  String get rulesEmptyBody;

  /// No description provided for @rulesCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建规则'**
  String get rulesCreate;

  /// No description provided for @rulesLoadError.
  ///
  /// In zh, this message translates to:
  /// **'规则模板读取失败'**
  String get rulesLoadError;

  /// No description provided for @rulesLoadErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到规则模板，请重试。'**
  String get rulesLoadErrorBody;

  /// No description provided for @rulesBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get rulesBuiltIn;

  /// No description provided for @rulesCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get rulesCustom;

  /// No description provided for @ruleBuiltInFreeScoring.
  ///
  /// In zh, this message translates to:
  /// **'自由计分'**
  String get ruleBuiltInFreeScoring;

  /// No description provided for @ruleBuiltInElevenWinByTwo.
  ///
  /// In zh, this message translates to:
  /// **'11 分制（领先 2 分）'**
  String get ruleBuiltInElevenWinByTwo;

  /// No description provided for @ruleBuiltInTwentyOne.
  ///
  /// In zh, this message translates to:
  /// **'21 分制'**
  String get ruleBuiltInTwentyOne;

  /// No description provided for @ruleBuiltInTimedTen.
  ///
  /// In zh, this message translates to:
  /// **'10 分钟计时'**
  String get ruleBuiltInTimedTen;

  /// No description provided for @rulesScoringButtons.
  ///
  /// In zh, this message translates to:
  /// **'计分 {buttons}'**
  String rulesScoringButtons(Object buttons);

  /// No description provided for @rulesTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标 {points} 分'**
  String rulesTarget(Object points);

  /// No description provided for @rulesMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String rulesMinutes(Object minutes);

  /// No description provided for @rulesWinByTwo.
  ///
  /// In zh, this message translates to:
  /// **'领先 2 分'**
  String get rulesWinByTwo;

  /// No description provided for @ruleNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建规则'**
  String get ruleNewTitle;

  /// No description provided for @ruleEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑规则'**
  String get ruleEditTitle;

  /// No description provided for @ruleNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'模板名称'**
  String get ruleNameLabel;

  /// No description provided for @ruleNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入名称'**
  String get ruleNameRequired;

  /// No description provided for @ruleTargetLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标分（可选）'**
  String get ruleTargetLabel;

  /// No description provided for @ruleTimeLimitLabel.
  ///
  /// In zh, this message translates to:
  /// **'时限（分钟，可选）'**
  String get ruleTimeLimitLabel;

  /// No description provided for @ruleFoulLimitLabel.
  ///
  /// In zh, this message translates to:
  /// **'犯规上限（可选）'**
  String get ruleFoulLimitLabel;

  /// No description provided for @ruleScoreButtonsLabel.
  ///
  /// In zh, this message translates to:
  /// **'每次记几分（用逗号分隔）'**
  String get ruleScoreButtonsLabel;

  /// No description provided for @ruleCustomLabelsLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义事件名称（用逗号分隔）'**
  String get ruleCustomLabelsLabel;

  /// No description provided for @ruleWinByTwoTitle.
  ///
  /// In zh, this message translates to:
  /// **'领先 2 分获胜'**
  String get ruleWinByTwoTitle;

  /// No description provided for @rulePossessionHintTitle.
  ///
  /// In zh, this message translates to:
  /// **'得分后提示球权'**
  String get rulePossessionHintTitle;

  /// No description provided for @rulePossessionHintSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只作提示，仍可手动记分'**
  String get rulePossessionHintSubtitle;

  /// No description provided for @rulePossessionPolicyLabel.
  ///
  /// In zh, this message translates to:
  /// **'得分后球权归谁'**
  String get rulePossessionPolicyLabel;

  /// No description provided for @rulePossessionPolicyHelper.
  ///
  /// In zh, this message translates to:
  /// **'先打开球权提示，再选择提示方式。'**
  String get rulePossessionPolicyHelper;

  /// No description provided for @ruleSaveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存规则'**
  String get ruleSaveAction;

  /// No description provided for @rulePositiveInteger.
  ///
  /// In zh, this message translates to:
  /// **'{label} 必须为正整数'**
  String rulePositiveInteger(Object label);

  /// No description provided for @ruleAtLeastOneInteger.
  ///
  /// In zh, this message translates to:
  /// **'至少填写一个正整数'**
  String get ruleAtLeastOneInteger;

  /// No description provided for @rulePolicyManual.
  ///
  /// In zh, this message translates to:
  /// **'手动设置'**
  String get rulePolicyManual;

  /// No description provided for @rulePolicySwitchAfterMade.
  ///
  /// In zh, this message translates to:
  /// **'命中后交换球权'**
  String get rulePolicySwitchAfterMade;

  /// No description provided for @rulePolicyKeepAfterMade.
  ///
  /// In zh, this message translates to:
  /// **'命中后保留球权'**
  String get rulePolicyKeepAfterMade;

  /// No description provided for @pregameTitle.
  ///
  /// In zh, this message translates to:
  /// **'赛前设置'**
  String get pregameTitle;

  /// No description provided for @pregamePlayers.
  ///
  /// In zh, this message translates to:
  /// **'球员'**
  String get pregamePlayers;

  /// No description provided for @pregameRuleTemplate.
  ///
  /// In zh, this message translates to:
  /// **'规则模板'**
  String get pregameRuleTemplate;

  /// No description provided for @pregameFreeScoring.
  ///
  /// In zh, this message translates to:
  /// **'自由计分'**
  String get pregameFreeScoring;

  /// No description provided for @pregameElevenPoint.
  ///
  /// In zh, this message translates to:
  /// **'11 分制'**
  String get pregameElevenPoint;

  /// No description provided for @pregameTwentyOnePoint.
  ///
  /// In zh, this message translates to:
  /// **'21 分制'**
  String get pregameTwentyOnePoint;

  /// No description provided for @pregameTimer.
  ///
  /// In zh, this message translates to:
  /// **'计时'**
  String get pregameTimer;

  /// No description provided for @pregameWinByTwo.
  ///
  /// In zh, this message translates to:
  /// **'领先 2 分获胜'**
  String get pregameWinByTwo;

  /// No description provided for @pregameAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get pregameAdvanced;

  /// No description provided for @pregameTargetScore.
  ///
  /// In zh, this message translates to:
  /// **'目标分'**
  String get pregameTargetScore;

  /// No description provided for @pregameEditTargetScore.
  ///
  /// In zh, this message translates to:
  /// **'编辑目标分'**
  String get pregameEditTargetScore;

  /// No description provided for @pregameConfirmTargetScore.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get pregameConfirmTargetScore;

  /// No description provided for @pregameTargetScoreRange.
  ///
  /// In zh, this message translates to:
  /// **'请输入 {min}～{max} 的整数'**
  String pregameTargetScoreRange(int min, int max);

  /// No description provided for @pregamePoint.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get pregamePoint;

  /// No description provided for @pregameStartMatch.
  ///
  /// In zh, this message translates to:
  /// **'开始比赛'**
  String get pregameStartMatch;

  /// No description provided for @pregameRecordingMode.
  ///
  /// In zh, this message translates to:
  /// **'记录模式（必选）'**
  String get pregameRecordingMode;

  /// No description provided for @pregameTrackingCoverage.
  ///
  /// In zh, this message translates to:
  /// **'失误追踪范围'**
  String get pregameTrackingCoverage;

  /// No description provided for @pregameClockMode.
  ///
  /// In zh, this message translates to:
  /// **'计时方式'**
  String get pregameClockMode;

  /// No description provided for @pregameTemporaryParticipant.
  ///
  /// In zh, this message translates to:
  /// **'临时姓名（未关联档案）'**
  String get pregameTemporaryParticipant;

  /// No description provided for @pregameManageRules.
  ///
  /// In zh, this message translates to:
  /// **'管理规则模板'**
  String get pregameManageRules;

  /// No description provided for @pregameSimpleMode.
  ///
  /// In zh, this message translates to:
  /// **'简洁记录'**
  String get pregameSimpleMode;

  /// No description provided for @pregameDetailedMode.
  ///
  /// In zh, this message translates to:
  /// **'详细记录'**
  String get pregameDetailedMode;

  /// No description provided for @pregameTrackingHelper.
  ///
  /// In zh, this message translates to:
  /// **'选择需要记录到比赛回放中的出手与失误范围。'**
  String get pregameTrackingHelper;

  /// No description provided for @pregameTimerEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启：请选择计时方式'**
  String get pregameTimerEnabled;

  /// No description provided for @pregameTimerDisabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭后不记录比赛时间'**
  String get pregameTimerDisabled;

  /// No description provided for @pregameCountUp.
  ///
  /// In zh, this message translates to:
  /// **'正计时'**
  String get pregameCountUp;

  /// No description provided for @pregameCountDown.
  ///
  /// In zh, this message translates to:
  /// **'倒计时'**
  String get pregameCountDown;

  /// No description provided for @pregameCountdownLabel.
  ///
  /// In zh, this message translates to:
  /// **'倒计时（1–180 分钟）'**
  String get pregameCountdownLabel;

  /// No description provided for @pregameCountdownHelper.
  ///
  /// In zh, this message translates to:
  /// **'倒计时必须设置在 1 到 180 分钟之间。'**
  String get pregameCountdownHelper;

  /// No description provided for @pregameMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get pregameMinutes;

  /// No description provided for @pregameProfileConflict.
  ///
  /// In zh, this message translates to:
  /// **'另一方已经选了这名球员，请换一个档案。'**
  String get pregameProfileConflict;

  /// No description provided for @pregameCountdownInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1 到 180 的整数分钟。'**
  String get pregameCountdownInvalid;

  /// No description provided for @pregameTrackingNone.
  ///
  /// In zh, this message translates to:
  /// **'不追踪出手与失误'**
  String get pregameTrackingNone;

  /// No description provided for @pregameTrackingScoresOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅记录比分'**
  String get pregameTrackingScoresOnly;

  /// No description provided for @pregameTrackingShotAttempts.
  ///
  /// In zh, this message translates to:
  /// **'投篮出手'**
  String get pregameTrackingShotAttempts;

  /// No description provided for @pregameTrackingLocations.
  ///
  /// In zh, this message translates to:
  /// **'投篮出手与位置'**
  String get pregameTrackingLocations;

  /// No description provided for @pregameTrackingFull.
  ///
  /// In zh, this message translates to:
  /// **'完整记录（含失误）'**
  String get pregameTrackingFull;

  /// No description provided for @pregameDeletedPlayer.
  ///
  /// In zh, this message translates to:
  /// **'已删除的球员档案'**
  String get pregameDeletedPlayer;

  /// No description provided for @pregameParticipationMode.
  ///
  /// In zh, this message translates to:
  /// **'选择球员'**
  String get pregameParticipationMode;

  /// No description provided for @pregameTemporaryName.
  ///
  /// In zh, this message translates to:
  /// **'{side}临时姓名'**
  String pregameTemporaryName(Object side);

  /// No description provided for @pregameNameSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'{side}本场姓名'**
  String pregameNameSnapshot(Object side);

  /// No description provided for @pregameTemporaryHint.
  ///
  /// In zh, this message translates to:
  /// **'可输入临时姓名；双方临时同名也可以。'**
  String get pregameTemporaryHint;

  /// No description provided for @pregameSnapshotHint.
  ///
  /// In zh, this message translates to:
  /// **'只改这场比赛的姓名，球员档案保持原样。'**
  String get pregameSnapshotHint;

  /// No description provided for @pregameRed.
  ///
  /// In zh, this message translates to:
  /// **'红方'**
  String get pregameRed;

  /// No description provided for @pregameBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝方'**
  String get pregameBlue;

  /// No description provided for @pregameValidationRedRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入红方姓名。'**
  String get pregameValidationRedRequired;

  /// No description provided for @pregameValidationBlueRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入蓝方姓名。'**
  String get pregameValidationBlueRequired;

  /// No description provided for @pregameValidationDuplicateProfile.
  ///
  /// In zh, this message translates to:
  /// **'双方不能选同一个球员档案。'**
  String get pregameValidationDuplicateProfile;

  /// No description provided for @pregameValidationRedMissing.
  ///
  /// In zh, this message translates to:
  /// **'找不到红方选择的球员档案，请重选或输入临时姓名。'**
  String get pregameValidationRedMissing;

  /// No description provided for @pregameValidationBlueMissing.
  ///
  /// In zh, this message translates to:
  /// **'找不到蓝方选择的球员档案，请重选或输入临时姓名。'**
  String get pregameValidationBlueMissing;

  /// No description provided for @pregameValidationModeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择记录模式后再开始比赛。'**
  String get pregameValidationModeRequired;

  /// No description provided for @pregameValidationCountdownRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先开启计时，再选择倒计时。'**
  String get pregameValidationCountdownRequired;

  /// No description provided for @pregameValidationCountdownDuration.
  ///
  /// In zh, this message translates to:
  /// **'倒计时请设为 1 到 180 分钟。'**
  String get pregameValidationCountdownDuration;

  /// No description provided for @scoringSimpleRedShot.
  ///
  /// In zh, this message translates to:
  /// **'红方出手'**
  String get scoringSimpleRedShot;

  /// No description provided for @scoringSimpleBlueShot.
  ///
  /// In zh, this message translates to:
  /// **'蓝方出手'**
  String get scoringSimpleBlueShot;

  /// No description provided for @scoringMade.
  ///
  /// In zh, this message translates to:
  /// **'命中'**
  String get scoringMade;

  /// No description provided for @scoringMissed.
  ///
  /// In zh, this message translates to:
  /// **'未命中'**
  String get scoringMissed;

  /// No description provided for @scoringPoints.
  ///
  /// In zh, this message translates to:
  /// **'{points} 分'**
  String scoringPoints(Object points);

  /// No description provided for @scoringCancelDraft.
  ///
  /// In zh, this message translates to:
  /// **'取消草稿'**
  String get scoringCancelDraft;

  /// No description provided for @scoringSubmitShot.
  ///
  /// In zh, this message translates to:
  /// **'提交投篮'**
  String get scoringSubmitShot;

  /// No description provided for @scoringUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get scoringUndo;

  /// No description provided for @scoringLocateLastShot.
  ///
  /// In zh, this message translates to:
  /// **'定位最近投篮'**
  String get scoringLocateLastShot;

  /// No description provided for @scoringPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get scoringPause;

  /// No description provided for @scoringFinishShort.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get scoringFinishShort;

  /// No description provided for @scoringMatchControlsTitle.
  ///
  /// In zh, this message translates to:
  /// **'结束或暂停比赛？'**
  String get scoringMatchControlsTitle;

  /// No description provided for @scoringMatchControlsBody.
  ///
  /// In zh, this message translates to:
  /// **'暂时离开可以先暂停；打完了就确认比分并结束比赛。'**
  String get scoringMatchControlsBody;

  /// No description provided for @scoringReturnToScoring.
  ///
  /// In zh, this message translates to:
  /// **'返回计分'**
  String get scoringReturnToScoring;

  /// No description provided for @scoringPauseMatch.
  ///
  /// In zh, this message translates to:
  /// **'暂停比赛'**
  String get scoringPauseMatch;

  /// No description provided for @scoringMatchPausedTitle.
  ///
  /// In zh, this message translates to:
  /// **'比赛已暂停'**
  String get scoringMatchPausedTitle;

  /// No description provided for @scoringMatchPausedBody.
  ///
  /// In zh, this message translates to:
  /// **'比赛暂停中，继续后就能接着记分。'**
  String get scoringMatchPausedBody;

  /// No description provided for @scoringReturnHome.
  ///
  /// In zh, this message translates to:
  /// **'返回主页'**
  String get scoringReturnHome;

  /// No description provided for @scoringPendingPauseExitBody.
  ///
  /// In zh, this message translates to:
  /// **'球场上还有灰色投篮点未确认。返回主页或结束比赛会丢弃这次未完成的记录。'**
  String get scoringPendingPauseExitBody;

  /// No description provided for @scoringDiscardDraft.
  ///
  /// In zh, this message translates to:
  /// **'丢弃未完成记录'**
  String get scoringDiscardDraft;

  /// No description provided for @scoringResume.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get scoringResume;

  /// No description provided for @scoringBlueFreeThrowMade.
  ///
  /// In zh, this message translates to:
  /// **'蓝罚中'**
  String get scoringBlueFreeThrowMade;

  /// No description provided for @scoringBlueFreeThrowMissed.
  ///
  /// In zh, this message translates to:
  /// **'蓝罚失'**
  String get scoringBlueFreeThrowMissed;

  /// No description provided for @scoringRedFreeThrowMade.
  ///
  /// In zh, this message translates to:
  /// **'红罚中'**
  String get scoringRedFreeThrowMade;

  /// No description provided for @scoringRedFreeThrowMissed.
  ///
  /// In zh, this message translates to:
  /// **'红罚失'**
  String get scoringRedFreeThrowMissed;

  /// No description provided for @scoringPossessionBlue.
  ///
  /// In zh, this message translates to:
  /// **'球权蓝'**
  String get scoringPossessionBlue;

  /// No description provided for @scoringPossessionRed.
  ///
  /// In zh, this message translates to:
  /// **'球权红'**
  String get scoringPossessionRed;

  /// No description provided for @scoringNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get scoringNote;

  /// No description provided for @scoringCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get scoringCustom;

  /// No description provided for @scoringClockRunning.
  ///
  /// In zh, this message translates to:
  /// **'计时进行中'**
  String get scoringClockRunning;

  /// No description provided for @scoringClockStatus.
  ///
  /// In zh, this message translates to:
  /// **'计时状态：{status}'**
  String scoringClockStatus(Object status);

  /// No description provided for @scoringPendingLocationTitle.
  ///
  /// In zh, this message translates to:
  /// **'这次投篮还没记完'**
  String get scoringPendingLocationTitle;

  /// No description provided for @scoringPendingDraftTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前有未提交投篮'**
  String get scoringPendingDraftTitle;

  /// No description provided for @scoringPendingLocationBody.
  ///
  /// In zh, this message translates to:
  /// **'可以继续把这次投篮记完，也可以取消未完成的操作后离开。'**
  String get scoringPendingLocationBody;

  /// No description provided for @scoringPendingDraftBody.
  ///
  /// In zh, this message translates to:
  /// **'离开前请取消或提交当前投篮草稿。'**
  String get scoringPendingDraftBody;

  /// No description provided for @scoringStay.
  ///
  /// In zh, this message translates to:
  /// **'留在本场'**
  String get scoringStay;

  /// No description provided for @scoringCancelLocationLeave.
  ///
  /// In zh, this message translates to:
  /// **'取消并离开'**
  String get scoringCancelLocationLeave;

  /// No description provided for @scoringCancelDraftLeave.
  ///
  /// In zh, this message translates to:
  /// **'取消草稿并离开'**
  String get scoringCancelDraftLeave;

  /// No description provided for @scoringSubmitLeave.
  ///
  /// In zh, this message translates to:
  /// **'提交并离开'**
  String get scoringSubmitLeave;

  /// No description provided for @scoringDraftCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'当前无法创建投篮草稿'**
  String get scoringDraftCreateFailed;

  /// No description provided for @scoringMissTrackingDisabled.
  ///
  /// In zh, this message translates to:
  /// **'当前设置不记录未命中投篮'**
  String get scoringMissTrackingDisabled;

  /// No description provided for @scoringActionRejected.
  ///
  /// In zh, this message translates to:
  /// **'请先完成当前落点或未记完的投篮'**
  String get scoringActionRejected;

  /// No description provided for @scoringFreeThrowTrackingDisabled.
  ///
  /// In zh, this message translates to:
  /// **'当前跟踪设置不记录该罚球'**
  String get scoringFreeThrowTrackingDisabled;

  /// No description provided for @scoringPossessionNotCommitted.
  ///
  /// In zh, this message translates to:
  /// **'球权修改未提交'**
  String get scoringPossessionNotCommitted;

  /// No description provided for @scoringNoUnlocatedShot.
  ///
  /// In zh, this message translates to:
  /// **'暂无可定位的未标记投篮'**
  String get scoringNoUnlocatedShot;

  /// No description provided for @scoringLocationCancelFailed.
  ///
  /// In zh, this message translates to:
  /// **'当前落点无法取消'**
  String get scoringLocationCancelFailed;

  /// No description provided for @scoringUndoFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能撤销'**
  String get scoringUndoFailed;

  /// No description provided for @scoringPauseFailed.
  ///
  /// In zh, this message translates to:
  /// **'当前无法暂停计时'**
  String get scoringPauseFailed;

  /// No description provided for @scoringResumeFailed.
  ///
  /// In zh, this message translates to:
  /// **'当前无法恢复计时'**
  String get scoringResumeFailed;

  /// No description provided for @scoringDraftIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'投篮草稿尚未完成'**
  String get scoringDraftIncomplete;

  /// No description provided for @scoringNoDraft.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可取消的草稿'**
  String get scoringNoDraft;

  /// No description provided for @scoringAddNote.
  ///
  /// In zh, this message translates to:
  /// **'添加备注'**
  String get scoringAddNote;

  /// No description provided for @scoringNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：暂停、战术安排或场上情况'**
  String get scoringNoteHint;

  /// No description provided for @scoringRecordNote.
  ///
  /// In zh, this message translates to:
  /// **'保存备注'**
  String get scoringRecordNote;

  /// No description provided for @scoringRecordCustom.
  ///
  /// In zh, this message translates to:
  /// **'记录自定义事件'**
  String get scoringRecordCustom;

  /// No description provided for @scoringEventLabel.
  ///
  /// In zh, this message translates to:
  /// **'事件名称'**
  String get scoringEventLabel;

  /// No description provided for @scoringRecordEvent.
  ///
  /// In zh, this message translates to:
  /// **'记录事件'**
  String get scoringRecordEvent;

  /// No description provided for @scoringNoTimer.
  ///
  /// In zh, this message translates to:
  /// **'无计时'**
  String get scoringNoTimer;

  /// No description provided for @scoringTimerNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未开启计时'**
  String get scoringTimerNotConfigured;

  /// No description provided for @scoringOvertime.
  ///
  /// In zh, this message translates to:
  /// **'加时赛'**
  String get scoringOvertime;

  /// No description provided for @scoringRegulationExpired.
  ///
  /// In zh, this message translates to:
  /// **'常规时间结束'**
  String get scoringRegulationExpired;

  /// No description provided for @scoringClockPaused.
  ///
  /// In zh, this message translates to:
  /// **'计时已暂停'**
  String get scoringClockPaused;

  /// No description provided for @scoringBackToScoringList.
  ///
  /// In zh, this message translates to:
  /// **'返回计分'**
  String get scoringBackToScoringList;

  /// No description provided for @scoringMatchTime.
  ///
  /// In zh, this message translates to:
  /// **'比赛时间：{time}'**
  String scoringMatchTime(Object time);

  /// No description provided for @scoringResumeClock.
  ///
  /// In zh, this message translates to:
  /// **'恢复计时'**
  String get scoringResumeClock;

  /// No description provided for @scoringMarkShotTitle.
  ///
  /// In zh, this message translates to:
  /// **'标记投篮位置？'**
  String get scoringMarkShotTitle;

  /// No description provided for @scoringMarkShotBody.
  ///
  /// In zh, this message translates to:
  /// **'可在球场上点选或拖动圆点后确认。'**
  String get scoringMarkShotBody;

  /// No description provided for @scoringDoNotMark.
  ///
  /// In zh, this message translates to:
  /// **'不标记'**
  String get scoringDoNotMark;

  /// No description provided for @scoringMark.
  ///
  /// In zh, this message translates to:
  /// **'标记'**
  String get scoringMark;

  /// No description provided for @scoringResolvePending.
  ///
  /// In zh, this message translates to:
  /// **'请先确认或取消落点，也可以撤销这次投篮'**
  String get scoringResolvePending;

  /// No description provided for @scoringReplay.
  ///
  /// In zh, this message translates to:
  /// **'复盘'**
  String get scoringReplay;

  /// No description provided for @courtReplayLabel.
  ///
  /// In zh, this message translates to:
  /// **'复盘球场'**
  String get courtReplayLabel;

  /// No description provided for @courtEditLabel.
  ///
  /// In zh, this message translates to:
  /// **'篮球场投篮位置编辑区'**
  String get courtEditLabel;

  /// No description provided for @courtReplayHint.
  ///
  /// In zh, this message translates to:
  /// **'查看已记录的投篮'**
  String get courtReplayHint;

  /// No description provided for @courtEditHint.
  ///
  /// In zh, this message translates to:
  /// **'点击球场记录或调整投篮落点'**
  String get courtEditHint;

  /// No description provided for @routeLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载'**
  String get routeLoading;

  /// No description provided for @routeHomeLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取进行中的比赛'**
  String get routeHomeLoadError;

  /// No description provided for @routeActiveMatchCheckError.
  ///
  /// In zh, this message translates to:
  /// **'暂时查不到比赛状态'**
  String get routeActiveMatchCheckError;

  /// No description provided for @routeActiveMatchCheckBody.
  ///
  /// In zh, this message translates to:
  /// **'请返回主页重试，先确认是否有比赛正在进行。'**
  String get routeActiveMatchCheckBody;

  /// No description provided for @routeMatchLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取比赛'**
  String get routeMatchLoadError;

  /// No description provided for @routeMatchNotActive.
  ///
  /// In zh, this message translates to:
  /// **'这场比赛不在进行中'**
  String get routeMatchNotActive;

  /// No description provided for @routeMatchNotActiveBody.
  ///
  /// In zh, this message translates to:
  /// **'请从主页继续进行中的比赛。'**
  String get routeMatchNotActiveBody;

  /// No description provided for @routeMatchRestoring.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复比赛'**
  String get routeMatchRestoring;

  /// No description provided for @routeMatchRestoringBody.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复计分记录，请稍候。'**
  String get routeMatchRestoringBody;

  /// No description provided for @routeReplayOpenError.
  ///
  /// In zh, this message translates to:
  /// **'无法打开复盘'**
  String get routeReplayOpenError;

  /// No description provided for @routeReplayOpenErrorBody.
  ///
  /// In zh, this message translates to:
  /// **'比赛数据读取失败，请返回后重试。'**
  String get routeReplayOpenErrorBody;

  /// No description provided for @routeReplayNotFound.
  ///
  /// In zh, this message translates to:
  /// **'没有找到这场比赛'**
  String get routeReplayNotFound;

  /// No description provided for @routeReplayNotFoundBody.
  ///
  /// In zh, this message translates to:
  /// **'记录可能已被移除。'**
  String get routeReplayNotFoundBody;

  /// No description provided for @routeActiveMatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'已有进行中的比赛'**
  String get routeActiveMatchTitle;

  /// No description provided for @routeContinueMatch.
  ///
  /// In zh, this message translates to:
  /// **'继续比赛'**
  String get routeContinueMatch;

  /// No description provided for @routeAbandonMatch.
  ///
  /// In zh, this message translates to:
  /// **'放弃比赛'**
  String get routeAbandonMatch;

  /// No description provided for @routeActiveCheckLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在查找进行中的比赛，请稍后再试。'**
  String get routeActiveCheckLoading;

  /// No description provided for @routeStartMatchConflict.
  ///
  /// In zh, this message translates to:
  /// **'已有进行中的比赛，请先继续或放弃它。'**
  String get routeStartMatchConflict;

  /// No description provided for @routeAbandonFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法放弃比赛，请重试。'**
  String get routeAbandonFailed;

  /// No description provided for @routeResumeFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法恢复比赛，请重试。'**
  String get routeResumeFailed;

  /// No description provided for @routeLeaveTitle.
  ///
  /// In zh, this message translates to:
  /// **'离开比赛'**
  String get routeLeaveTitle;

  /// No description provided for @routeLeaveBody.
  ///
  /// In zh, this message translates to:
  /// **'可以继续计时，或先暂停再离开。'**
  String get routeLeaveBody;

  /// No description provided for @routeLeaveStay.
  ///
  /// In zh, this message translates to:
  /// **'留在比赛'**
  String get routeLeaveStay;

  /// No description provided for @routeLeaveKeepRunning.
  ///
  /// In zh, this message translates to:
  /// **'继续计时'**
  String get routeLeaveKeepRunning;

  /// No description provided for @routeLeavePauseAndLeave.
  ///
  /// In zh, this message translates to:
  /// **'暂停并离开'**
  String get routeLeavePauseAndLeave;

  /// No description provided for @routeClockCheckError.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法确认计时状态，请留在本场重试。'**
  String get routeClockCheckError;

  /// No description provided for @routeProjectLinkError.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接，请稍后重试。'**
  String get routeProjectLinkError;

  /// No description provided for @projectTitle.
  ///
  /// In zh, this message translates to:
  /// **'项目详情'**
  String get projectTitle;

  /// No description provided for @projectTagline.
  ///
  /// In zh, this message translates to:
  /// **'一对一篮球的本地计分与复盘工具。'**
  String get projectTagline;

  /// No description provided for @projectFreeForever.
  ///
  /// In zh, this message translates to:
  /// **'永久免费'**
  String get projectFreeForever;

  /// No description provided for @projectFreeForeverDetail.
  ///
  /// In zh, this message translates to:
  /// **'核心计分和复盘功能永久免费。'**
  String get projectFreeForeverDetail;

  /// No description provided for @projectOpenSource.
  ///
  /// In zh, this message translates to:
  /// **'永久开源'**
  String get projectOpenSource;

  /// No description provided for @projectOpenSourceDetail.
  ///
  /// In zh, this message translates to:
  /// **'源代码始终公开，欢迎查看和参与。'**
  String get projectOpenSourceDetail;

  /// No description provided for @projectOffline.
  ///
  /// In zh, this message translates to:
  /// **'本地离线'**
  String get projectOffline;

  /// No description provided for @projectOfflineDetail.
  ///
  /// In zh, this message translates to:
  /// **'不用注册，没网络也能记比赛。'**
  String get projectOfflineDetail;

  /// No description provided for @projectPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'不会上传个人数据'**
  String get projectPrivacy;

  /// No description provided for @projectPrivacyDetail.
  ///
  /// In zh, this message translates to:
  /// **'球员和比赛数据保存在本机，球豆不会上传。'**
  String get projectPrivacyDetail;

  /// No description provided for @projectOpen.
  ///
  /// In zh, this message translates to:
  /// **'查看与参与'**
  String get projectOpen;

  /// No description provided for @projectContribute.
  ///
  /// In zh, this message translates to:
  /// **'贡献指南'**
  String get projectContribute;

  /// No description provided for @projectIssue.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get projectIssue;

  /// No description provided for @projectOpenBrowser.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开'**
  String get projectOpenBrowser;

  /// No description provided for @exportBackupDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择球豆备份'**
  String get exportBackupDialogTitle;

  /// No description provided for @exportAutomaticBackupDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择自动备份文件夹'**
  String get exportAutomaticBackupDialogTitle;

  /// No description provided for @exportFullBackupSubject.
  ///
  /// In zh, this message translates to:
  /// **'球豆完整本地备份'**
  String get exportFullBackupSubject;

  /// No description provided for @exportSafetyBackupSubject.
  ///
  /// In zh, this message translates to:
  /// **'球豆恢复前安全备份'**
  String get exportSafetyBackupSubject;

  /// No description provided for @exportCsvSubject.
  ///
  /// In zh, this message translates to:
  /// **'球豆 CSV 数据导出'**
  String get exportCsvSubject;

  /// No description provided for @exportReplaySubject.
  ///
  /// In zh, this message translates to:
  /// **'球豆比赛复盘'**
  String get exportReplaySubject;

  /// No description provided for @projectGitHub.
  ///
  /// In zh, this message translates to:
  /// **'GitHub'**
  String get projectGitHub;

  /// No description provided for @projectLicense.
  ///
  /// In zh, this message translates to:
  /// **'许可证'**
  String get projectLicense;

  /// No description provided for @historyImportedIncompleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份导入的未完成比赛'**
  String get historyImportedIncompleteTitle;

  /// No description provided for @historyImportedIncompleteBody.
  ///
  /// In zh, this message translates to:
  /// **'这场比赛从备份导入，还没结束，可以继续记分。'**
  String get historyImportedIncompleteBody;

  /// No description provided for @historyResumeImportedIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'继续这场比赛'**
  String get historyResumeImportedIncomplete;

  /// No description provided for @historyResumeImportedIncompleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能继续这场比赛，请先确认没有其他比赛正在进行。'**
  String get historyResumeImportedIncompleteFailed;

  /// No description provided for @historyImportedIncompleteLoadError.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到从备份导入的未完成比赛。'**
  String get historyImportedIncompleteLoadError;

  /// No description provided for @historyImportedIncompleteRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get historyImportedIncompleteRetry;

  /// No description provided for @pregameTemplatesFallbackLoading.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到规则模板，先用内置规则。球员档案还在加载中。'**
  String get pregameTemplatesFallbackLoading;

  /// No description provided for @pregamePlayersLoading.
  ///
  /// In zh, this message translates to:
  /// **'球员档案还在加载中，也可以先输入临时姓名。'**
  String get pregamePlayersLoading;

  /// No description provided for @pregameTemplatesPlayersError.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到规则模板和球员档案，可以先用临时姓名开赛。'**
  String get pregameTemplatesPlayersError;

  /// No description provided for @pregamePlayersError.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到球员档案，可以先用临时姓名开赛。'**
  String get pregamePlayersError;

  /// No description provided for @pregameTemplatesFallbackNotice.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到规则模板，先用内置规则。'**
  String get pregameTemplatesFallbackNotice;

  /// No description provided for @scoringConfirmLocation.
  ///
  /// In zh, this message translates to:
  /// **'确认落点'**
  String get scoringConfirmLocation;

  /// No description provided for @scoringSkipLocation.
  ///
  /// In zh, this message translates to:
  /// **'取消定位'**
  String get scoringSkipLocation;

  /// No description provided for @scoringFoul.
  ///
  /// In zh, this message translates to:
  /// **'犯规'**
  String get scoringFoul;

  /// No description provided for @scoringFoulForSide.
  ///
  /// In zh, this message translates to:
  /// **'{side}犯规'**
  String scoringFoulForSide(Object side);

  /// No description provided for @scoringMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get scoringMore;

  /// No description provided for @scoringShotsGroup.
  ///
  /// In zh, this message translates to:
  /// **'投篮'**
  String get scoringShotsGroup;

  /// No description provided for @scoringShotDisplayGroup.
  ///
  /// In zh, this message translates to:
  /// **'投篮显示'**
  String get scoringShotDisplayGroup;

  /// No description provided for @scoringShowMissMarkers.
  ///
  /// In zh, this message translates to:
  /// **'显示{side}未命中点'**
  String scoringShowMissMarkers(Object side);

  /// No description provided for @scoringDisplayShown.
  ///
  /// In zh, this message translates to:
  /// **'已显示'**
  String get scoringDisplayShown;

  /// No description provided for @scoringDisplayHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏'**
  String get scoringDisplayHidden;

  /// No description provided for @scoringFreeThrowsGroup.
  ///
  /// In zh, this message translates to:
  /// **'罚球'**
  String get scoringFreeThrowsGroup;

  /// No description provided for @scoringMatchStatusGroup.
  ///
  /// In zh, this message translates to:
  /// **'比赛状态'**
  String get scoringMatchStatusGroup;

  /// No description provided for @scoringRecordsGroup.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get scoringRecordsGroup;

  /// No description provided for @scoringNotesCustomRecordsGroup.
  ///
  /// In zh, this message translates to:
  /// **'备注与自定义记录'**
  String get scoringNotesCustomRecordsGroup;

  /// No description provided for @scoringMatchGroup.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get scoringMatchGroup;

  /// No description provided for @scoringChooseScoringSide.
  ///
  /// In zh, this message translates to:
  /// **'请选择蓝方或红方得分'**
  String get scoringChooseScoringSide;

  /// No description provided for @scoringSupplementPrompt.
  ///
  /// In zh, this message translates to:
  /// **'补充{side} +{points} 落点 · 剩余 {seconds}秒'**
  String scoringSupplementPrompt(Object points, Object seconds, Object side);

  /// No description provided for @scoringMissSupplementPrompt.
  ///
  /// In zh, this message translates to:
  /// **'补充{side}未命中落点 · 剩余 {seconds}秒'**
  String scoringMissSupplementPrompt(Object seconds, Object side);

  /// No description provided for @scoringSupplementExpired.
  ///
  /// In zh, this message translates to:
  /// **'补落点的时间已过'**
  String get scoringSupplementExpired;

  /// No description provided for @scoringScoreSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{side} +{points} 分'**
  String scoringScoreSemantics(Object points, Object side);

  /// No description provided for @scoringLocationPendingSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{side} +{points}，还有 {seconds} 秒可补落点'**
  String scoringLocationPendingSemantics(
    Object points,
    Object seconds,
    Object side,
  );

  /// No description provided for @scoringMissSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{side}未命中'**
  String scoringMissSemantics(Object side);

  /// No description provided for @scoringMissLocationPendingSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{side}未命中，还有 {seconds} 秒可补落点'**
  String scoringMissLocationPendingSemantics(Object seconds, Object side);

  /// No description provided for @updateTitle.
  ///
  /// In zh, this message translates to:
  /// **'软件更新'**
  String get updateTitle;

  /// No description provided for @updateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检查、下载并安装新版本'**
  String get updateSubtitle;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本：{version}'**
  String updateCurrentVersion(Object version);

  /// No description provided for @updateAutoCheck.
  ///
  /// In zh, this message translates to:
  /// **'启动时检查更新'**
  String get updateAutoCheck;

  /// No description provided for @updateAutoCheckDetail.
  ///
  /// In zh, this message translates to:
  /// **'启动后会联网检查新版本，不上传比赛或球员记录。关闭后仍可手动检查。'**
  String get updateAutoCheckDetail;

  /// No description provided for @updateCheck.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateUpToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}'**
  String updateAvailable(Object version);

  /// No description provided for @updateDownloadSize.
  ///
  /// In zh, this message translates to:
  /// **'下载大小：{size}'**
  String updateDownloadSize(Object size);

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get updateLater;

  /// No description provided for @updateDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get updateDownload;

  /// No description provided for @updateDownloadQueued.
  ///
  /// In zh, this message translates to:
  /// **'等待系统开始下载'**
  String get updateDownloadQueued;

  /// No description provided for @updateDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载 {received} / {total}'**
  String updateDownloading(Object received, Object total);

  /// No description provided for @updateDownloadPaused.
  ///
  /// In zh, this message translates to:
  /// **'下载已暂停，系统会在条件允许时继续'**
  String get updateDownloadPaused;

  /// No description provided for @updateVerifying.
  ///
  /// In zh, this message translates to:
  /// **'正在校验安装包…'**
  String get updateVerifying;

  /// No description provided for @updateReady.
  ///
  /// In zh, this message translates to:
  /// **'安装包已就绪'**
  String get updateReady;

  /// No description provided for @updateInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装更新'**
  String get updateInstall;

  /// No description provided for @updateCancelDownload.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get updateCancelDownload;

  /// No description provided for @updateRetryDownload.
  ///
  /// In zh, this message translates to:
  /// **'重新下载'**
  String get updateRetryDownload;

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法检查更新，请确认网络后重试。'**
  String get updateCheckFailed;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载未完成，请检查网络和存储空间后重试。'**
  String get updateDownloadFailed;

  /// No description provided for @updateVerificationFailed.
  ///
  /// In zh, this message translates to:
  /// **'安装包校验失败，请重新下载。'**
  String get updateVerificationFailed;

  /// No description provided for @updateFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'安装包已被移除，请重新下载。'**
  String get updateFileMissing;

  /// No description provided for @updateInstallBlocked.
  ///
  /// In zh, this message translates to:
  /// **'请先完成或结束当前比赛，再安装更新。尚未确认比赛状态时，也无法安装。'**
  String get updateInstallBlocked;

  /// No description provided for @updatePermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'允许安装更新'**
  String get updatePermissionTitle;

  /// No description provided for @updatePermissionBody.
  ///
  /// In zh, this message translates to:
  /// **'请在系统设置中允许球豆安装应用，再返回这里。最后还需要你在系统安装界面确认。'**
  String get updatePermissionBody;

  /// No description provided for @updateOpenSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开系统设置'**
  String get updateOpenSettings;

  /// No description provided for @updateInstallFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开安装界面，请检查系统安装权限后重试。'**
  String get updateInstallFailed;

  /// No description provided for @updateInstallerOpened.
  ///
  /// In zh, this message translates to:
  /// **'已打开系统安装界面，请在那里确认安装。取消后可以再次点击安装。'**
  String get updateInstallerOpened;

  /// No description provided for @updateIncompatible.
  ///
  /// In zh, this message translates to:
  /// **'新版本需要更新的 Android 系统，当前设备无法安装。'**
  String get updateIncompatible;

  /// No description provided for @updateUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂不支持应用内更新。'**
  String get updateUnsupported;

  /// No description provided for @updateSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置未保存，请重试。'**
  String get updateSettingsFailed;

  /// No description provided for @updateFallback.
  ///
  /// In zh, this message translates to:
  /// **'正在使用 GitHub 备用下载渠道'**
  String get updateFallback;

  /// No description provided for @pregameGoalScoringMode.
  ///
  /// In zh, this message translates to:
  /// **'计分方式'**
  String get pregameGoalScoringMode;

  /// No description provided for @pregameGoalModeFree.
  ///
  /// In zh, this message translates to:
  /// **'自由计分'**
  String get pregameGoalModeFree;

  /// No description provided for @pregameGoalModeTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标计分'**
  String get pregameGoalModeTarget;

  /// No description provided for @ruleBuiltInDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认规则'**
  String get ruleBuiltInDefault;

  /// No description provided for @scoringTargetReachedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已达到目标分'**
  String get scoringTargetReachedTitle;

  /// No description provided for @scoringTargetPoints.
  ///
  /// In zh, this message translates to:
  /// **'目标 {target} 分'**
  String scoringTargetPoints(int target);

  /// No description provided for @scoringTargetReachedPlayer.
  ///
  /// In zh, this message translates to:
  /// **'{name}已达到目标分'**
  String scoringTargetReachedPlayer(String name);

  /// No description provided for @scoringTargetReachedTie.
  ///
  /// In zh, this message translates to:
  /// **'双方已达到目标分，当前平分'**
  String get scoringTargetReachedTie;

  /// No description provided for @scoringTargetSupplement.
  ///
  /// In zh, this message translates to:
  /// **'可先补上最后一球的落点'**
  String get scoringTargetSupplement;

  /// No description provided for @scoringTargetSkipLocation.
  ///
  /// In zh, this message translates to:
  /// **'跳过落点'**
  String get scoringTargetSkipLocation;

  /// No description provided for @scoringTargetUndoScore.
  ///
  /// In zh, this message translates to:
  /// **'撤销上一笔得分'**
  String get scoringTargetUndoScore;

  /// No description provided for @scoringTargetContinueHelp.
  ///
  /// In zh, this message translates to:
  /// **'继续后，本场不再提醒目标分'**
  String get scoringTargetContinueHelp;

  /// No description provided for @summaryGameFinished.
  ///
  /// In zh, this message translates to:
  /// **'比赛结束'**
  String get summaryGameFinished;

  /// No description provided for @summaryWinner.
  ///
  /// In zh, this message translates to:
  /// **'{name}获胜'**
  String summaryWinner(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
