import '../data/database/app_database.dart';

/// 「模块弱项」的最小样本量（开发文档 §11.1）：已作答不足 10 道的模块只标“数据较少”，
/// 不参与弱项评选，避免“3 题错 1 题”被当成薄弱模块。
const int kWeakModuleMinAnswered = 10;

/// 模块正确率（0..1）。没作答过返回 null——不能拿 0 当“正确率 0%”，
/// 那会让一个从没练过的模块被判成最弱。
double? moduleAccuracy(ModuleStat module) {
  if (module.answeredCount <= 0) return null;
  return module.correctCount / module.answeredCount;
}

/// 该模块的样本量够不够参与弱项评选。
bool isModuleSampleEnough(ModuleStat module) =>
    module.answeredCount >= kWeakModuleMinAnswered;

/// 选出最需要补强的模块（开发文档 §11.1）。
///
/// 已作答不足 [kWeakModuleMinAnswered] 道的模块不参与评选，
/// 避免“3 题错 1 题”被说成薄弱模块；没有合格模块时返回 null。
///
/// 排序先比正确率，正确率相同时比作答量：
/// 早先只比正确率，两个模块都是 100% 时会返回排序靠前的那个，
/// 于是“答了 200 道全对”和“答了 10 道全对”被同等对待，
/// 甚至刚做满 10 道的模块会被判成“当前最需要补强”。
ModuleStat? weakestModule(List<ModuleStat> modules) {
  final eligible =
      modules.where(isModuleSampleEnough).toList()
        ..sort((a, b) {
          final aRate = moduleAccuracy(a)!;
          final bRate = moduleAccuracy(b)!;
          final byRate = aRate.compareTo(bRate);
          if (byRate != 0) return byRate;
          // 正确率相同：作答越多说明样本越可靠，优先当作弱项。
          return b.answeredCount.compareTo(a.answeredCount);
        });
  return eligible.isEmpty ? null : eligible.first;
}

/// 首页「按模块刷题」区块的排列顺序：**样本够的弱项排最前**，
/// 其次是有数据但样本不足的，最后是从没练过的。
///
/// 为什么不干脆按题量或字典序：这个区块的存在意义就是“补弱项”，
/// 排第一的必须是用户真正该练的那个模块；而从没练过的模块不能冒充弱项
/// （没数据 ≠ 差），否则第一次打开就指着一个陌生模块说“你最弱”。
int compareModulesForPractice(
  String a,
  String b,
  Map<String, ModuleStat> stats,
  Map<String, int> counts,
) {
  int group(String name) {
    final stat = stats[name];
    if (stat == null || stat.answeredCount <= 0) return 2;
    return isModuleSampleEnough(stat) ? 0 : 1;
  }

  final byGroup = group(a).compareTo(group(b));
  if (byGroup != 0) return byGroup;

  final aStat = stats[a];
  final bStat = stats[b];
  final aRate = aStat == null ? null : moduleAccuracy(aStat);
  final bRate = bStat == null ? null : moduleAccuracy(bStat);
  if (aRate != null && bRate != null) {
    final byRate = aRate.compareTo(bRate);
    if (byRate != 0) return byRate;
  }
  // 同组内再按题量降序（题多的模块通常更值得练），最后按名称稳定排序。
  final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
  return byCount != 0 ? byCount : a.compareTo(b);
}
