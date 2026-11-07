import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/keep_screen_on.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/session_answer_extensions.dart';
import '../../domain/models.dart' as domain;
import '../../shared/widgets/rich_content.dart';
import 'time_budget.dart';

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
  // 切到后台的那一刻。应用回到前台时把这段时长从计时里扣掉：
  // 用户回微信、接电话的时间不应该算成“做题用时”，否则结果页每题
  // 用时、统计页模块总时长全都会虚高。
  DateTime? _pausedAt;
  // 暂停瞬间的已用时长（本组 / 当前题），回前台时作为新的计时基准。
  int _frozenSessionMs = 0;
  int _frozenQuestionMs = 0;
  String? _frozenQuestionId;
  bool _favorite = false;
  bool _loading = true;
  bool _finishing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 做题期间屏幕常亮：长材料题很容易超过系统息屏时间（默认 30 秒），
    // 屏幕黑掉后要重新解锁，作答节奏被直接打断。
    KeepScreenOn.enable();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 一定要关掉，否则用户退出做题后整台手机都不息屏、白耗电。
    KeepScreenOn.disable();
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_pausedAt == null) {
        // 冻结计时：把当前已用时长落成基准值，并把锚点推到未来，
        // 这样后台期间两个 getter 算出的增量恒为 0。不能只记时间点、
        // 回前台再平移锚点：后台里 _saveCurrent 会把锚点重置到后台
        // 窗口内，平移后就会超出当前时刻，暂停就失效了。
        _pausedAt = DateTime.now();
        _frozenSessionMs = _elapsedSessionMs;
        _frozenQuestionMs = _currentQuestionDurationMs;
        _frozenQuestionId = _currentQuestion?.id;
      }
      _saveProgress();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_pausedAt == null) return;
      _pausedAt = null;
      // 从冻结值重新起算，后台那段时间整个丢掉。
      final now = DateTime.now();
      _baseDurationMs = _frozenSessionMs;
      _runStartedAt = now;
      final question = _currentQuestion;
      if (question != null && question.id == _frozenQuestionId) {
        _questionBaseDurations[question.id] = _frozenQuestionMs;
        _questionStartedAt = now;
      } else {
        _questionStartedAt = now;
      }
      _frozenSessionMs = 0;
      _frozenQuestionMs = 0;
      _frozenQuestionId = null;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null || _rows.isEmpty) {
      // 以前这里只是一个居中的一行字：没有 AppBar、没有返回按钮，
      // 而页面外层 PopScope 是 canPop: false。用户点开一组练习后如果
      // 读取失败（题库损坏、记录被清空），就被关在死页里，只能杀进程。
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          _goBackHome();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '返回',
              onPressed: _goBackHome,
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text('练习'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '无法打开这次练习：${_error ?? '题目为空'}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _goBackHome,
                    child: const Text('返回首页'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final session = _session!;
    final question = _currentQuestion;
    if (question == null) {
      // 题库换版后，进行中的练习里可能有题已经不存在。
      // 这里以前只画一行“题目不存在”，没有 AppBar、没有返回按钮，
      // 而外层 PopScope 又是 canPop: false —— 用户被彻底关在死页面里，
      // 只能杀进程（进度还在，但人已经不敢再用了）。
      // 现在给返回/交卷两个出口，并说明发生了什么。
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _confirmExit();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '返回',
              onPressed: _confirmExit,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: _finishing ? null : _confirmFinish,
                child: const Text('交卷'),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.report_gmailerrorred_outlined,
                    size: 40,
                    color: AppColors.ink,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '这道题已随题库更新失效',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '第 ${_index + 1} / ${_rows.length} 题在新题库里找不到了。'
                    '你可以直接交卷，或者返回题库重新开始一组练习。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _finishing ? null : _confirmFinish,
                    child: const Text('交卷查看结果'),
                  ),
                  TextButton(
                    onPressed: _confirmExit,
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
        await _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _confirmExit,
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
            // 1-4 覆盖不到五个选项的题（行测常识/言语里 5 选项并不罕见），
            // 以前那类题在桌面端完全无法用键盘作答，只能去点鼠标。
            for (var i = 0; i < question.options.length && i < 9; i++)
              SingleActivator(
                [
                  LogicalKeyboardKey.digit1,
                  LogicalKeyboardKey.digit2,
                  LogicalKeyboardKey.digit3,
                  LogicalKeyboardKey.digit4,
                  LogicalKeyboardKey.digit5,
                  LogicalKeyboardKey.digit6,
                  LogicalKeyboardKey.digit7,
                  LogicalKeyboardKey.digit8,
                  LogicalKeyboardKey.digit9,
                ][i],
              ): () =>
                  _selectOption(question.options.keys.elementAt(i)),
            // 数字小键盘上的 1-9 同样应该能选。
            for (var i = 0; i < question.options.length && i < 9; i++)
              SingleActivator(
                [
                  LogicalKeyboardKey.numpad1,
                  LogicalKeyboardKey.numpad2,
                  LogicalKeyboardKey.numpad3,
                  LogicalKeyboardKey.numpad4,
                  LogicalKeyboardKey.numpad5,
                  LogicalKeyboardKey.numpad6,
                  LogicalKeyboardKey.numpad7,
                  LogicalKeyboardKey.numpad8,
                  LogicalKeyboardKey.numpad9,
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
                _timeHintsRow(
                  context,
                  question,
                  deadline == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(deadline),
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

  // 在后台（_pausedAt != null）时直接返回冻结值：后台期间
  // didChangeAppLifecycleState 会调 _saveProgress()，它读的就是这两个
  // getter；如果这里还算实时增量，后台那段时间照样会被写进数据库。
  int get _elapsedSessionMs => _pausedAt != null
      ? _frozenSessionMs
      : _baseDurationMs +
            DateTime.now().difference(_runStartedAt).inMilliseconds;

  int get _currentQuestionDurationMs {
    final question = _currentQuestion;
    if (question == null) return 0;
    if (_pausedAt != null && question.id == _frozenQuestionId) {
      return _frozenQuestionMs;
    }
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
      // 页面内的临时副本，只用于渲染；真正计入统计的是数据库行。
      moduleCounted: false,
      dailyCounted: false,
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
          // 模块名要一起传：数据库靠它实时累计「各模块正确率」，
          // 否则没交卷的那几十题在统计页完全看不到。
          module: question.module,
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
      // 超时自动交卷的提示不能只弹 SnackBar：这里紧接着 pushReplacement，
      // SnackBar 依附的 Scaffold 立刻被销毁，用户根本看不到提示，只会莫名
      // 其妙地被扔到结果页。改成把标记带到结果页顶部常驻显示。
      context.pushReplacement(
        automatic
            ? '/result/${widget.sessionId}?timedOut=1'
            : '/result/${widget.sessionId}',
      );
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
    final original = await database.favoriteNote(question.id);
    final controller = TextEditingController(text: original);
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
    // 清空笔记（包括误触空格）必须明确告诉用户：
    // setFavoriteNote 会把内容 trim 后写入，只输一个空格等于把原笔记
    // 删了；如果还提示“笔记已保存”，用户根本不知道自己写的东西没了。
    final clearing = note.trim().isEmpty && original.isNotEmpty;
    await database.setFavoriteNote(question.id, note);
    if (!mounted) return;
    // 写笔记不再强制收藏：笔记和收藏是两回事，
    // 题目页的收藏图标状态保持用户自己的选择。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          clearing ? '笔记已清空' : '笔记已保存，可在题库页「笔记」里查看',
        ),
      ),
    );
  }

  /// 练习页出错时的唯一出口：回首页。
  ///
  /// 外层 PopScope 是 canPop: false，出错页以前只画一行字，
  /// 用户既不能返回也不能后退，只能杀进程。
  void _goBackHome() {
    if (!mounted) return;
    context.go('/home');
  }

  /// 退出练习前的确认。
  ///
  /// 之前点返回键或左上角箭头会直接离开做题页：辛辛苦苦做了几十题，
  /// 误触一下心流就被打断，而且不知道进度到底还在不在。交卷有确认框，
  /// 退出却没有，行为不一致。这里统一补上确认，并明确告诉用户进度已保存。
  Future<void> _confirmExit() async {
    final answered = _selected.values.where((value) => value.isNotEmpty).length;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出练习？'),
        content: Text(
          answered == 0
              ? '还没作答。退出后可以随时回到这里继续。'
              : '已作答 $answered 题，进度会保存，可以随时回来继续。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续做题'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    final router = GoRouter.of(context);
    await _saveProgress();
    if (mounted) router.pop();
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
                  // 图例最多有 4 项，加上「检查并交卷」按钮，在 360 宽的
                  // 小屏上排成一行会溢出。图例单独一行并用 Wrap 兜底换行。
                  //
                  // 图例颜色必须和格子实际用色一致：之前“已答”画的是
                  // AppColors.ink（黑），而格子实际用 softFill（浅灰），
                  // 用户对着图例找颜色根本对不上。练习模式（immediate）下
                  // 格子还会变绿/变红表示对错，图例也必须标出来，否则用户
                  // 不知道红绿是什么意思。
                  Wrap(
                    spacing: 13,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendDot(
                        label: '已答',
                        color: AppColors.softFill,
                        border: AppColors.line,
                      ),
                      _LegendDot(
                        label: '不确定',
                        color: AppColors.warningFill,
                        border: AppColors.warning,
                      ),
                      if (_answers.values.any((item) => item.submitted)) ...[
                        _LegendDot(
                          label: '答对',
                          color: AppColors.positiveFill,
                          border: AppColors.positive,
                        ),
                        _LegendDot(
                          label: '答错',
                          color: AppColors.negativeFill,
                          border: AppColors.negative,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmFinish();
                      },
                      child: const Text('检查并交卷'),
                    ),
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

  // 限时训练的第二行状态条：单题倒计时（设置开启时）+ 模考分模块
  // 时间预算（整卷时长按模块题数分摊）。都只提醒不强制——行测
  // 考生有自己的做题策略，页面负责把「快没时间了」喊出来。
  Widget _timeHintsRow(
    BuildContext context,
    domain.QuestionContent question,
    DateTime? deadline,
  ) {
    final questionTimeLimit = ref.watch(questionTimeLimitProvider).value ?? 0;
    final showQuestionLimit = questionTimeLimit > 0;
    final moduleBudgets = deadline == null
        ? null
        : moduleBudgetsSeconds(
            totalBudgetSeconds: _session?.timeLimitSeconds ?? 0,
            questionCountByModule: _moduleQuestionCounts(),
          );
    final moduleBudget = moduleBudgets?[question.module] ?? 0;
    final showModuleBudget = moduleBudget > 0;
    if (!showQuestionLimit && !showModuleBudget) {
      return const SizedBox.shrink();
    }
    final questionMs = _currentQuestionDurationMs;
    final limit = questionLimitPresentation(
      ((questionTimeLimit * 1000 - questionMs) / 1000).floor(),
      questionTimeLimit,
    );
    final moduleElapsedMs = showModuleBudget
        ? _moduleElapsedMs(question.module, question.id) + questionMs
        : 0;
    final overBudgetSec = moduleElapsedMs ~/ 1000 - moduleBudget;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          if (showModuleBudget)
            Text(
              overBudgetSec >= 0
                  ? '${question.module} 已超 ${formatLimitClock(overBudgetSec)}'
                  : '${question.module} ${formatLimitClock(moduleElapsedMs ~/ 1000)} / ${formatLimitClock(moduleBudget)}',
              style: TextStyle(
                color: overBudgetSec >= 0 ? AppColors.negative : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const Spacer(),
          if (showQuestionLimit)
            Text(
              limit.label,
              style: TextStyle(
                color: limit.over
                    ? AppColors.negative
                    : limit.warn
                        ? AppColors.warning
                        : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  Map<String, int> _moduleQuestionCounts() {
    final counts = <String, int>{};
    for (final row in _rows) {
      final module = _questions[row.questionId]?.module;
      if (module == null) continue;
      counts.update(module, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  // 本模块已花时间：已完成各题的累计用时 + 当前题的实时用时。
  // 当前题不取 _questionBaseDurations（那是上次保存值，不含最近几秒），
  // 而是用 _currentQuestionDurationMs 的实时值，避免双重计入。
  int _moduleElapsedMs(String module, String currentQuestionId) {
    var total = 0;
    for (final row in _rows) {
      if (_questions[row.questionId]?.module != module) continue;
      if (row.questionId == currentQuestionId) continue;
      total += _questionBaseDurations[row.questionId] ?? 0;
    }
    return total;
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
  const _LegendDot({
    required this.label,
    required this.color,
    this.border,
  });

  final String label;
  final Color color;

  /// 填色块外面再描一圈边框，让浅色底（positiveFill/negativeFill 这类
  /// 极淡的底色）在白底上也能看出边界，否则图例看上去像没画东西。
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
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
