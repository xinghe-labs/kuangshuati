import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';

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
