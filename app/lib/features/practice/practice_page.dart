import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/session_answer_extensions.dart';
import '../../domain/models.dart' as domain;
import '../../shared/widgets/rich_content.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage>
    with WidgetsBindingObserver {
  final Map<String, db.SessionAnswer> _answers = {};
  final Map<String, Set<String>> _selected = {};
  final Map<String, int> _questionBaseDurations = {};
  final Map<String, domain.QuestionContent> _questions = {};
  final Set<String> _uncertain = {};
  final ScrollController _scrollController = ScrollController();

  db.PracticeSession? _session;
  List<db.SessionQuestion> _rows = const [];
  Timer? _ticker;
  DateTime _runStartedAt = DateTime.now();
  DateTime _questionStartedAt = DateTime.now();
  int _index = 0;
  int _baseDurationMs = 0;
  bool _favorite = false;
  bool _loading = true;
  bool _finishing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null || _rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('无法打开这次练习：${_error ?? '题目为空'}'),
          ),
        ),
      );
    }
    final session = _session!;
    final question = _currentQuestion;
    if (question == null) {
      return const Scaffold(body: Center(child: Text('题目不存在')));
    }
    final answer = _answers[question.id];
    final showResult =
        session.revealMode == domain.RevealMode.immediate.value &&
        answer?.submitted == true;
    // 多选题从正确答案个数推导：正确答案多于一项即为多选，
    // 界面显示“多选”并允许勾选多个选项。
    final isMultiSelect = question.correctAnswers.length > 1;
    final deadline = session.deadlineAt;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        await _saveProgress();
        if (mounted) router.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final router = GoRouter.of(context);
              await _saveProgress();
              if (mounted) router.pop();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: '答题卡',
              onPressed: _showAnswerSheet,
              icon: const Icon(Icons.grid_view_outlined),
            ),
            TextButton(
              onPressed: _finishing ? null : _confirmFinish,
              child: const Text('交卷'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_index + 1) / _rows.length,
              minHeight: 3,
              color: AppColors.ink,
              backgroundColor: AppColors.softFill,
            ),
          ),
        ),
        body: CallbackShortcuts(
          bindings: {
            // 桌面端/Web 键盘作答：数字选选项，回车提交/下一题，方向键翻题。
            for (var i = 0; i < question.options.length && i < 4; i++)
              SingleActivator(
                [
                  LogicalKeyboardKey.digit1,
                  LogicalKeyboardKey.digit2,
                  LogicalKeyboardKey.digit3,
                  LogicalKeyboardKey.digit4,
                ][i],
              ): () =>
                  _selectOption(question.options.keys.elementAt(i)),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                _handlePrimary(session, question, answer),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                _handlePrimary(session, question, answer),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _goTo(_index - 1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _goTo(_index + 1),
          },
          child: Focus(
            autofocus: true,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                // 题号/模块/多选标签/剩余时间/计时器一行放不下时，
                // 原来的多个 Flexible + Spacer 会把“第 2 / 116 题”压成省略号，
                // 大字号下用户直接看不到总题数。改用 Wrap 让它自动换行。
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      '第 ${_index + 1} / ${_rows.length} 题',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    AppTag(label: question.module),
                    if (isMultiSelect) const AppTag(label: '多选'),
                    // 模考剩余时间：到点自动交卷，用户需要能看到还剩多久。
                    if (deadline != null)
                      Text(
                        '剩余 ${_formatRemaining(deadline)}',
                        style: TextStyle(
                          color: _remainingMs(deadline) < 5 * 60 * 1000
                              ? AppColors.negative
                              : AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (ref.watch(showTimerProvider).value ?? true)
                      Text(
                        _formatDuration(_elapsedSessionMs),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (question.material != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softFill,
                      border: Border(
                        left: BorderSide(color: AppColors.ink, width: 3),
                      ),
                    ),
                    child: RichContent(
                      question.material!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                RichContent(
                  question.stem,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                for (final entry in question.options.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _OptionTile(
                      letter: entry.key,
                      text: entry.value,
                      selected:
                          _selected[question.id]?.contains(entry.key) ?? false,
                      showResult: showResult,
                      correct: question.correctAnswers.contains(entry.key),
                      onTap: () => _selectOption(entry.key),
                    ),
                  ),
                const SizedBox(height: 8),
                // 小屏大字号下四个操作放不下一行时自动换行，避免 RenderFlex 溢出。
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    TextButton.icon(
                      onPressed: () => _toggleUncertain(question.id),
                      icon: Icon(
                        _uncertain.contains(question.id)
                            ? Icons.help
                            : Icons.help_outline,
                        size: 18,
                      ),
                      label: Text(
                        _uncertain.contains(question.id) ? '已标记不确定' : '标记不确定',
                      ),
                    ),
                    // 跳过：不会做的题可以先翻过去，不强迫硬选一个；
                    // 跳过的题保持未作答，不算错。
                    TextButton.icon(
                      onPressed: _index < _rows.length - 1
                          ? () => _goTo(_index + 1)
                          : null,
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('跳过'),
                    ),
                    IconButton(
                      tooltip: _favorite ? '取消收藏' : '收藏本题',
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _favorite ? Icons.bookmark : Icons.bookmark_outline,
                        size: 21,
                      ),
                    ),
                    IconButton(
                      tooltip: '写笔记',
                      onPressed: _editNote,
                      icon: const Icon(Icons.edit_note, size: 22),
                    ),
                  ],
                ),
                if (showResult) ...[
                  const SizedBox(height: 14),
                  _AnswerPanel(
                    correct: answer?.isCorrect == true,
                    correctAnswers: question.correctAnswers,
                    solution: question.solution,
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: _BottomBar(
          canGoPrevious: _index > 0,
          primaryLabel: _primaryLabel(session, answer),
          nextIcon: _primaryIsNext(session, answer),
          onPrevious: () => _goTo(_index - 1),
          onPrimary: () => _handlePrimary(session, question, answer),
        ),
      ),
    );
  }

  domain.QuestionContent? get _currentQuestion {
    if (_index < 0 || _index >= _rows.length) return null;
    return _questions[_rows[_index].questionId];
  }

  int get _elapsedSessionMs =>
      _baseDurationMs + DateTime.now().difference(_runStartedAt).inMilliseconds;

  int get _currentQuestionDurationMs {
    final question = _currentQuestion;
    if (question == null) return 0;
    final base =
        _questionBaseDurations[question.id] ??
        _answers[question.id]?.durationMs ??
        0;
    return base + DateTime.now().difference(_questionStartedAt).inMilliseconds;
  }

  Future<void> _load() async {
    try {
      final database = ref.read(databaseProvider);
      final session = await database.sessionById(widget.sessionId);
      if (session == null) throw StateError('练习记录不存在');
      if (session.status != domain.SessionStatus.active.value) {
        if (mounted) {
          context.pushReplacement('/result/${widget.sessionId}');
        }
        return;
      }
      final rows = await database.sessionQuestionRows(widget.sessionId);
      final answers = await database.answersForSession(widget.sessionId);
      final questions = await ref
          .read(contentRepositoryProvider)
          .questionsByIds(rows.map((row) => row.questionId));
      for (final question in questions) {
        _questions[question.id] = question;
      }
      for (final answer in answers) {
        _answers[answer.questionId] = answer;
        _selected[answer.questionId] = answer.selected;
        _questionBaseDurations[answer.questionId] = answer.durationMs;
        if (answer.uncertain) _uncertain.add(answer.questionId);
      }
      final index = session.currentIndex.clamp(0, rows.length - 1);
      final firstQuestionId = rows.isEmpty ? null : rows[index].questionId;
      final favorite = firstQuestionId == null
          ? false
          : await database.isFavorite(firstQuestionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _rows = rows;
        _index = index;
        _baseDurationMs = session.durationMs;
        _runStartedAt = DateTime.now();
        _questionStartedAt = DateTime.now();
        _favorite = favorite;
        _loading = false;
      });
      // 已经超时的会话重开：先问用户，不再静默自动交卷。
      if (_deadlinePassed) {
        if (!mounted) return;
        final finishNow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('本次练习已超过时限'),
            content: const Text('时间已到，无法继续作答。可以现在交卷查看结果。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('返回'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('立即交卷'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (finishNow == true) {
          await _finalize(automatic: true);
        } else {
          context.pop();
        }
        return;
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_deadlinePassed) {
          _finalize(automatic: true);
        } else {
          setState(() {});
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool get _deadlinePassed {
    final deadline = _session?.deadlineAt;
    return deadline != null &&
        DateTime.now().millisecondsSinceEpoch >= deadline;
  }

  Future<void> _selectOption(String letter) async {
    final question = _currentQuestion;
    final session = _session;
    if (question == null || session == null) return;
    final existing = _answers[question.id];
    if (session.revealMode == domain.RevealMode.immediate.value &&
        existing?.submitted == true) {
      return;
    }
    // 多选题（正确答案多于一项）按勾选/取消切换；单选题维持点选即替换。
    final isMultiSelect = question.correctAnswers.length > 1;
    final current = Set<String>.of(_selected[question.id] ?? const <String>{});
    if (isMultiSelect) {
      if (!current.add(letter)) current.remove(letter);
    } else {
      current
        ..clear()
        ..add(letter);
    }
    setState(() {
      _selected[question.id] = current;
    });
    await _saveCurrent(submitted: false, isCorrect: null);
  }

  Future<void> _toggleUncertain(String questionId) async {
    setState(() {
      if (!_uncertain.add(questionId)) _uncertain.remove(questionId);
    });
    final answer = _answers[questionId];
    await _saveCurrent(
      submitted: answer?.submitted ?? false,
      isCorrect: answer?.isCorrect,
    );
  }

  Future<void> _handlePrimary(
    db.PracticeSession session,
    domain.QuestionContent question,
    db.SessionAnswer? answer,
  ) async {
    final submitted = answer?.submitted == true;
    if (submitted ||
        session.revealMode == domain.RevealMode.afterSubmit.value) {
      if (_index < _rows.length - 1) {
        await _goTo(_index + 1);
      } else {
        await _confirmFinish();
      }
      return;
    }
    final selected = _selected[question.id] ?? {};
    if (selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择答案')));
      return;
    }
    await _saveCurrent(
      submitted: true,
      isCorrect: question.isCorrect(selected),
    );
    if (mounted) setState(() {});
  }

  String _primaryLabel(db.PracticeSession session, db.SessionAnswer? answer) {
    if (session.revealMode == domain.RevealMode.afterSubmit.value) {
      return _index == _rows.length - 1 ? '检查并交卷' : '下一题';
    }
    if (answer?.submitted == true) {
      return _index == _rows.length - 1 ? '完成练习' : '下一题';
    }
    return '提交答案';
  }

  bool _primaryIsNext(db.PracticeSession session, db.SessionAnswer? answer) {
    return session.revealMode == domain.RevealMode.afterSubmit.value ||
        answer?.submitted == true;
  }

  Future<void> _saveCurrent({
    required bool submitted,
    required bool? isCorrect,
  }) async {
    final question = _currentQuestion;
    if (question == null) return;
    final duration = _currentQuestionDurationMs;
    final answer = db.SessionAnswer(
      sessionId: widget.sessionId,
      questionId: question.id,
      selectedJson: '',
      submitted: submitted,
      isCorrect: isCorrect,
      uncertain: _uncertain.contains(question.id),
      durationMs: duration,
      answeredAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref
        .read(databaseProvider)
        .saveAnswer(
          sessionId: widget.sessionId,
          questionId: question.id,
          selected: _selected[question.id] ?? {},
          submitted: submitted,
          isCorrect: isCorrect,
          durationMs: duration,
          uncertain: _uncertain.contains(question.id),
        );
    _answers[question.id] = answer;
    _questionBaseDurations[question.id] = duration;
    _questionStartedAt = DateTime.now();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _rows.length || index == _index) return;
    final current = _answers[_currentQuestion?.id];
    await _saveCurrent(
      submitted: current?.submitted ?? false,
      isCorrect: current?.isCorrect,
    );
    final totalDuration = _elapsedSessionMs;
    if (!mounted) return;
    setState(() {
      _index = index;
      _questionStartedAt = DateTime.now();
      _baseDurationMs = totalDuration;
      _runStartedAt = DateTime.now();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await ref
        .read(databaseProvider)
        .saveProgress(
          sessionId: widget.sessionId,
          currentIndex: index,
          durationMs: totalDuration,
        );
    final favorite = await ref
        .read(databaseProvider)
        .isFavorite(_rows[index].questionId);
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _saveProgress() async {
    if (_loading || _session == null) return;
    await _saveCurrent(
      submitted: _answers[_currentQuestion?.id]?.submitted ?? false,
      isCorrect: _answers[_currentQuestion?.id]?.isCorrect,
    );
    await ref
        .read(databaseProvider)
        .saveProgress(
          sessionId: widget.sessionId,
          currentIndex: _index,
          durationMs: _elapsedSessionMs,
        );
  }

  Future<void> _confirmFinish() async {
    final unanswered = _rows.where((row) {
      final selected = _selected[row.questionId];
      return selected == null || selected.isEmpty;
    }).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认交卷'),
        content: Text(
          unanswered == 0
              ? '交卷后将生成本次练习结果。'
              : '还有 $unanswered 道题未作答。未作的题计 0 分，不会记入错题本。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续作答'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _finalize();
  }

  Future<void> _finalize({bool automatic = false}) async {
    if (_finishing || _session == null) return;
    setState(() => _finishing = true);
    try {
      await _saveCurrent(
        submitted: _answers[_currentQuestion?.id]?.submitted ?? false,
        isCorrect: _answers[_currentQuestion?.id]?.isCorrect,
      );
      await ref
          .read(databaseProvider)
          .finalizeSession(
            sessionId: widget.sessionId,
            questionLookup: _questions,
          );
      if (!mounted) return;
      if (automatic) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('考试时间已到，答卷已自动提交')));
      }
      context.pushReplacement('/result/${widget.sessionId}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('交卷失败：$error')));
    }
  }

  Future<void> _toggleFavorite() async {
    final question = _currentQuestion;
    if (question == null) return;
    final favorite = await ref
        .read(databaseProvider)
        .toggleFavorite(question.id);
    if (mounted) {
      setState(() => _favorite = favorite);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(favorite ? '已加入收藏' : '已取消收藏')));
    }
  }

  Future<void> _editNote() async {
    final question = _currentQuestion;
    if (question == null) return;
    final database = ref.read(databaseProvider);
    final controller = TextEditingController(
      text: await database.favoriteNote(question.id),
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本题笔记'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(hintText: '记下易错点、解题入口或需要回看的原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存笔记'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await database.setFavoriteNote(question.id, note);
    if (!mounted) return;
    // 写笔记不再强制收藏：笔记和收藏是两回事，
    // 题目页的收藏图标状态保持用户自己的选择。
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('笔记已保存，可在题库页「笔记」里查看')));
  }

  Future<void> _showAnswerSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      // 全屏高度可用（减去顶部留白），129 题的长答题卡需要内部滚动。
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('答题卡', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 5),
                  Text(
                    '已答 ${_selected.values.where((value) => value.isNotEmpty).length} / ${_rows.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                          ),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final questionId = _rows[index].questionId;
                        final answer = _answers[questionId];
                        final selected = _selected[questionId] ?? {};
                        return _AnswerCardCell(
                          index: index,
                          current: index == _index,
                          answered: selected.isNotEmpty,
                          uncertain: _uncertain.contains(questionId),
                          correct: answer?.submitted == true
                              ? answer?.isCorrect
                              : null,
                          onTap: () => Navigator.pop(context, index),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _LegendDot(label: '已答', color: AppColors.ink),
                      const SizedBox(width: 13),
                      _LegendDot(label: '不确定', color: AppColors.warning),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmFinish();
                        },
                        child: const Text('检查并交卷'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) await _goTo(picked);
  }

  String _formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int _remainingMs(int deadlineMs) {
    final remaining = deadlineMs - DateTime.now().millisecondsSinceEpoch;
    return remaining < 0 ? 0 : remaining;
  }

  /// 模考剩余时间：超过一小时按 h:mm:ss，否则 mm:ss。
  String _formatRemaining(int deadlineMs) {
    final totalSeconds = _remainingMs(deadlineMs) ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.showResult,
    required this.correct,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool showResult;
  final bool correct;
  final VoidCallback onTap;

  /// 选项正文是否只是重复了字母（题库里图形/漫画类题的通病）。
  ///
  /// 实测 58890 道题里有 2975 道（约 5%）的 options 就是
  /// `{"A":"A","B":"B",...}`——真正的选项内容全在一张题干图里。
  /// 直接把正文渲染出来，用户看到的是“A A”“B B”这种像界面坏了的重复，
  /// 所以改成提示去看题干图。
  bool get _textRepeatsLetter => optionTextRepeatsLetter(letter, text);

  @override
  Widget build(BuildContext context) {
    final isWrongSelection = showResult && selected && !correct;
    final isCorrect = showResult && correct;
    final background = isCorrect
        ? AppColors.positiveFill
        : isWrongSelection
        ? AppColors.negativeFill
        : selected
        ? AppColors.surface
        : AppColors.surface;
    final border = isCorrect
        ? AppColors.positive
        : isWrongSelection
        ? AppColors.negative
        : selected
        ? AppColors.ink
        : AppColors.line;
    // 选项的可读名：字母 + 正文 + 结果。
    //
    // 选项是「一整块可点区域」，如果不给语义，屏幕阅读器只会读到一个无名的
    // 可点元素，用户既不知道这是哪个选项，也听不到正文和选中状态。
    final repeatsLetter = _textRepeatsLetter;
    final optionText = repeatsLetter ? '见图' : _plainMarkup(text);
    final stateLabel = isCorrect
        ? '，正确答案'
        : isWrongSelection
        ? '，选错'
        : selected
        ? '，已选'
        : '';
    return Semantics(
      button: true,
      selected: selected,
      label: '$letter。$optionText$stateLabel',
      // 子节点（字母圈、富文本、对错图标）已经合并进 label，
      // 否则会被重复朗读一遍。
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: border,
            width: selected || showResult ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected || isCorrect ? border : AppColors.softFill,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: selected || isCorrect
                          ? AppColors.onInk
                          : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: repeatsLetter
                      ? Text(
                          '见题干图片',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : RichContent(
                          text,
                          selectable: false,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                ),
                if (isCorrect)
                  Icon(Icons.check_circle, color: AppColors.positive, size: 19),
                if (isWrongSelection)
                  Icon(Icons.cancel, color: AppColors.negative, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 把选项 markup 转成一句可朗读的纯文本。
  ///
  /// markup 里的图片用 PUA 标记占位（\uE000asset\uE001），直接朗读会念出乱码，
  /// 所以换成「图」字占位，保留“这里有个图”的信息。
  static String _plainMarkup(String markup) {
    final withoutImages = markup.replaceAll(RegExp('[\uE000-\uF8FF]'), '');
    final collapsed = withoutImages.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return '（含图片）';
    return collapsed;
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canGoPrevious,
    required this.primaryLabel,
    required this.nextIcon,
    required this.onPrevious,
    required this.onPrimary,
  });

  final bool canGoPrevious;
  final String primaryLabel;
  final bool nextIcon;
  final VoidCallback onPrevious;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            IconButton.outlined(
              tooltip: '上一题',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onPrimary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(primaryLabel),
                    if (nextIcon) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.arrow_forward, size: 17),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({
    required this.correct,
    required this.correctAnswers,
    required this.solution,
  });

  final bool correct;
  final Set<String> correctAnswers;
  final String solution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: correct ? AppColors.positiveFill : AppColors.negativeFill,
        border: Border(
          left: BorderSide(
            color: correct ? AppColors.positive : AppColors.negative,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? '回答正确' : '回答错误',
            style: TextStyle(
              color: correct ? AppColors.positive : AppColors.negative,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '正确答案：${correctAnswers.join('、')}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 11),
          Text('解析', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          RichContent(solution, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class AppTag extends StatelessWidget {
  const AppTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      color: AppColors.softFill,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AnswerCardCell extends StatelessWidget {
  const _AnswerCardCell({
    required this.index,
    required this.current,
    required this.answered,
    required this.uncertain,
    required this.correct,
    required this.onTap,
  });

  final int index;
  final bool current;
  final bool answered;
  final bool uncertain;
  final bool? correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = correct == true
        ? AppColors.positiveFill
        : correct == false
        ? AppColors.negativeFill
        : uncertain
        ? AppColors.warningFill
        : answered
        ? AppColors.softFill
        : AppColors.surface;
    final border = current
        ? AppColors.ink
        : correct == true
        ? AppColors.positive
        : correct == false
        ? AppColors.negative
        : AppColors.line;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: current ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 10)),
      ],
    );
  }
}

/// 选项正文是否只是重复了字母（题库里图形/漫画类题的通病）。
///
/// 实测 58890 道题里有 2975 道（约 5%）的 options 就是
/// `{"A":"A","B":"B",...}`——真正的选项内容全在一张题干图里。
/// 直接把正文渲染出来，用户看到的是“A A”“B B”这种像界面坏了的重复，
/// 所以选项区改成提示去看题干图。
///
/// 不能复用 `_OptionTile._plainMarkup`：它对空正文返回“（含图片）”，
/// 那本来就已经是提示语了，不该再被当成“只重复字母”。
bool optionTextRepeatsLetter(String letter, String text) {
  final withoutImages = text.replaceAll(RegExp('[-]'), '');
  final normalized = withoutImages.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return true;
  return normalized.toUpperCase() == letter.toUpperCase();
}
