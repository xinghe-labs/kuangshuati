/// 限时训练的纯函数：无 UI、无 IO，方便单测。
library;

/// 单题限时可选档位（秒），0 表示不限时。
const List<int> questionTimeLimitChoices = [0, 45, 60, 75, 90, 120];

/// 模考分模块时间预算：把整卷时长按各模块题数占比分摊。
///
/// 行测整卷只有一个总倒计时，但考生真正的节奏感来自模块——
/// 「资料分析 20 题大约配 25 分钟」是备考常识。这里把每个模块的
/// 预算算出来显示，超了变红提醒。不强制跳题：打断用户自己的
/// 做题策略比超时更伤。
///
/// 预算 = 总时长 × 模块题数占比，向上取整（宁多勿少，避免预算
/// 加起来小于总时长导致最后模块被克扣）。
Map<String, int> moduleBudgetsSeconds({
  required int totalBudgetSeconds,
  required Map<String, int> questionCountByModule,
}) {
  if (totalBudgetSeconds <= 0) return const {};
  final total = questionCountByModule.values.fold(0, (a, b) => a + b);
  if (total == 0) return const {};
  final budgets = <String, int>{};
  for (final entry in questionCountByModule.entries) {
    if (entry.value <= 0) continue;
    budgets[entry.key] = (totalBudgetSeconds * entry.value / total).ceil();
  }
  return budgets;
}

/// 秒数 → mm:ss（超过一小时 → h:mm:ss），负数按 0 处理。
String formatLimitClock(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final twoM = m.toString().padLeft(2, '0');
  final twoS = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$twoM:$twoS' : '$twoM:$twoS';
}

/// 单题限时倒计时的展示文案与严重程度。
/// remainingSec < 0 表示已超时。
({String label, bool warn, bool over}) questionLimitPresentation(
  int remainingSec,
  int limitSec,
) {
  if (remainingSec < 0) {
    return (label: '已超时 +${formatLimitClock(-remainingSec)}', warn: false, over: true);
  }
  // 剩余不足三分之一或不足 10 秒时预警：长题（90s 档）提前 30 秒
  // 就该收尾，短题（45s 档）留 10 秒检查。
  final warn = remainingSec < 10 || remainingSec * 3 < limitSec;
  return (label: '本题 ${formatLimitClock(remainingSec)}', warn: warn, over: false);
}
