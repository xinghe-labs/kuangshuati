/// 随机模考组卷的纯函数：无 UI、无 IO，方便单测。
///
/// 设计见 docs/random-mock-paper.md：按题库各模块题量占比（或均匀）
/// 分层随机抽题组一套整卷，限时模考，交卷后统一判分。练完即散。
library;

import '../../domain/models.dart';

/// 组卷题量档位。
const List<int> randomMockQuestionChoices = [105, 120, 130];

/// 时长折算：60 秒/题（对齐主流省考 120 分钟 120 题的节奏），
/// 向上取整到 5 分钟。
const int randomMockSecondsPerQuestion = 60;

/// 缺口重抽的最大轮数。随机抽题可能重复返回已抽到的题，
/// 靠重抽补缺口；连续无进展（题库抽空或实现方总是返回同一批）就停。
const int randomMockMaxRounds = 4;

/// 配比方式：真题结构 = 按题库各模块题量占比分配；
/// 均匀分配 = 各模块平均分。
///
/// 题库 module 字段允许自定义（缺省「综合」），所以配比不写死
/// 模块名，两种都由当次查询到的分布决定。
enum RandomMockMix { paperStructure, even }

/// 把目标题量 [total] 按权重分给各模块，最大余数法保证总数
/// 精确等于 [total]。
///
/// - [availableByModule] 是各模块可抽题数，0 题的模块不参与分配；
/// - 真题结构按题量占比加权，均匀分配按模块数平均；
/// - 返回表按「配额从大到小、同数按模块名」排序（Dart Map 保持
///   插入顺序），组卷顺序沿用这个顺序，大块模块排前面，接近真题卷。
/// - 配额可能超过某模块的实际可抽数（目标题量 > 题库总量时必然如此），
///   超出部分由 [nextQuotas] 的缺口再分配处理。
Map<String, int> moduleQuotas({
  required Map<String, int> availableByModule,
  required int total,
  RandomMockMix mix = RandomMockMix.paperStructure,
}) {
  if (total <= 0) return const {};
  final modules = availableByModule.entries
      .where((entry) => entry.value > 0)
      .toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  if (modules.isEmpty) return const {};

  final weights = <double>[
    for (final entry in modules)
      mix == RandomMockMix.even ? 1.0 : entry.value.toDouble(),
  ];
  final weightSum = weights.fold(0.0, (sum, weight) => sum + weight);

  final quotas = <String, int>{};
  final remainders = <MapEntry<String, double>>[];
  var allocated = 0;
  for (var index = 0; index < modules.length; index++) {
    final share = weights[index] / weightSum * total;
    final floor = share.floor();
    quotas[modules[index].key] = floor;
    allocated += floor;
    remainders.add(MapEntry(modules[index].key, share - floor));
  }
  // 余数按小数部分从大到小逐一补 1，凑齐总数；平手按模块名稳定排序。
  remainders.sort((a, b) {
    final byFraction = b.value.compareTo(a.value);
    return byFraction != 0 ? byFraction : a.key.compareTo(b.key);
  });
  var remaining = total - allocated;
  for (final entry in remainders) {
    if (remaining <= 0) break;
    quotas[entry.key] = quotas[entry.key]! + 1;
    remaining -= 1;
  }
  return quotas;
}

/// 某一轮抽题后，把缺口（[target] − 已抽到）按各模块剩余可用量占比
/// 再分配成新一轮配额。返回 null 表示没有任何模块还有余量，凑不齐了。
Map<String, int>? nextQuotas({
  required Map<String, int> quotas,
  required Map<String, int> receivedByModule,
  required Map<String, int> availableByModule,
  required int target,
}) {
  final receivedTotal = receivedByModule.values.fold(0, (a, b) => a + b);
  final shortfallTotal = target - receivedTotal;
  if (shortfallTotal <= 0) return null;
  // 权重 = 剩余可用量；已经抽到的题不再算进可抽余量。
  final weights = <String, int>{};
  for (final entry in quotas.entries) {
    final remaining =
        (availableByModule[entry.key] ?? 0) - (receivedByModule[entry.key] ?? 0);
    if (remaining > 0) weights[entry.key] = remaining;
  }
  if (weights.isEmpty) return null;
  return moduleQuotas(availableByModule: weights, total: shortfallTotal)
      .map(
        (module, quota) => MapEntry(
          module,
          (receivedByModule[module] ?? 0) + quota,
        ),
      );
}

/// 在「每模块最多抽到自身可用量」的约束下，模拟缺口重抽循环，
/// 估算本次实际能组成的题数。纯内存计算，供配置面板在确认前
/// 显示「预计 N 题」；与启动器的抽题循环共用 [randomMockMaxRounds]，
/// 两边口径一致。
int achievableRandomMockCount({
  required Map<String, int> availableByModule,
  required int total,
  required RandomMockMix mix,
}) {
  if (total <= 0) return 0;
  var quotas = moduleQuotas(
    availableByModule: availableByModule,
    total: total,
    mix: mix,
  );
  final received = <String, int>{};
  for (var round = 0; round < randomMockMaxRounds; round++) {
    var progress = false;
    for (final entry in quotas.entries) {
      final got = received[entry.key] ?? 0;
      final need = entry.value - got;
      if (need <= 0) continue;
      final canTake = (availableByModule[entry.key] ?? 0) - got;
      if (canTake <= 0) continue;
      progress = true;
      received[entry.key] = got + (need < canTake ? need : canTake);
    }
    final receivedTotal = received.values.fold(0, (a, b) => a + b);
    if (receivedTotal >= total) return total;
    if (!progress) return receivedTotal;
    final next = nextQuotas(
      quotas: quotas,
      receivedByModule: received,
      availableByModule: availableByModule,
      target: total,
    );
    if (next == null) return receivedTotal;
    quotas = next;
  }
  return received.values.fold(0, (a, b) => a + b);
}

/// 把逐模块抽到的题目合并成整卷顺序：模块按 [moduleOrder]（首次
/// 配额表的顺序，大块在前），模块内保持抽题返回顺序——材料组在
/// 抽题结果里本来就整体连续，合并后依然连续。
List<QuestionContent> assembleRandomMockPaper({
  required List<String> moduleOrder,
  required Map<String, List<QuestionContent>> receivedByModule,
}) {
  final paper = <QuestionContent>[];
  for (final module in moduleOrder) {
    paper.addAll(receivedByModule[module] ?? const <QuestionContent>[]);
  }
  return paper;
}

/// 题量 → 整卷时长（秒）：60 秒/题，向上取整到 5 分钟。
int randomMockDurationSeconds(int questionCount) {
  if (questionCount <= 0) return 0;
  const step = 300;
  return (questionCount * randomMockSecondsPerQuestion + step - 1) ~/ step *
      step;
}
