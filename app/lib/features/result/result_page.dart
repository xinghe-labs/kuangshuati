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
  const ResultPage({required this.sessionId, this.timedOut = false, super.key});

  final String sessionId;

  /// 是否为「考试时间到，系统自动交卷」进入的结果页。
  ///
  /// 超时自动交卷时，练习页原本只弹一个 SnackBar 就立刻 pushReplacement，
  /// SnackBar 依附的 Scaffold 随即被销毁，提示实际上一闪而过甚至完全看不到，
  /// 用户会莫名其妙地被扔到结果页。改成把标记带到结果页顶部常驻显示。
  final bool timedOut;

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
    // 题库换版后旧题可能已不存在：总题数按会话记录算，
    // 失效题不计入正确率分母，但必须明确告诉用户。
    final missingCount = _rows.length - details.length;
    // 已答/答对数只看作答记录，不看题目是否还在题库里：
    // 早先两者都从 details 统计，题库一换版，明明答了 120 题的模考
    // 会显示“已答 118”，模考得分率的分母（details.length）也跟着变小，
    // 少几道题就等于凭空多得分。
    final answeredCount = _rows
        .where((row) => _answers[row.questionId]?.selected.isNotEmpty ?? false)
        .length;
    final correctCount = _rows
        .where((row) => _answers[row.questionId]?.isCorrect == true)
        .length;
    // 开发文档 §11.1 / §11.2：练习看“正确率”（分母只算已作答题），
    // 模考看“得分率”（分母是整卷题数，未答按零分）。
    final isMock = session.mode == domain.PracticeMode.mock.name;
    final ratioBase = isMock ? _rows.length : answeredCount;
    final score = ratioBase == 0 ? 0.0 : correctCount / ratioBase;
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
          if (widget.timedOut) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.warningFill,
              child: Row(
                children: [
                  Icon(
                    Icons.timer_off_outlined,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '考试时间已到，答卷已自动提交。未作答的题按 0 分计，不会记入错题本。',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
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
                      child: _ResultMetric(label: '已答', value: '$answeredCount'),
                    ),
                    Expanded(
                      child: _ResultMetric(label: '答对', value: '$correctCount'),
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
                  '本次有 $uncertainCount 道题被标记不确定，'
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
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
          if (visible.isEmpty)
            // 题库换版后旧题全部找不到时 details 是空的，一道题都展示不出来。
            // 这里以前不看这个情况，统一写“没有错题 / 这次练习全部答对”，
            // 用户明明做错了一堆题，却被告诉全对。
            details.isEmpty
                ? const AppEmptyState(
                    title: '题目已随题库更新失效',
                    message: '这次练习的题目在新题库里都找不到了，无法展示逐题回顾。'
                        '上面的正确率仍按你当时的作答计算。',
                  )
                : const AppEmptyState(title: '没有错题', message: '这次练习全部答对。')
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
          style: TextStyle(color: AppColors.onInkMuted, fontSize: 10),
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
          // 展开后要能重新看到完整题干：折叠状态下的 title 被限制成 2 行，
          // 长材料题的题干被截断，用户光看“正确答案：A”和一段解析，
          // 根本回忆不起自己刚才做的是哪道题。
          if (question.stem.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: RichContent(
                question.stem,
                selectable: false,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 选项也要展开出来：用户最想知道的是“我当时为什么选错”，
          // 只给正确答案字母和一段解析，没有选项原文，就只能凭记忆。
          // 这里把每个选项标出“你的选择”和“正确答案”。
          if (question.options.isNotEmpty) ...[
            for (final entry in question.options.entries) ...[
              _ResultOption(
                letter: entry.key,
                text: entry.value,
                chosen: selected.contains(entry.key),
                isCorrect: question.correctAnswers.contains(entry.key),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
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

/// 结果页展开后的单个选项：标出「你的选择」和「正确答案」。
///
/// 用户复盘时最想知道的是「我当时为什么选错」，所以选项原文必须能重新看到，
/// 而不是只给一个正确答案字母。
class _ResultOption extends StatelessWidget {
  const _ResultOption({
    required this.letter,
    required this.text,
    required this.chosen,
    required this.isCorrect,
  });

  final String letter;
  final String text;
  final bool chosen;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    // 和练习页保持一致的判定：正文只是重复字母时，真正的选项内容在题干图里。
    final withoutImages = text.replaceAll(RegExp('[\uE000-\uF8FF]'), '');
    final normalized = withoutImages.replaceAll(RegExp(r'\s+'), ' ').trim();
    final repeatsLetter =
        normalized.isEmpty || normalized.toUpperCase() == letter.toUpperCase();
    final background = isCorrect
        ? AppColors.positiveFill
        : chosen
        ? AppColors.negativeFill
        : AppColors.surface;
    final border = isCorrect
        ? AppColors.positive
        : chosen
        ? AppColors.negative
        : AppColors.line;
    final label = isCorrect
        ? '正确答案'
        : chosen
        ? '你的选择'
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              letter,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: repeatsLetter
                ? Text(
                    '见题干图片',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : RichContent(
                    text,
                    selectable: false,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isCorrect ? AppColors.positive : AppColors.negative,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
