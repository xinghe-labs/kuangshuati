import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/session_answer_extensions.dart';
import '../../domain/models.dart' as domain;
import '../../shared/widgets/app_widgets.dart';
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
    final repository = ref.read(contentRepositoryProvider);
    final details = [
      for (final row in _rows)
        if (repository.findQuestion(row.questionId) case final question?)
          (
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
    final score = details.isEmpty ? 0.0 : correct / details.length;
    final visible = _wrongOnly
        ? details.where((item) => item.answer?.isCorrect != true).toList()
        : details;

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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        height: 0.95,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 5),
                      child: Text(
                        '% 得分率',
                        style: TextStyle(
                          color: Color(0xFFD1D1CA),
                          fontSize: 12,
                        ),
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
                        value: '${details.length}',
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
          if (visible.isEmpty)
            const AppEmptyState(title: '没有错题', message: '这次练习全部答对。')
          else
            for (final item in visible) ...[
              _ResultQuestion(
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
      if (!mounted) return;
      setState(() {
        _session = session;
        _rows = rows;
        _answers = {for (final answer in answers) answer.questionId: answer};
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
    final repository = ref.read(contentRepositoryProvider);
    final questions = [
      for (final row in _rows) ?repository.findQuestion(row.questionId),
    ];
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
          style: const TextStyle(color: Color(0xFFBDBDB7), fontSize: 10),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
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
    required this.question,
    required this.answer,
    required this.module,
  });

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
            '${question.questionNo}',
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
          question.stem,
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
              child: Text(question.material!),
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
            child: Text(
              question.solution,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
