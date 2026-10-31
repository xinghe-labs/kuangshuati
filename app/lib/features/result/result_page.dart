import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/session_answer_extensions.dart';
import '../../domain/models.dart' as domain;
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/rich_content.dart';
import '../practice/practice_launcher.dart';

class ResultPage extends ConsumerStatefulWidget {
  const ResultPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  db.PracticeSession? _session;
  List<db.SessionQuestion> _rows = const [];
  Map<String, db.SessionAnswer> _answers = const {};
  Map<String, domain.QuestionContent> _questions = const {};
  bool _loading = true;
  bool _wrongOnly = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习结果')),
        body: Center(child: Text('读取结果失败：${_error ?? '记录不存在'}')),
      );
    }
    final session = _session!;
    final details = [
      for (final (index, row) in _rows.indexed)
        if (_questions[row.questionId] case final question?)
          (
            // 复习列表里的“第 N 题”是本场练习的位置，不是原卷题号：
            // 原卷题号按模块重新计数，同卷里有多个“第 1 题”。
            number: index + 1,
            question: question,
            answer: _answers[row.questionId],
            module: question.module,
          ),
    ];
    final answered = details
        .where((item) => (item.answer?.selected.isNotEmpty ?? false))
        .length;
    final correct = details
        .where((item) => item.answer?.isCorrect == true)
        .length;
    // 题库换版后旧题可能已不存在：总题数按会话记录算，
    // 失效题不计入正确率分母，但必须明确告诉用户。
    final missingCount = _rows.length - details.length;
    // 开发文档 §11.1 / §11.2：练习看“正确率”（分母只算已作答题），
    // 模考看“得分率”（分母是整卷题数，未答按零分）。
    final isMock = session.mode == domain.PracticeMode.mock.name;
    final ratioBase = isMock ? details.length : answered;
    final score = ratioBase == 0 ? 0.0 : correct / ratioBase;
    final visible = _wrongOnly
        ? details.where((item) => item.answer?.isCorrect != true).toList()
        : details;
    final uncertainCount = details
        .where((item) => item.answer?.uncertain == true)
        .length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('练习结果'),
        actions: [
          IconButton(
            tooltip: '返回首页',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    color: Color(0xFFBDBDB7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(score * 100).round()}',
                      style: TextStyle(
                        color: AppColors.onInk,
                        fontSize: 52,
                        height: 0.95,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isMock ? '% 得分率' : '% 正确率',
                      style: TextStyle(
                        color: AppColors.onInkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ResultMetric(
                        label: '总题数',
                        value: '${_rows.length}',
                      ),
                    ),
                    Expanded(
                      child: _ResultMetric(label: '已答', value: '$answered'),
                    ),
                    Expanded(
                      child: _ResultMetric(label: '答对', value: '$correct'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('再练一次'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('返回首页'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: SectionHeading(title: '逐题回顾')),
              FilterChip(
                label: Text(_wrongOnly ? '仅看错题' : '全部题目'),
                selected: _wrongOnly,
                onSelected: (value) => setState(() => _wrongOnly = value),
              ),
            ],
          ),
          if (uncertainCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.softFill,
                child: Text(
                  '本有 $uncertainCount 道题被标记不确定，'
                  '已加入明天的复习计划。',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
          if (missingCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.softFill,
                child: Text(
                  '有 $missingCount 道题已随题库更新失效，无法展示，'
                  '也不计入正确率。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (visible.isEmpty)
            const AppEmptyState(title: '没有错题', message: '这次练习全部答对。')
          else
            for (final item in visible) ...[
              _ResultQuestion(
                number: item.number,
                question: item.question,
                answer: item.answer,
                module: item.module,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    try {
      final database = ref.read(databaseProvider);
      final session = await database.sessionById(widget.sessionId);
      if (session == null) throw StateError('练习记录不存在');
      final rows = await database.sessionQuestionRows(widget.sessionId);
      final answers = await database.answersForSession(widget.sessionId);
      final questions = await ref
          .read(contentRepositoryProvider)
          .questionsByIds(rows.map((row) => row.questionId));
      if (!mounted) return;
      setState(() {
        _session = session;
        _rows = rows;
        _answers = {for (final answer in answers) answer.questionId: answer};
        _questions = {for (final question in questions) question.id: question};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _restart() async {
    final session = _session;
    if (session == null) return;
    final questions = [for (final row in _rows) ?_questions[row.questionId]];
    final mode = domain.PracticeMode.values.firstWhere(
      (value) => value.name == session.mode,
      orElse: () => domain.PracticeMode.custom,
    );
    await launchPractice(
      context,
      ref,
      mode: mode,
      title: session.title,
      questions: questions,
      revealMode: session.revealMode == domain.RevealMode.afterSubmit.value
          ? domain.RevealMode.afterSubmit
          : domain.RevealMode.immediate,
      paperId: session.paperId,
      timeLimitSeconds: session.timeLimitSeconds,
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onInkMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onInk,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ResultQuestion extends StatelessWidget {
  const _ResultQuestion({
    required this.number,
    required this.question,
    required this.answer,
    required this.module,
  });

  final int number;
  final domain.QuestionContent question;
  final db.SessionAnswer? answer;
  final String module;

  @override
  Widget build(BuildContext context) {
    final selected = answer?.selected ?? {};
    final blank = selected.isEmpty;
    final correct = answer?.isCorrect == true;
    return Container(
      color: AppColors.surface,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          color: blank
              ? AppColors.softFill
              : correct
              ? AppColors.positiveFill
              : AppColors.negativeFill,
          child: Text(
            '$number',
            style: TextStyle(
              color: blank
                  ? AppColors.muted
                  : correct
                  ? AppColors.positive
                  : AppColors.negative,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          question.plainStem,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            blank
                ? '未作答 · $module'
                : '${correct ? '正确' : '错误'} · 你的答案 ${selected.join('、')} · $module',
            style: TextStyle(
              color: blank
                  ? AppColors.muted
                  : correct
                  ? AppColors.positive
                  : AppColors.negative,
              fontSize: 11,
            ),
          ),
        ),
        children: [
          if (question.material != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.softFill,
              child: RichContent(question.material!),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '正确答案：${question.correctAnswers.join('、')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: RichContent(
              question.solution,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
