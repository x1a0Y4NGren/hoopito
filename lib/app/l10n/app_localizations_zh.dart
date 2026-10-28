// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get v2Saving => '正在保存';

  @override
  String get v2Saved => '已保存到本机';

  @override
  String get v2SaveFailed => '保存失败，请重试';

  @override
  String get v2LastAction => '上次操作';

  @override
  String v2GrowthChartRange(int count, int total) {
    return '显示最近 $count 场，共 $total 场';
  }

  @override
  String get v2SafetyWriteError => '未能保存并验证替换前的安全副本，本机数据未替换。请检查存储空间后重试。';

  @override
  String get v2SafetyLoadError => '无法读取安全副本，请重试。';

  @override
  String get v2BackupRows => '行';

  @override
  String v2BackupCapacityError(String measured, String limit) {
    return '备份超过支持容量（当前 $measured，上限 $limit）。原数据已保留。';
  }

  @override
  String get v2SwapSides => '交换双方';

  @override
  String get v2PresetApplied => '已沿用双方和规则，还可以调整';

  @override
  String get v2RulesSummary => '规则概览';

  @override
  String get v2StartFailed => '比赛未能开始，请重试。';

  @override
  String get v2PointsDifference => '最近两场得分差值';

  @override
  String get v2MarginDifference => '最近两场分差变化';

  @override
  String get v2Matches => '比赛';

  @override
  String get v2RecentMatches => '最近三场';

  @override
  String get v2RecentPreset => '沿用上场设置';

  @override
  String get v2Result => '赛果';

  @override
  String get v2Rematch => '再来一场';

  @override
  String get v2Share => '分享战报';

  @override
  String get v2Replay => '完整复盘';

  @override
  String get v2CoverageTitle => '记录范围';

  @override
  String get v2CoverageScores => '主要记分';

  @override
  String get v2CoverageComplete => '记录全部投篮与罚球';

  @override
  String get v2CoverageHelp => '主要记分不显示命中率。完整记录需记下每次投篮和罚球，包括未命中。';

  @override
  String get v2CorrectCoverage => '纠正记录范围';

  @override
  String get v2CoverageReason => '记录范围纠正';

  @override
  String get v2FieldGoalPercentage => '运动战命中率';

  @override
  String get v2FreeThrowPercentage => '罚球命中率';

  @override
  String get v2RecordedSample => '以下图表仅表示已记录的样本';

  @override
  String get v2LocationScope => '已确认运动战落点 / 已记录运动战出手';

  @override
  String get v2SavePlayer => '保存到球员档案';

  @override
  String get v2CreatePlayer => '新建球员档案';

  @override
  String get v2SelectPlayer => '选择已有球员';

  @override
  String get v2PlayerSaved => '已关联球员档案，本场姓名不变';

  @override
  String get v2Retry => '重试';

  @override
  String get v2GuideTitle => '快速上手';

  @override
  String get v2GuideScore => '直接记分';

  @override
  String get v2GuideScoreBody => '点双方的 +1、+2、+3 即可记分。';

  @override
  String get v2GuideLocation => '记落点和未命中';

  @override
  String get v2GuideLocationBody => '可以先点球场再记分，也可以记分后在 10 秒内补落点。未命中也能记。';

  @override
  String get v2GuideUndo => '撤销和结束比赛';

  @override
  String get v2GuideUndoBody => '点撤销可退回上一步。打完后，点顶部结束比赛，再确认这场投篮是否记全。';

  @override
  String get v2GuideSkip => '跳过';

  @override
  String get v2GuideNext => '下一步';

  @override
  String get v2GuideDone => '知道了';

  @override
  String get v2AbandonedMatch => '比赛未完赛';

  @override
  String get v2AbandonedMatchHelp => '已保存的记录仍可复盘；本场不计入已完成比赛统计。';

  @override
  String get v2SafetyTitle => '恢复安全副本';

  @override
  String get v2SafetyHelp =>
      '安全副本是替换前自动保存的本机数据备份，保留最近两份，可在这里恢复。恢复前也会先保存并验证当前数据的副本。';

  @override
  String get v2SafetyEmpty => '尚无安全副本';

  @override
  String get v2SafetyRestore => '恢复这份副本';

  @override
  String get v2SafetyConfirm =>
      '这份副本将替换全部本机数据。球豆会先保存并验证当前数据的安全副本，失败就不会替换。请先结束正在进行的比赛。';

  @override
  String get v2GrowthSample => '按比赛顺序显示运动战命中率；空缺表示记录不完整或无出手。';

  @override
  String get appName => '球豆';

  @override
  String get startScoring => '开始计分';

  @override
  String get replayHistory => '历史';

  @override
  String get settings => '设置';

  @override
  String get projectDetails => '项目详情';

  @override
  String get ruleTargetReached => '已达到目标分，要结束还是继续？';

  @override
  String get ruleWinByTwoRequired => '已达到目标分，还要领先 2 分才能赢，请继续比赛。';

  @override
  String get ruleMatchPoint => '赛点';

  @override
  String get rulePossessionSuggested => '球权建议';

  @override
  String ruleFoulLimit(Object limit, Object side) {
    return '$side犯规已达 $limit 次上限';
  }

  @override
  String get finishOrContinueOvertime => '常规时间结束，请确认结束或进入加时';

  @override
  String get matchDecisionTitle => '比赛决策';

  @override
  String get continueMatch => '继续比赛';

  @override
  String get finishMatch => '结束比赛';

  @override
  String get confirmFinalScoreTitle => '确认最终比分';

  @override
  String get confirmFinalScoreBody => '结束后将锁定当前比分并关闭进行中的比赛。';

  @override
  String finalScoreLine(
    Object blueName,
    Object blueScore,
    Object redName,
    Object redScore,
  ) {
    return '$redName $redScore : $blueScore $blueName';
  }

  @override
  String get cancelAction => '取消';

  @override
  String get actionFailedRetry => '操作失败，请重试。';

  @override
  String get historyTitle => '最近比赛';

  @override
  String get historyHomeTooltip => '返回主页';

  @override
  String get replayExitToScoringTooltip => '返回计分';

  @override
  String get replayExitToHistoryTooltip => '返回历史';

  @override
  String get historySearchHint => '搜索球员或比赛';

  @override
  String get historyCompleted => '已完成';

  @override
  String get historyArchived => '已归档';

  @override
  String get historyAll => '全部';

  @override
  String get historyResetFilters => '重置筛选';

  @override
  String get historyEmpty => '暂无比赛记录';

  @override
  String get historyEmptyDescription => '完成一场比赛后，记录会显示在这里。';

  @override
  String get historyActiveMatch => '进行中的比赛';

  @override
  String get historyResume => '继续';

  @override
  String get historyActions => '比赛操作';

  @override
  String get historyArchive => '归档';

  @override
  String get historyUnarchive => '取消归档';

  @override
  String get historyDeletePermanently => '永久删除';

  @override
  String get historyDeleteTitle => '永久删除比赛？';

  @override
  String get historyDeleteBody => '这场比赛及其事件、投篮落点和操作记录都会永久删除，无法恢复。';

  @override
  String get historyLoadMore => '加载更多';

  @override
  String get historyMoreFilters => '更多筛选';

  @override
  String get historyAdvancedTitle => '高级筛选';

  @override
  String get historyRuleLabel => '规则名称';

  @override
  String get historyRecordingModeLabel => '记录模式';

  @override
  String get historyAllModes => '全部模式';

  @override
  String get historySimpleMode => '简洁记录';

  @override
  String get historyDetailedMode => '详细记录';

  @override
  String get historyStartDate => '开始日期';

  @override
  String get historyEndDate => '结束日期';

  @override
  String get historyClearDates => '清除日期';

  @override
  String get historyApplyFilters => '应用筛选';

  @override
  String get historyLoadError => '无法加载比赛记录。';

  @override
  String get historyRetry => '重试';

  @override
  String get historyRule => '规则';

  @override
  String get historyDuration => '时长';

  @override
  String get historyResult => '结果';

  @override
  String get historyDraw => '平局';

  @override
  String historyWinner(Object winnerName) {
    return '胜者：$winnerName';
  }

  @override
  String get historyLocationCompleteness => '落点记录比例';

  @override
  String get replayTitle => '比赛复盘';

  @override
  String get replayExportTooltip => '导出复盘图';

  @override
  String get replayAuditTooltip => '操作记录';

  @override
  String get replayEditMode => '编辑模式';

  @override
  String get replayReadOnly => '仅查看';

  @override
  String get replayFinished => '终场';

  @override
  String get replayInProgress => '进行中';

  @override
  String get replayExportTitle => '复盘分享图';

  @override
  String get replayExportDescription => '将落点图和比赛分析合成一张本地图片';

  @override
  String get replayClose => '关闭';

  @override
  String get replayGenerating => '生成中';

  @override
  String get replayGenerateShare => '生成并分享';

  @override
  String get replayExportFailed => '图片生成或分享失败，请重试';

  @override
  String get replayExportAnalysis => '本场分析';

  @override
  String get replayExportShotLocations => '落点记录';

  @override
  String get replayExportShootingPercentage => '投篮命中率';

  @override
  String get replayExportLeadChanges => '领先变化';

  @override
  String get replayExportLargestLead => '最大领先';

  @override
  String get replayExportKeyMoments => '关键节点';

  @override
  String get replayNoData => '暂无';

  @override
  String replayExportLeadChangesValue(Object count) {
    return '$count 次';
  }

  @override
  String replayExportKeyMomentsValue(Object count) {
    return '$count 次';
  }

  @override
  String get replayCourt => '落点图';

  @override
  String get replaySaveLocation => '保存落点';

  @override
  String get replayOverview => '总览';

  @override
  String get replayDuration => '时长';

  @override
  String get replayScoringEvents => '得分记录';

  @override
  String get replayFouls => '犯规';

  @override
  String get replayLocationCompleteness => '落点记录比例';

  @override
  String get replayPossession => '球权记录';

  @override
  String get replayFinishedBoundary => '比赛已结束';

  @override
  String get replayInProgressBoundary => '比赛未完成';

  @override
  String get replayNoPossession => '暂无球权记录';

  @override
  String get replayPossessionManual => '人工';

  @override
  String get replayPossessionSuggested => '建议';

  @override
  String get replayPossessionCurrent => '未记录结束时间';

  @override
  String replayPossessionEnded(Object time) {
    return '结束 $time';
  }

  @override
  String replayPossessionReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get replayNoReason => '未填写原因';

  @override
  String get replaySuggestedReason => '命中后根据规则建议球权';

  @override
  String get replayTimeline => '比赛记录';

  @override
  String get replayFilters => '筛选';

  @override
  String get replayNoEvents => '没有符合筛选条件的记录';

  @override
  String get replayFilterAll => '全部';

  @override
  String get replayFilterScores => '得分';

  @override
  String get replayFilterFouls => '犯规';

  @override
  String get replayFilterMisses => '未中';

  @override
  String get replayFilterOther => '其他';

  @override
  String get replayFilterBoth => '双方';

  @override
  String get replayFilterRed => '红方';

  @override
  String get replayFilterBlue => '蓝方';

  @override
  String get replayFilterShowDeleted => '显示已删除';

  @override
  String get replayFilterHideDeleted => '隐藏已删除';

  @override
  String get replayFilterMade => '命中';

  @override
  String get replayFilterMissed => '未中';

  @override
  String get replayFilterPoints => '分值';

  @override
  String replayActionScore(Object points) {
    return '+$points 分';
  }

  @override
  String get replayActionFoul => '犯规';

  @override
  String get replayActionMiss => '投篮未中';

  @override
  String get replayActionRecord => '记录';

  @override
  String get replayMatchSide => '比赛';

  @override
  String get replayDeleted => '已删除';

  @override
  String replayClockPosition(Object seconds) {
    return '比赛时钟 $seconds 秒';
  }

  @override
  String get replayEditorTitle => '编辑记录';

  @override
  String get replayEditorSide => '所属方';

  @override
  String get replayEditorEventKind => '记录类型';

  @override
  String get replayEditorPoints => '分值';

  @override
  String get replayEditorOutcome => '结果';

  @override
  String get replayEditorNote => '备注';

  @override
  String get replayEditorCustomLabel => '自定义标签';

  @override
  String get replayEditorClock => '比赛时钟位置（秒）';

  @override
  String get replayEditorLocationX => '落点 X';

  @override
  String get replayEditorLocationY => '落点 Y';

  @override
  String get replayLocationEditTitle => '保存落点修改';

  @override
  String get replayLocationSaveAction => '保存';

  @override
  String get replayEditorReason => '修改原因（可选）';

  @override
  String get replayEditorDelete => '删除';

  @override
  String get replayEditorRestore => '恢复';

  @override
  String get replayEditorSave => '保存修改';

  @override
  String get replayEditorSaveNote => '保存备注';

  @override
  String get replayEditorInvalidNumber => '请输入有效数字。';

  @override
  String get replayEditorLocationRange => '落点数值必须在 0 到 1 之间。';

  @override
  String get replayEditorDeleteTitle => '删除这条记录？';

  @override
  String get replayEditorDeleteBody =>
      '删除后，这条记录不再计入比分和统计，操作记录会保留。之后可显示已删除记录，再将它恢复。';

  @override
  String get replayEditorConfirmDelete => '确认删除';

  @override
  String get replayEditorRestoreTitle => '恢复这条记录？';

  @override
  String get replayEditorRestoreBody => '恢复后，这条记录会重新计入比分和统计。';

  @override
  String get replayEditorConfirmRestore => '确认恢复';

  @override
  String get replayAuditTitle => '操作记录';

  @override
  String get replayAuditEmpty => '暂无操作记录';

  @override
  String replayAuditReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get replayAuditNoReason => '未填写原因';

  @override
  String get replayAuditActionCreate => '创建';

  @override
  String get replayAuditActionUndo => '撤销';

  @override
  String get replayAuditActionEdit => '编辑';

  @override
  String get replayAuditActionDelete => '删除';

  @override
  String get replayAuditActionImport => '导入';

  @override
  String get replayAuditActionRestore => '恢复';

  @override
  String get replayAuditActionCommand => '执行操作';

  @override
  String get replayAuditActionLocate => '设置落点';

  @override
  String get replayAuditActionPossession => '更新球权';

  @override
  String get replayAuditActionPossessionSuggestion => '建议球权';

  @override
  String get replayAuditActionUnknown => '未知操作';

  @override
  String get replayAuditTargetEvent => '记录';

  @override
  String get replayAuditTargetLocation => '落点';

  @override
  String get replayAuditTargetMatch => '比赛';

  @override
  String get replayAuditTargetCommand => '操作';

  @override
  String get replayAuditFieldType => '记录类型';

  @override
  String get replayAuditFieldSide => '所属方';

  @override
  String get replayAuditFieldPoints => '分数';

  @override
  String get replayAuditFieldOutcome => '结果';

  @override
  String get replayAuditFieldNote => '备注';

  @override
  String get replayAuditFieldCustomLabel => '自定义标签';

  @override
  String get replayAuditFieldClock => '比赛时钟';

  @override
  String get replayAuditFieldDeleted => '已删除';

  @override
  String get replayAuditFieldX => '落点 X';

  @override
  String get replayAuditFieldY => '落点 Y';

  @override
  String get replayAuditValueNone => '—';

  @override
  String get replayAuditValueDeleted => '是';

  @override
  String get replayAuditValueActive => '否';

  @override
  String get replayAnalyticsTitle => '比赛分析';

  @override
  String get replayAnalyticsLeadChanges => '领先变化';

  @override
  String get replayAnalyticsLargestLead => '最大领先';

  @override
  String get replayAnalyticsShootingPercentage => '投篮命中率';

  @override
  String get replayAnalyticsKeyMoments => '关键时刻';

  @override
  String get replayAnalyticsNoAttempts => '暂无出手';

  @override
  String get replayAnalyticsScoringFlow => '比分走势';

  @override
  String get replayAnalyticsNoScoringEvents => '本场暂无得分记录';

  @override
  String get replayAnalyticsKeyPossessions => '关键回合';

  @override
  String get replayAnalyticsNoKeyPossessions => '本场暂无关键回合';

  @override
  String replayAnalyticsScoreSemantics(
    Object blueScore,
    Object points,
    Object redScore,
    Object side,
  ) {
    return '$side 得 $points 分，$redScore 比 $blueScore';
  }

  @override
  String get replayAnalyticsTie => '扳平比分';

  @override
  String get replayAnalyticsOvertake => '完成反超';

  @override
  String get replayAnalyticsMatchPoint => '到达赛点';

  @override
  String get replayAnalyticsScoringRun => '连续得分';

  @override
  String get replayAnalyticsShotRecord => '投篮记录';

  @override
  String get replayAnalyticsRecordedAttempts => '记录的出手';

  @override
  String get replayAnalyticsIncompleteShooting => '记录不完整，暂不显示命中率';

  @override
  String get replayAnalyticsFieldGoals => '投篮';

  @override
  String get replayAnalyticsFreeThrows => '罚球';

  @override
  String get replayAnalyticsFouls => '犯规';

  @override
  String get replayAnalyticsPossessions => '球权';

  @override
  String get replayAnalyticsTrackingCoverage => '记录范围';

  @override
  String get replayAnalyticsLocationCoverage => '位置覆盖';

  @override
  String get replayAnalyticsShotZones => '出手区域';

  @override
  String get replayAnalyticsZoneRestrictedArea => '篮下';

  @override
  String get replayAnalyticsZonePaint => '油漆区';

  @override
  String get replayAnalyticsZoneMidRange => '中距离';

  @override
  String get replayAnalyticsZoneCornerThree => '底角三分';

  @override
  String get replayAnalyticsZoneWingThree => '侧翼三分';

  @override
  String get replayAnalyticsZoneTopThree => '弧顶三分';

  @override
  String get replayAnalyticsZoneUnknown => '未知区域';

  @override
  String get replayAnalyticsTrackingNone => '无记录';

  @override
  String get replayAnalyticsTrackingScoresOnly => '仅记录得分';

  @override
  String get replayAnalyticsTrackingShotAttempts => '记录出手结果';

  @override
  String get replayAnalyticsTrackingLocations => '记录出手与位置';

  @override
  String get replayAnalyticsTrackingFull => '记录完整';

  @override
  String get playerAnalyticsTooltip => '查看球员分析';

  @override
  String get playerAnalyticsTitle => '球员分析';

  @override
  String get playerAnalyticsWindow => '统计时段';

  @override
  String get playerAnalyticsSevenDays => '近 7 天';

  @override
  String get playerAnalyticsThirtyDays => '近 30 天';

  @override
  String get playerAnalyticsNinetyDays => '近 90 天';

  @override
  String get playerAnalyticsAllTime => '全部';

  @override
  String get playerAnalyticsOpponent => '对手';

  @override
  String get playerAnalyticsAllOpponents => '所有对手';

  @override
  String get playerAnalyticsGrowth => '成长趋势';

  @override
  String get playerAnalyticsRecentChange => '近期变化';

  @override
  String get playerAnalyticsAveragePoints => '场均得分';

  @override
  String get playerAnalyticsAverageMargin => '场均分差';

  @override
  String get playerAnalyticsRecord => '胜负战绩';

  @override
  String get playerAnalyticsMatches => '场';

  @override
  String get playerAnalyticsWins => '胜';

  @override
  String get playerAnalyticsShootingTrend => '投篮趋势';

  @override
  String get playerAnalyticsFieldGoals => '投篮';

  @override
  String get playerAnalyticsFreeThrows => '罚球';

  @override
  String get playerAnalyticsRecordedShots => '记录出手';

  @override
  String get playerAnalyticsNoReliablePercentage =>
      '暂无可显示的投篮命中率，需要记录完整且有运动战出手的比赛。';

  @override
  String get playerAnalyticsZoneHeatmap => '出手区域';

  @override
  String get playerAnalyticsNoMatches => '该周期暂无已完成比赛';

  @override
  String get playerAnalyticsNoTrend => '暂无足够的趋势数据';

  @override
  String get playerAnalyticsOpponentNone => '不限对手';

  @override
  String get playerAnalyticsLoadError => '无法读取分析数据';

  @override
  String get playerAnalyticsLoadErrorBody => '无法读取球员分析，请重试。';

  @override
  String get playerAnalyticsNotFound => '找不到球员';

  @override
  String get playerAnalyticsNotFoundBody => '该球员档案可能已被删除。';

  @override
  String get playerAnalyticsRetry => '重试';

  @override
  String get playerComparisonOpen => '比较';

  @override
  String get playerComparisonTitle => '球员比较';

  @override
  String get playerComparisonMode => '比较方式';

  @override
  String get playerComparisonMatchMode => '比赛';

  @override
  String get playerComparisonWindowMode => '时段';

  @override
  String get playerComparisonMatchModeHint => '选择该球员的两场已完成比赛进行比较。';

  @override
  String get playerComparisonWindowModeHint => '比较相邻且不重叠的两个时段，后一时段截止于打开此页面时。';

  @override
  String get playerComparisonBaseline => '参照数据';

  @override
  String get playerComparisonCurrent => '比较数据';

  @override
  String get playerComparisonDifference => '差值';

  @override
  String get playerComparisonSelectBaseline => '选择参照比赛';

  @override
  String get playerComparisonSelectCurrent => '选择比较比赛';

  @override
  String get playerComparisonSwap => '交换两场比赛';

  @override
  String get playerComparisonChooseGame => '选择比赛';

  @override
  String get playerComparisonLoading => '正在比较';

  @override
  String get playerComparisonLoadError => '无法读取比较数据';

  @override
  String get playerComparisonLoadErrorBody => '无法读取比赛比较，请重试。';

  @override
  String get playerComparisonRetry => '重试';

  @override
  String get playerComparisonNoMatches => '暂无可比较比赛';

  @override
  String get playerComparisonNoMatchesBody => '先用该球员档案完成一场比赛，再来比较。';

  @override
  String get playerComparisonNeedTwoMatches => '至少需要两场比赛';

  @override
  String get playerComparisonNeedTwoMatchesBody =>
      '再用该球员档案完成一场比赛，即可比较两场比赛；现在也可以比较时段数据。';

  @override
  String get playerComparisonEmptyWindows => '两个时段都没有比赛';

  @override
  String get playerComparisonEmptyWindowsBody => '试试更长的时段，或取消对手筛选。';

  @override
  String get playerComparisonBaselineEmpty => '参照时段没有比赛。';

  @override
  String get playerComparisonCurrentEmpty => '比较时段没有比赛。';

  @override
  String get playerComparisonSummary => '数据对比';

  @override
  String get playerComparisonResult => '胜负';

  @override
  String get playerComparisonMatchCount => '场次';

  @override
  String get playerComparisonWinRate => '胜率';

  @override
  String get playerComparisonPoints => '得分';

  @override
  String get playerComparisonPointsPerGame => '场均得分';

  @override
  String get playerComparisonMargin => '分差';

  @override
  String get playerComparisonMarginPerGame => '场均分差';

  @override
  String get playerComparisonFieldGoalsMade => '运动战命中';

  @override
  String get playerComparisonFieldGoalAttempts => '运动战出手';

  @override
  String get playerComparisonFieldGoalPercentage => '运动战命中率';

  @override
  String get playerComparisonFreeThrowsMade => '罚球命中';

  @override
  String get playerComparisonFreeThrowAttempts => '罚球出手';

  @override
  String get playerComparisonFreeThrowPercentage => '罚球命中率';

  @override
  String get playerComparisonLocationCoverage => '落点记录比例';

  @override
  String get playerComparisonConfirmedZones => '已确认落点的区域分布';

  @override
  String get playerComparisonConfirmedZonesNote => '各区域占比只按已确认的运动战落点计算。';

  @override
  String get playerComparisonIncrease => '增加';

  @override
  String get playerComparisonDecrease => '减少';

  @override
  String get playerComparisonEqual => '持平';

  @override
  String get playerComparisonInsufficientData => '数据不足';

  @override
  String get playerComparisonWin => '胜';

  @override
  String get playerComparisonLoss => '负';

  @override
  String get playerComparisonTie => '平';

  @override
  String get playerComparisonPercentagePoints => '个百分点';

  @override
  String get replayMoreActions => '更多操作';

  @override
  String get legacyBootstrapTitle => '球豆数据兼容性检查';

  @override
  String get legacyBootstrapHeadline => '无法打开旧版 v0.1 数据';

  @override
  String legacyBootstrapBody(Object version) {
    return '旧版数据库$version与当前版本不兼容。原文件会保持原样，球豆不会自动转换、删除或清空它。请先导出或备份旧文件，再用当前版本新建本地数据。';
  }

  @override
  String get bootstrapFailureBody => '本地记录暂时打不开，现有数据没有改动。请稍后重试，或新建本地数据库。';

  @override
  String get entryPreparingRecords => '正在打开本地记录…';

  @override
  String get settingsDefaultSection => '默认值';

  @override
  String get settingsDefaultRuleTitle => '默认计分规则';

  @override
  String get settingsDefaultRuleSubtitle => '当前沿用赛前设置';

  @override
  String get settingsRulesSection => '比赛规则';

  @override
  String get settingsRulesTemplateTitle => '规则模板';

  @override
  String get settingsRulesTemplateSubtitle => '内置模板与自定义比赛规则';

  @override
  String get settingsFeedbackSection => '计分反馈';

  @override
  String get settingsHapticTitle => '振动反馈';

  @override
  String get settingsHapticEnabled => '已开启';

  @override
  String get settingsHapticDisabled => '已关闭';

  @override
  String get settingsSoundTitle => '操作音效';

  @override
  String get settingsSoundEnabled => '已开启';

  @override
  String get settingsSoundDisabled => '已关闭';

  @override
  String get settingsAppearanceSection => '外观';

  @override
  String get settingsLanguageSection => '语言';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageSubtitle => '选择应用界面语言';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsThemeTitle => '主题';

  @override
  String get settingsThemeSubtitle => '选择浅色、深色或跟随系统';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsMotionTitle => '动效';

  @override
  String get settingsMotionSubtitle => '使用标准动效，或减少动画';

  @override
  String get settingsMotionStandard => '标准动效';

  @override
  String get settingsMotionReduced => '减少动效';

  @override
  String get settingsMotionHelp => '减少动效会缩短过渡，关闭装饰性动画。';

  @override
  String get settingsMotionPreview => '动效预览';

  @override
  String get settingsMotionPreviewStandard => '预览：标准动效';

  @override
  String get settingsMotionPreviewReduced => '预览：减少动效';

  @override
  String get settingsDataSection => '数据';

  @override
  String get settingsDataManagementTitle => '数据与备份';

  @override
  String get settingsDataManagementSubtitle => '导出数据、恢复备份、设置自动备份';

  @override
  String get settingsManualDataSection => '导出与恢复';

  @override
  String get settingsAutomaticBackupSection => '自动备份设置';

  @override
  String get settingsExportDataTitle => '导出数据';

  @override
  String get settingsExportDataSubtitle => 'JSON 备份可恢复数据，CSV 文件可用于分析';

  @override
  String get settingsExportDataDialogTitle => '选择导出格式';

  @override
  String get settingsStatisticsSection => '统计';

  @override
  String get settingsStatisticsSubtitle => '基于本地比赛事件计算';

  @override
  String get settingsBackupSection => '备份与导出';

  @override
  String get settingsExportBackupTitle => '导出完整备份';

  @override
  String get settingsExportBackupSubtitle => 'JSON 文件，包含比赛、球员、规则、事件和设置';

  @override
  String get settingsExportBackupSuccess => '已打开分享界面，可保存或发送备份文件';

  @override
  String get settingsRestoreTitle => '从备份恢复';

  @override
  String get settingsRestoreSubtitleMerge => '合并备份，或先备份当前数据再完整替换';

  @override
  String get settingsRestoreSubtitleBlocked => '比赛进行中可以合并；替换数据需先结束比赛';

  @override
  String get settingsExportCsvTitle => '导出 CSV';

  @override
  String get settingsExportCsvSubtitle => '导出 3 个文件：比赛列表、事件列表和球员统计';

  @override
  String get settingsExportCsvSuccess => '已打开分享界面，可保存 3 个 CSV 文件';

  @override
  String get settingsAutomaticBackupTitle => '自动备份';

  @override
  String get settingsAutomaticBackupEnabled => '已开启';

  @override
  String get settingsAutomaticBackupDisabled => '已关闭';

  @override
  String get settingsBackupDirectoryTitle => '备份位置';

  @override
  String get settingsBackupDirectoryPickerTitle => '选择自动备份文件夹';

  @override
  String get settingsBackupDirectoryUnselected => '尚未选择，只会访问你选择的文件夹';

  @override
  String get settingsBackupNowTitle => '立即备份';

  @override
  String get settingsBackupNever => '还没有手动或自动备份记录';

  @override
  String settingsBackupLastSuccess(Object date, Object time) {
    return '上次备份成功：$date $time';
  }

  @override
  String get settingsBackupRetentionTitle => '保留几份自动备份';

  @override
  String get settingsBackupRetentionSubtitle => '只清理多余的球豆自动备份，手动备份和安全副本不受影响';

  @override
  String get settingsPrivacySection => '隐私';

  @override
  String get settingsPrivacyTitle => '本地数据';

  @override
  String get settingsPrivacySubtitle => '个人数据保存在本机，球豆不会上传';

  @override
  String get settingsExperimentalSection => '实验功能';

  @override
  String get settingsExperimentalTitle => '实验功能开关';

  @override
  String get settingsExperimentalSubtitle => '当前没有可用实验功能';

  @override
  String get settingsDiagnosticsSection => '开发诊断';

  @override
  String get settingsDiagnosticsTitle => '诊断信息';

  @override
  String get settingsDiagnosticsSubtitle => '当前没有诊断数据';

  @override
  String get settingsProjectSection => '项目详情';

  @override
  String get settingsAboutTitle => '关于球豆';

  @override
  String get settingsAboutSection => '关于';

  @override
  String get settingsAboutSubtitle => '永久免费开源，查看许可证与贡献方式';

  @override
  String get settingsRestoreDialogTitle => '如何恢复备份？';

  @override
  String get settingsRestorePickerTitle => '选择球豆备份';

  @override
  String get settingsMergeTitle => '合并导入（推荐）';

  @override
  String get settingsMergeSubtitle =>
      '保留本机设置和正在进行的比赛。冲突记录会另存，不会覆盖本机记录；不会仅因昵称相同就合并球员。';

  @override
  String get settingsReplaceTitle => '替换本机数据';

  @override
  String get settingsReplaceSubtitle => '先备份并验证当前数据，再用所选备份替换全部本机数据；失败则保留原数据';

  @override
  String get settingsReplaceBlocked => '请先结束正在进行的比赛';

  @override
  String get settingsReplaceConfirmTitle => '替换全部本机数据？';

  @override
  String get settingsReplaceConfirmBody =>
      '备份文件验证通过后，球豆会先保存并验证当前数据的备份（安全副本），再用所选备份替换全部本机数据。任一步失败都不会替换。请先结束正在进行的比赛。';

  @override
  String get settingsReplaceConfirmAction => '选择备份';

  @override
  String get settingsRestoreNotSelected => '未选择备份文件';

  @override
  String get settingsMergeCompleted => '备份已合并，本机设置和正在进行的比赛保持不变';

  @override
  String get settingsReplaceCompleted => '已用备份替换本机数据，自动备份位置已重置';

  @override
  String get settingsDirectoryUpdated => '自动备份位置已更新';

  @override
  String get settingsDirectoryNotSelected => '未选择文件夹';

  @override
  String get settingsAutomaticBackupNotConfigured => '未选择文件夹，自动备份保持关闭';

  @override
  String get settingsAutomaticBackupTurnedOn => '自动备份已开启';

  @override
  String get settingsAutomaticBackupTurnedOff => '自动备份已关闭';

  @override
  String get settingsHapticTurnedOn => '振动反馈已开启';

  @override
  String get settingsHapticTurnedOff => '振动反馈已关闭';

  @override
  String get settingsSoundTurnedOn => '操作音效已开启';

  @override
  String get settingsSoundTurnedOff => '操作音效已关闭';

  @override
  String get settingsBackupWritten => '备份已保存到所选文件夹';

  @override
  String settingsRetentionUpdated(Object count) {
    return '将保留最近 $count 份自动备份';
  }

  @override
  String get settingsErrorChecksum => '备份校验失败，文件可能已损坏或被修改';

  @override
  String get settingsErrorFutureVersion => '这份备份来自较新版本，请更新球豆后再试';

  @override
  String get settingsErrorInvalidBackup => '备份内容无效，现有数据未被修改';

  @override
  String get settingsErrorMerge => '备份合并失败，本机数据未被修改';

  @override
  String get settingsErrorDirectoryRequired => '请先选择自动备份文件夹';

  @override
  String get settingsErrorDirectoryUnavailable => '无法保存到所选文件夹，请重新选择';

  @override
  String get settingsErrorBackupWrite => '备份未能保存，请重新选择备份文件夹后再试';

  @override
  String get settingsErrorRestoreBlocked => '请先结束正在进行的比赛';

  @override
  String get settingsErrorGeneric => '操作失败，请稍后重试';

  @override
  String get playerAnalyticsNoLocationData => '暂无落点数据';

  @override
  String get homePlayersTooltip => '球员';

  @override
  String get homeSettingsTooltip => '设置';

  @override
  String get homeProjectTooltip => '项目详情';

  @override
  String get homeActiveMatch => '进行中的比赛';

  @override
  String get homeClockNotConfigured => '未开启计时';

  @override
  String get homeClockRegulationExpired => '常规时间结束';

  @override
  String get homeClockRunning => '计时进行中';

  @override
  String get homeClockPaused => '计时已暂停';

  @override
  String get homeLastPersistedUnknown => '上次保存时间未知';

  @override
  String homeLastPersisted(Object date) {
    return '最近保存：$date';
  }

  @override
  String get homeResumeMatch => '继续比赛';

  @override
  String get homeAbandonMatch => '放弃比赛';

  @override
  String get homeAbandonTitle => '放弃这场比赛？';

  @override
  String get homeAbandonBody => '比赛记录仍会保留，但不能再从主页继续这场比赛。';

  @override
  String get homeConfirmAbandon => '确认放弃';

  @override
  String get homeActiveMatchBlocked => '已有进行中的比赛，请先继续或放弃它。';

  @override
  String get homeVersus => '对阵';

  @override
  String get playersTitle => '球员';

  @override
  String get playersCreate => '新建球员';

  @override
  String get playersEdit => '编辑球员';

  @override
  String get playersEmptyTitle => '还没有保存的球员';

  @override
  String get playersEmptyBody => '不保存档案也能直接比赛。保存后，下次选人更方便。';

  @override
  String get playersLoadError => '无法读取球员';

  @override
  String get playersLoadErrorBody => '本地球员数据暂时无法打开。';

  @override
  String get retryAction => '重试';

  @override
  String get playersPreferredRed => '偏好红方';

  @override
  String get playersPreferredBlue => '偏好蓝方';

  @override
  String get playersPreferredUnset => '未设置偏好方';

  @override
  String get playerSaveFailed => '保存失败，请重试。';

  @override
  String get playerDeleteTitle => '删除球员？';

  @override
  String get playerDeleteBody => '只会删除此球员档案，不会删除已有比赛记录。';

  @override
  String get deleteAction => '删除';

  @override
  String get playerDeleteFailed => '删除失败，请重试。';

  @override
  String get playerNewTitle => '新建球员';

  @override
  String get playerEditTitle => '编辑球员';

  @override
  String get playerDeleteTooltip => '删除球员';

  @override
  String get playerSaveTooltip => '保存球员';

  @override
  String get playerOpenError => '无法打开球员档案';

  @override
  String get playerOpenErrorBody => '无法打开该球员档案，请重试。';

  @override
  String get playerNicknameLabel => '昵称';

  @override
  String get playerNicknameRequired => '请输入球员昵称';

  @override
  String get playerPreferredSide => '偏好方';

  @override
  String get playerSideAny => '不限';

  @override
  String get playerSideRed => '红方';

  @override
  String get playerSideBlue => '蓝方';

  @override
  String get playerNoteLabel => '备注';

  @override
  String get playerNoteHint => '打法、习惯或需要记住的信息';

  @override
  String get playerSaving => '保存中';

  @override
  String get rulesTitle => '规则模板';

  @override
  String get rulesEmptyTitle => '暂无规则模板';

  @override
  String get rulesEmptyBody => '创建一套常用规则，下场比赛直接选。';

  @override
  String get rulesCreate => '新建规则';

  @override
  String get rulesLoadError => '规则模板读取失败';

  @override
  String get rulesLoadErrorBody => '暂时读不到规则模板，请重试。';

  @override
  String get rulesBuiltIn => '内置';

  @override
  String get rulesCustom => '自定义';

  @override
  String get ruleBuiltInFreeScoring => '自由计分';

  @override
  String get ruleBuiltInElevenWinByTwo => '11 分制（领先 2 分）';

  @override
  String get ruleBuiltInTwentyOne => '21 分制';

  @override
  String get ruleBuiltInTimedTen => '10 分钟计时';

  @override
  String rulesScoringButtons(Object buttons) {
    return '计分 $buttons';
  }

  @override
  String rulesTarget(Object points) {
    return '目标 $points 分';
  }

  @override
  String rulesMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String get rulesWinByTwo => '领先 2 分';

  @override
  String get ruleNewTitle => '新建规则';

  @override
  String get ruleEditTitle => '编辑规则';

  @override
  String get ruleNameLabel => '模板名称';

  @override
  String get ruleNameRequired => '请输入名称';

  @override
  String get ruleTargetLabel => '目标分（可选）';

  @override
  String get ruleTimeLimitLabel => '时限（分钟，可选）';

  @override
  String get ruleFoulLimitLabel => '犯规上限（可选）';

  @override
  String get ruleScoreButtonsLabel => '每次记几分（用逗号分隔）';

  @override
  String get ruleCustomLabelsLabel => '自定义事件名称（用逗号分隔）';

  @override
  String get ruleWinByTwoTitle => '领先 2 分获胜';

  @override
  String get rulePossessionHintTitle => '得分后提示球权';

  @override
  String get rulePossessionHintSubtitle => '只作提示，仍可手动记分';

  @override
  String get rulePossessionPolicyLabel => '得分后球权归谁';

  @override
  String get rulePossessionPolicyHelper => '先打开球权提示，再选择提示方式。';

  @override
  String get ruleSaveAction => '保存规则';

  @override
  String rulePositiveInteger(Object label) {
    return '$label 必须为正整数';
  }

  @override
  String get ruleAtLeastOneInteger => '至少填写一个正整数';

  @override
  String get rulePolicyManual => '手动设置';

  @override
  String get rulePolicySwitchAfterMade => '命中后交换球权';

  @override
  String get rulePolicyKeepAfterMade => '命中后保留球权';

  @override
  String get pregameTitle => '赛前设置';

  @override
  String get pregamePlayers => '球员';

  @override
  String get pregameRuleTemplate => '规则模板';

  @override
  String get pregameFreeScoring => '自由计分';

  @override
  String get pregameElevenPoint => '11 分制';

  @override
  String get pregameTwentyOnePoint => '21 分制';

  @override
  String get pregameTimer => '计时';

  @override
  String get pregameWinByTwo => '领先 2 分获胜';

  @override
  String get pregameAdvanced => '高级设置';

  @override
  String get pregameTargetScore => '目标分';

  @override
  String get pregameEditTargetScore => '编辑目标分';

  @override
  String get pregameConfirmTargetScore => '确认';

  @override
  String pregameTargetScoreRange(int min, int max) {
    return '请输入 $min～$max 的整数';
  }

  @override
  String get pregamePoint => '分';

  @override
  String get pregameStartMatch => '开始比赛';

  @override
  String get pregameRecordingMode => '记录模式（必选）';

  @override
  String get pregameTrackingCoverage => '失误追踪范围';

  @override
  String get pregameClockMode => '计时方式';

  @override
  String get pregameTemporaryParticipant => '临时姓名（未关联档案）';

  @override
  String get pregameManageRules => '管理规则模板';

  @override
  String get pregameSimpleMode => '简洁记录';

  @override
  String get pregameDetailedMode => '详细记录';

  @override
  String get pregameTrackingHelper => '选择需要记录到比赛回放中的出手与失误范围。';

  @override
  String get pregameTimerEnabled => '已开启：请选择计时方式';

  @override
  String get pregameTimerDisabled => '关闭后不记录比赛时间';

  @override
  String get pregameCountUp => '正计时';

  @override
  String get pregameCountDown => '倒计时';

  @override
  String get pregameCountdownLabel => '倒计时（1–180 分钟）';

  @override
  String get pregameCountdownHelper => '倒计时必须设置在 1 到 180 分钟之间。';

  @override
  String get pregameMinutes => '分钟';

  @override
  String get pregameProfileConflict => '另一方已经选了这名球员，请换一个档案。';

  @override
  String get pregameCountdownInvalid => '请输入 1 到 180 的整数分钟。';

  @override
  String get pregameTrackingNone => '不追踪出手与失误';

  @override
  String get pregameTrackingScoresOnly => '仅记录比分';

  @override
  String get pregameTrackingShotAttempts => '投篮出手';

  @override
  String get pregameTrackingLocations => '投篮出手与位置';

  @override
  String get pregameTrackingFull => '完整记录（含失误）';

  @override
  String get pregameDeletedPlayer => '已删除的球员档案';

  @override
  String get pregameParticipationMode => '选择球员';

  @override
  String pregameTemporaryName(Object side) {
    return '$side临时姓名';
  }

  @override
  String pregameNameSnapshot(Object side) {
    return '$side本场姓名';
  }

  @override
  String get pregameTemporaryHint => '可输入临时姓名；双方临时同名也可以。';

  @override
  String get pregameSnapshotHint => '只改这场比赛的姓名，球员档案保持原样。';

  @override
  String get pregameRed => '红方';

  @override
  String get pregameBlue => '蓝方';

  @override
  String get pregameValidationRedRequired => '请输入红方姓名。';

  @override
  String get pregameValidationBlueRequired => '请输入蓝方姓名。';

  @override
  String get pregameValidationDuplicateProfile => '双方不能选同一个球员档案。';

  @override
  String get pregameValidationRedMissing => '找不到红方选择的球员档案，请重选或输入临时姓名。';

  @override
  String get pregameValidationBlueMissing => '找不到蓝方选择的球员档案，请重选或输入临时姓名。';

  @override
  String get pregameValidationModeRequired => '请选择记录模式后再开始比赛。';

  @override
  String get pregameValidationCountdownRequired => '请先开启计时，再选择倒计时。';

  @override
  String get pregameValidationCountdownDuration => '倒计时请设为 1 到 180 分钟。';

  @override
  String get scoringSimpleRedShot => '红方出手';

  @override
  String get scoringSimpleBlueShot => '蓝方出手';

  @override
  String get scoringMade => '命中';

  @override
  String get scoringMissed => '未命中';

  @override
  String scoringPoints(Object points) {
    return '$points 分';
  }

  @override
  String get scoringCancelDraft => '取消草稿';

  @override
  String get scoringSubmitShot => '提交投篮';

  @override
  String get scoringUndo => '撤销';

  @override
  String get scoringLocateLastShot => '定位最近投篮';

  @override
  String get scoringPause => '暂停';

  @override
  String get scoringFinishShort => '结束';

  @override
  String get scoringMatchControlsTitle => '结束或暂停比赛？';

  @override
  String get scoringMatchControlsBody => '暂时离开可以先暂停；打完了就确认比分并结束比赛。';

  @override
  String get scoringReturnToScoring => '返回计分';

  @override
  String get scoringPauseMatch => '暂停比赛';

  @override
  String get scoringMatchPausedTitle => '比赛已暂停';

  @override
  String get scoringMatchPausedBody => '比赛暂停中，继续后就能接着记分。';

  @override
  String get scoringReturnHome => '返回主页';

  @override
  String get scoringPendingPauseExitBody =>
      '球场上还有灰色投篮点未确认。返回主页或结束比赛会丢弃这次未完成的记录。';

  @override
  String get scoringDiscardDraft => '丢弃未完成记录';

  @override
  String get scoringResume => '恢复';

  @override
  String get scoringBlueFreeThrowMade => '蓝罚中';

  @override
  String get scoringBlueFreeThrowMissed => '蓝罚失';

  @override
  String get scoringRedFreeThrowMade => '红罚中';

  @override
  String get scoringRedFreeThrowMissed => '红罚失';

  @override
  String get scoringPossessionBlue => '球权蓝';

  @override
  String get scoringPossessionRed => '球权红';

  @override
  String get scoringNote => '备注';

  @override
  String get scoringCustom => '自定义';

  @override
  String get scoringClockRunning => '计时进行中';

  @override
  String scoringClockStatus(Object status) {
    return '计时状态：$status';
  }

  @override
  String get scoringPendingLocationTitle => '这次投篮还没记完';

  @override
  String get scoringPendingDraftTitle => '当前有未提交投篮';

  @override
  String get scoringPendingLocationBody => '可以继续把这次投篮记完，也可以取消未完成的操作后离开。';

  @override
  String get scoringPendingDraftBody => '离开前请取消或提交当前投篮草稿。';

  @override
  String get scoringStay => '留在本场';

  @override
  String get scoringCancelLocationLeave => '取消并离开';

  @override
  String get scoringCancelDraftLeave => '取消草稿并离开';

  @override
  String get scoringSubmitLeave => '提交并离开';

  @override
  String get scoringDraftCreateFailed => '当前无法创建投篮草稿';

  @override
  String get scoringMissTrackingDisabled => '当前设置不记录未命中投篮';

  @override
  String get scoringActionRejected => '请先完成当前落点或未记完的投篮';

  @override
  String get scoringFreeThrowTrackingDisabled => '当前跟踪设置不记录该罚球';

  @override
  String get scoringPossessionNotCommitted => '球权修改未提交';

  @override
  String get scoringNoUnlocatedShot => '暂无可定位的未标记投篮';

  @override
  String get scoringLocationCancelFailed => '当前落点无法取消';

  @override
  String get scoringUndoFailed => '没能撤销';

  @override
  String get scoringPauseFailed => '当前无法暂停计时';

  @override
  String get scoringResumeFailed => '当前无法恢复计时';

  @override
  String get scoringDraftIncomplete => '投篮草稿尚未完成';

  @override
  String get scoringNoDraft => '当前没有可取消的草稿';

  @override
  String get scoringAddNote => '添加备注';

  @override
  String get scoringNoteHint => '例如：暂停、战术安排或场上情况';

  @override
  String get scoringRecordNote => '保存备注';

  @override
  String get scoringRecordCustom => '记录自定义事件';

  @override
  String get scoringEventLabel => '事件名称';

  @override
  String get scoringRecordEvent => '记录事件';

  @override
  String get scoringNoTimer => '无计时';

  @override
  String get scoringTimerNotConfigured => '未开启计时';

  @override
  String get scoringOvertime => '加时赛';

  @override
  String get scoringRegulationExpired => '常规时间结束';

  @override
  String get scoringClockPaused => '计时已暂停';

  @override
  String get scoringBackToScoringList => '返回计分';

  @override
  String scoringMatchTime(Object time) {
    return '比赛时间：$time';
  }

  @override
  String get scoringResumeClock => '恢复计时';

  @override
  String get scoringMarkShotTitle => '标记投篮位置？';

  @override
  String get scoringMarkShotBody => '可在球场上点选或拖动圆点后确认。';

  @override
  String get scoringDoNotMark => '不标记';

  @override
  String get scoringMark => '标记';

  @override
  String get scoringResolvePending => '请先确认或取消落点，也可以撤销这次投篮';

  @override
  String get scoringReplay => '复盘';

  @override
  String get courtReplayLabel => '复盘球场';

  @override
  String get courtEditLabel => '篮球场投篮位置编辑区';

  @override
  String get courtReplayHint => '查看已记录的投篮';

  @override
  String get courtEditHint => '点击球场记录或调整投篮落点';

  @override
  String get routeLoading => '正在加载';

  @override
  String get routeHomeLoadError => '无法读取进行中的比赛';

  @override
  String get routeActiveMatchCheckError => '暂时查不到比赛状态';

  @override
  String get routeActiveMatchCheckBody => '请返回主页重试，先确认是否有比赛正在进行。';

  @override
  String get routeMatchLoadError => '无法读取比赛';

  @override
  String get routeMatchNotActive => '这场比赛不在进行中';

  @override
  String get routeMatchNotActiveBody => '请从主页继续进行中的比赛。';

  @override
  String get routeMatchRestoring => '正在恢复比赛';

  @override
  String get routeMatchRestoringBody => '正在恢复计分记录，请稍候。';

  @override
  String get routeReplayOpenError => '无法打开复盘';

  @override
  String get routeReplayOpenErrorBody => '比赛数据读取失败，请返回后重试。';

  @override
  String get routeReplayNotFound => '没有找到这场比赛';

  @override
  String get routeReplayNotFoundBody => '记录可能已被移除。';

  @override
  String get routeActiveMatchTitle => '已有进行中的比赛';

  @override
  String get routeContinueMatch => '继续比赛';

  @override
  String get routeAbandonMatch => '放弃比赛';

  @override
  String get routeActiveCheckLoading => '正在查找进行中的比赛，请稍后再试。';

  @override
  String get routeStartMatchConflict => '已有进行中的比赛，请先继续或放弃它。';

  @override
  String get routeAbandonFailed => '无法放弃比赛，请重试。';

  @override
  String get routeResumeFailed => '无法恢复比赛，请重试。';

  @override
  String get routeLeaveTitle => '离开比赛';

  @override
  String get routeLeaveBody => '可以继续计时，或先暂停再离开。';

  @override
  String get routeLeaveStay => '留在比赛';

  @override
  String get routeLeaveKeepRunning => '继续计时';

  @override
  String get routeLeavePauseAndLeave => '暂停并离开';

  @override
  String get routeClockCheckError => '暂时无法确认计时状态，请留在本场重试。';

  @override
  String get routeProjectLinkError => '无法打开链接，请稍后重试。';

  @override
  String get projectTitle => '项目详情';

  @override
  String get projectTagline => '一对一篮球的本地计分与复盘工具。';

  @override
  String get projectFreeForever => '永久免费';

  @override
  String get projectFreeForeverDetail => '核心计分和复盘功能永久免费。';

  @override
  String get projectOpenSource => '永久开源';

  @override
  String get projectOpenSourceDetail => '源代码始终公开，欢迎查看和参与。';

  @override
  String get projectOffline => '本地离线';

  @override
  String get projectOfflineDetail => '不用注册，没网络也能记比赛。';

  @override
  String get projectPrivacy => '不会上传个人数据';

  @override
  String get projectPrivacyDetail => '球员和比赛数据保存在本机，球豆不会上传。';

  @override
  String get projectOpen => '查看与参与';

  @override
  String get projectContribute => '贡献指南';

  @override
  String get projectIssue => '问题反馈';

  @override
  String get projectOpenBrowser => '在浏览器中打开';

  @override
  String get exportBackupDialogTitle => '选择球豆备份';

  @override
  String get exportAutomaticBackupDialogTitle => '选择自动备份文件夹';

  @override
  String get exportFullBackupSubject => '球豆完整本地备份';

  @override
  String get exportSafetyBackupSubject => '球豆恢复前安全备份';

  @override
  String get exportCsvSubject => '球豆 CSV 数据导出';

  @override
  String get exportReplaySubject => '球豆比赛复盘';

  @override
  String get projectGitHub => 'GitHub';

  @override
  String get projectLicense => '许可证';

  @override
  String get historyImportedIncompleteTitle => '从备份导入的未完成比赛';

  @override
  String get historyImportedIncompleteBody => '这场比赛从备份导入，还没结束，可以继续记分。';

  @override
  String get historyResumeImportedIncomplete => '继续这场比赛';

  @override
  String get historyResumeImportedIncompleteFailed =>
      '没能继续这场比赛，请先确认没有其他比赛正在进行。';

  @override
  String get historyImportedIncompleteLoadError => '暂时读不到从备份导入的未完成比赛。';

  @override
  String get historyImportedIncompleteRetry => '重试';

  @override
  String get pregameTemplatesFallbackLoading => '暂时读不到规则模板，先用内置规则。球员档案还在加载中。';

  @override
  String get pregamePlayersLoading => '球员档案还在加载中，也可以先输入临时姓名。';

  @override
  String get pregameTemplatesPlayersError => '暂时读不到规则模板和球员档案，可以先用临时姓名开赛。';

  @override
  String get pregamePlayersError => '暂时读不到球员档案，可以先用临时姓名开赛。';

  @override
  String get pregameTemplatesFallbackNotice => '暂时读不到规则模板，先用内置规则。';

  @override
  String get scoringConfirmLocation => '确认落点';

  @override
  String get scoringSkipLocation => '取消定位';

  @override
  String get scoringFoul => '犯规';

  @override
  String scoringFoulForSide(Object side) {
    return '$side犯规';
  }

  @override
  String get scoringMore => '更多';

  @override
  String get scoringShotsGroup => '投篮';

  @override
  String get scoringShotDisplayGroup => '投篮显示';

  @override
  String scoringShowMissMarkers(Object side) {
    return '显示$side未命中点';
  }

  @override
  String get scoringDisplayShown => '已显示';

  @override
  String get scoringDisplayHidden => '已隐藏';

  @override
  String get scoringFreeThrowsGroup => '罚球';

  @override
  String get scoringMatchStatusGroup => '比赛状态';

  @override
  String get scoringRecordsGroup => '记录';

  @override
  String get scoringNotesCustomRecordsGroup => '备注与自定义记录';

  @override
  String get scoringMatchGroup => '比赛';

  @override
  String get scoringChooseScoringSide => '请选择蓝方或红方得分';

  @override
  String scoringSupplementPrompt(Object points, Object seconds, Object side) {
    return '补充$side +$points 落点 · 剩余 $seconds秒';
  }

  @override
  String scoringMissSupplementPrompt(Object seconds, Object side) {
    return '补充$side未命中落点 · 剩余 $seconds秒';
  }

  @override
  String get scoringSupplementExpired => '补落点的时间已过';

  @override
  String scoringScoreSemantics(Object points, Object side) {
    return '$side +$points 分';
  }

  @override
  String scoringLocationPendingSemantics(
    Object points,
    Object seconds,
    Object side,
  ) {
    return '$side +$points，还有 $seconds 秒可补落点';
  }

  @override
  String scoringMissSemantics(Object side) {
    return '$side未命中';
  }

  @override
  String scoringMissLocationPendingSemantics(Object seconds, Object side) {
    return '$side未命中，还有 $seconds 秒可补落点';
  }

  @override
  String get updateTitle => '软件更新';

  @override
  String get updateSubtitle => '检查、下载并安装新版本';

  @override
  String updateCurrentVersion(Object version) {
    return '当前版本：$version';
  }

  @override
  String get updateAutoCheck => '启动时检查更新';

  @override
  String get updateAutoCheckDetail => '启动后会联网检查新版本，不上传比赛或球员记录。关闭后仍可手动检查。';

  @override
  String get updateCheck => '检查更新';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String get updateUpToDate => '已是最新版本';

  @override
  String updateAvailable(Object version) {
    return '发现新版本 $version';
  }

  @override
  String updateDownloadSize(Object size) {
    return '下载大小：$size';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍后';

  @override
  String get updateDownload => '下载更新';

  @override
  String get updateDownloadQueued => '等待系统开始下载';

  @override
  String updateDownloading(Object received, Object total) {
    return '正在下载 $received / $total';
  }

  @override
  String get updateDownloadPaused => '下载已暂停，系统会在条件允许时继续';

  @override
  String get updateVerifying => '正在校验安装包…';

  @override
  String get updateReady => '安装包已就绪';

  @override
  String get updateInstall => '安装更新';

  @override
  String get updateCancelDownload => '取消下载';

  @override
  String get updateRetryDownload => '重新下载';

  @override
  String get updateCheckFailed => '暂时无法检查更新，请确认网络后重试。';

  @override
  String get updateDownloadFailed => '下载未完成，请检查网络和存储空间后重试。';

  @override
  String get updateVerificationFailed => '安装包校验失败，请重新下载。';

  @override
  String get updateFileMissing => '安装包已被移除，请重新下载。';

  @override
  String get updateInstallBlocked => '请先完成或结束当前比赛，再安装更新。尚未确认比赛状态时，也无法安装。';

  @override
  String get updatePermissionTitle => '允许安装更新';

  @override
  String get updatePermissionBody => '请在系统设置中允许球豆安装应用，再返回这里。最后还需要你在系统安装界面确认。';

  @override
  String get updateOpenSettings => '打开系统设置';

  @override
  String get updateInstallFailed => '无法打开安装界面，请检查系统安装权限后重试。';

  @override
  String get updateInstallerOpened => '已打开系统安装界面，请在那里确认安装。取消后可以再次点击安装。';

  @override
  String get updateIncompatible => '新版本需要更新的 Android 系统，当前设备无法安装。';

  @override
  String get updateUnsupported => '当前平台暂不支持应用内更新。';

  @override
  String get updateSettingsFailed => '设置未保存，请重试。';

  @override
  String get updateFallback => '正在使用 GitHub 备用下载渠道';

  @override
  String get pregameGoalScoringMode => '计分方式';

  @override
  String get pregameGoalModeFree => '自由计分';

  @override
  String get pregameGoalModeTarget => '目标计分';

  @override
  String get ruleBuiltInDefault => '默认规则';

  @override
  String get scoringTargetReachedTitle => '已达到目标分';

  @override
  String scoringTargetPoints(int target) {
    return '目标 $target 分';
  }

  @override
  String scoringTargetReachedPlayer(String name) {
    return '$name已达到目标分';
  }

  @override
  String get scoringTargetReachedTie => '双方已达到目标分，当前平分';

  @override
  String get scoringTargetSupplement => '可先补上最后一球的落点';

  @override
  String get scoringTargetSkipLocation => '跳过落点';

  @override
  String get scoringTargetUndoScore => '撤销上一笔得分';

  @override
  String get scoringTargetContinueHelp => '继续后，本场不再提醒目标分';

  @override
  String get summaryGameFinished => '比赛结束';

  @override
  String summaryWinner(String name) {
    return '$name获胜';
  }
}
