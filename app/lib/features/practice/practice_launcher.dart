import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';
import 'mock_paper.dart';

/// 开始一组新练习。
///
/// 如果有「进行中」的旧练习，必须先确认（docs/requirements-discovery.md Q6）：
/// 早先 createSession 会把旧的 active 会话直接标记成 abandoned，用户点一下
/// 「随机 20 题」，已经做了十几题的旧练习就静默作废，再也找不回来。
/// 现在默认动作是「返回当前练习」，只有明确选择「结束旧练习」才会替换。
Future<void> launchPractice(
  BuildContext context,
  WidgetRef ref, {
  required PracticeMode mode,
  required String title,
  required List<QuestionContent> questions,
  RevealMode revealMode = RevealMode.immediate,
  String? paperId,
  int? requestedCount,
  int? timeLimitSeconds,
  int? questionLimitSeconds,
}) async {
  if (questions.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前没有可练习的题目')));
    return;
  }
  // 设置里的“答完立即出答案”必须真的生效：关闭后练习类模式改为
  // 交卷后统一判分；模考本身永远是 afterSubmit，不受影响。
  var effectiveReveal = revealMode;
  if (revealMode == RevealMode.immediate) {
    final revealNow = await ref
        .read(databaseProvider)
        .getSetting('revealImmediately', 'true');
    if (revealNow == 'false') effectiveReveal = RevealMode.afterSubmit;
  }
  final database = ref.read(databaseProvider);

  // 有未完成的练习时先确认，不能静默把它作废。
  final active = await database.latestActiveSession();
  if (!context.mounted) return;
  if (active != null) {
    final submitted = await database.submittedCountFor(active.id);
    if (!context.mounted) return;
    final decision = await showDialog<_ReplaceDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('还有一组练习没做完'),
        content: Text(
          '「${active.title}」已答 $submitted / ${active.actualCount} 题。\n'
          '开始新练习会把这一组结束掉，没交卷的进度和成绩都不会保留。',
        ),
        actions: [
          // 默认动作：回到当前练习。
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_ReplaceDecision.resume),
            child: const Text('返回当前练习'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_ReplaceDecision.replace),
            child: const Text('结束旧练习并开始'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (decision != _ReplaceDecision.replace) {
      if (decision == _ReplaceDecision.resume) {
        // 直接带用户回到那组练习，而不是把用户丢在原地。
        context.push('/practice/${active.id}');
      }
      return;
    }
  }

  final id = 'session-${DateTime.now().microsecondsSinceEpoch}';
  try {
    await database.createSession(
      id: id,
      mode: mode,
      title: title,
      questions: questions,
      revealMode: effectiveReveal,
      paperId: paperId,
      requestedCount: requestedCount,
      timeLimitSeconds: timeLimitSeconds,
      questionLimitSeconds: questionLimitSeconds,
    );
  } on Object catch (error) {
    // 建会话失败（磁盘满、数据库被锁、记录损坏）时以前什么都不做：
    // 用户点了「随机 20 题」或「继续练习」，界面没任何反应，只能反复点。
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法开始练习：$error')),
    );
    return;
  }
  if (context.mounted) context.push('/practice/$id');
}

enum _ReplaceDecision { resume, replace }


/// 把「读题库」失败的异常变成一句用户能看懂的话。
///
/// 首页/统计/题库页在点入口时直接 await 题库读取，题库文件损坏、
/// 磁盘 I/O 出错时异常会直接抛到手势回调里：用户点了一下，屏幕
/// 毫无变化，也没有任何可重试的地方。
String describeContentError(Object error) {
  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('HttpException') ||
      message.contains('HandshakeException')) {
    return '题库读取失败：网络不可用或连接被打断，请检查网络后重试。';
  }
  return '题库读取失败，请稍后重试（$message）';
}

/// 题库读取失败时统一提示，避免各页面各写一套。
void showContentError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(describeContentError(error))));
}

Future<List<QuestionContent>> questionsFromIds(
  WidgetRef ref,
  Iterable<String> ids,
) {
  return Future.value(ref.read(contentRepositoryProvider).questionsByIds(ids));
}

Future<List<QuestionContent>> randomQuestions(
  WidgetRef ref,
  int count, {
  String? module,
}) {
  return Future.value(
    ref.read(contentRepositoryProvider).randomQuestions(count, module: module),
  );
}

/// 随机模考：按题库各模块题量占比（或均匀）分层随机组一套整卷，
/// 限时模考，交卷后统一判分。练完即散，不保存卷子
/// （docs/random-mock-paper.md）。
///
/// 缺口处理：某模块抽不够配额时按其余模块剩余可用量再分配重抽，
/// 最多 [randomMockMaxRounds] 轮；整体凑不齐目标题量时提示真实题量
/// 照常开考。模块分布拿不到时退化为纯随机整卷抽题。
Future<void> launchRandomMock(
  BuildContext context,
  WidgetRef ref, {
  required int targetCount,
  required RandomMockMix mix,
}) async {
  final repository = ref.read(contentRepositoryProvider);
  try {
    final available = Map<String, int>.from(await repository.moduleCounts());
    List<QuestionContent> questions;
    if (available.isEmpty) {
      // 分布拿不到（旧题库实现/异常数据）：纯随机抽一套，功能仍可用。
      questions = await randomQuestions(ref, targetCount);
    } else {
      var quotas = moduleQuotas(
        availableByModule: available,
        total: targetCount,
        mix: mix,
      );
      final moduleOrder = quotas.keys.toList();
      final received = <String, List<QuestionContent>>{};
      final seenIds = <String>{};
      for (var round = 0; round < randomMockMaxRounds; round++) {
        var progress = false;
        for (final entry in quotas.entries) {
          final module = entry.key;
          final need = entry.value - (received[module]?.length ?? 0);
          if (need <= 0) continue;
          final drawn = await randomQuestions(ref, need, module: module);
          // 随机抽题可能重复返回上一轮抽过的题（演示题库还是固定种子），
          // 去重后才有真实进展。
          final fresh = drawn.where((item) => seenIds.add(item.id)).toList();
          if (fresh.isEmpty) continue;
          progress = true;
          (received[module] ??= []).addAll(fresh);
        }
        final receivedByCount = {
          for (final entry in received.entries) entry.key: entry.value.length,
        };
        final receivedTotal = receivedByCount.values.fold(0, (a, b) => a + b);
        if (receivedTotal >= targetCount || !progress) break;
        final next = nextQuotas(
          quotas: quotas,
          receivedByModule: receivedByCount,
          availableByModule: available,
          target: targetCount,
        );
        if (next == null) break;
        quotas = next;
      }
      questions = assembleRandomMockPaper(
        moduleOrder: moduleOrder,
        receivedByModule: received,
      );
    }
    if (!context.mounted) return;
    if (questions.length < targetCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '题库题量不足，本次共组成 ${questions.length} 题（目标 $targetCount 题）',
          ),
        ),
      );
    }
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.mock,
      title: '随机模考 · ${questions.length} 题',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
      timeLimitSeconds: randomMockDurationSeconds(questions.length),
      requestedCount: targetCount,
    );
  } on Object catch (error) {
    if (context.mounted) showContentError(context, error);
  }
}
