import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';

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
  final id = 'session-${DateTime.now().microsecondsSinceEpoch}';
  await ref
      .read(databaseProvider)
      .createSession(
        id: id,
        mode: mode,
        title: title,
        questions: questions,
        revealMode: effectiveReveal,
        paperId: paperId,
        requestedCount: requestedCount,
        timeLimitSeconds: timeLimitSeconds,
      );
  if (context.mounted) context.push('/practice/$id');
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
