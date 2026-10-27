import 'dart:math';

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
  final id = 'session-${DateTime.now().microsecondsSinceEpoch}';
  await ref
      .read(databaseProvider)
      .createSession(
        id: id,
        mode: mode,
        title: title,
        questions: questions,
        revealMode: revealMode,
        paperId: paperId,
        requestedCount: requestedCount,
        timeLimitSeconds: timeLimitSeconds,
      );
  if (context.mounted) context.push('/practice/$id');
}

List<QuestionContent> questionsFromIds(WidgetRef ref, Iterable<String> ids) {
  final repository = ref.read(contentRepositoryProvider);
  return [for (final id in ids) ?repository.findQuestion(id)];
}

List<QuestionContent> randomQuestions(WidgetRef ref, int count) {
  final all = [...ref.read(contentRepositoryProvider).allQuestions];
  all.shuffle(Random.secure());
  return all.take(count).toList();
}
