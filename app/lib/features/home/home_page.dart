import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';
import '../settings/settings_platform_io.dart'
    if (dart.library.js_interop) '../settings/settings_platform_web.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SettingsPlatform.autoCheckUpdate(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(latestActiveSessionProvider);
    final reviews = ref.watch(reviewItemsProvider);
    final daily = ref.watch(dailyStatsProvider);
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final today = daily.value
        ?.where((item) => item.day == todayKey)
        .firstOrNull;
    final dueCount =
        reviews.value
            ?.where(
              (item) =>
                  !item.mastered &&
                  (item.nextReviewAt == null ||
                      item.nextReviewAt! <= now.millisecondsSinceEpoch),
            )
            .length ??
        0;

    return AppPage(
      children: [
        const PageIntro(
          title: '今天继续把题刷透',
          description: '少做选择，打开就练。进度和答题记录都只保存在本机。',
        ),
        activeSession.when(
          data: (session) => session == null
              ? _StartPanel(
                  onSequence: () => _startSequence(context, ref),
                  onRandom: () => _startRandom(context, ref),
                )
              : _ContinuePanel(session: session),
          loading: () => const _LoadingBlock(label: '正在读取练习进度'),
          error: (error, stack) => _ErrorBlock(error: error),
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: '今日概览'),
        MetricStrip(
          items: [
            MetricItem('已答', '${today?.answeredCount ?? 0}', '题'),
            MetricItem('正确', '${today?.correctCount ?? 0}', '题'),
            MetricItem('待复习', '$dueCount', '题'),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: '直接开始'),
        _ActionGrid(
          children: [
            _ActionTile(
              index: '01',
              title: '顺序练习',
              detail: '从第一题开始，保持稳定节奏',
              icon: Icons.format_list_numbered,
              onTap: () => _startSequence(context, ref),
            ),
            _ActionTile(
              index: '02',
              title: '随机 20 题',
              detail: '一组短练习，适合碎片时间',
              icon: Icons.shuffle,
              onTap: () => _startRandom(context, ref),
            ),
            _ActionTile(
              index: '03',
              title: '到期错题',
              detail: dueCount == 0 ? '暂无到期错题' : '$dueCount 道题等待重做',
              icon: Icons.replay_circle_filled_outlined,
              onTap: () => _startReviews(context, ref),
            ),
            _ActionTile(
              index: '04',
              title: '整卷模考',
              detail: '查看试卷并选择一套开始',
              icon: Icons.timer_outlined,
              onTap: () => context.go('/bank'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: '最近试卷'),
        _RecentPapers(onStartPaper: _startPaper),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _startSequence(BuildContext context, WidgetRef ref) async {
    // 顺序练习要接着往后做，而不是永远从头开始：
    // 早先固定返回题库最前面的 100 题，练完一遍后再点还是那 100 题，
    // 题库共 58890 题却永远只能做到前 100 道。
    final database = ref.read(databaseProvider);
    final repository = ref.read(contentRepositoryProvider);
    final answered = await database.answeredQuestionIds();
    var questions = await repository.sequenceQuestions(
      limit: 100,
      excludeIds: answered,
    );
    var restart = false;
    if (questions.isEmpty) {
      // 题库里能做的都做完了（或题库本来就空），退回从头开始，
      // 但明确告知用户这是重刷，而不是默默又发一批旧题。
      questions = await repository.sequenceQuestions(limit: 100);
      restart = true;
    }
    if (!context.mounted) return;
    if (restart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('题库已全部练过一遍，这次从第一题重新开始')),
      );
    }
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: questions,
      requestedCount: 100,
    );
  }

  Future<void> _startRandom(BuildContext context, WidgetRef ref) async {
    final questions = await randomQuestions(ref, 20);
    if (!context.mounted) return;
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      requestedCount: 20,
    );
  }

  Future<void> _startReviews(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final reviewItems = await ref.read(databaseProvider).allReviewItems();
    final dueIds = reviewItems
        .where(
          (item) =>
              !item.mastered &&
              (item.nextReviewAt == null || item.nextReviewAt! <= now),
        )
        .map((item) => item.questionId);
    if (!context.mounted) return;
    final questions = await questionsFromIds(ref, dueIds);
    if (!context.mounted) return;
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.wrong,
      title: '到期错题复习',
      questions: questions,
    );
  }

  Future<void> _startPaper(
    BuildContext context,
    WidgetRef ref,
    Paper paper, {
    bool mock = false,
  }) async {
    final questions = await ref
        .read(contentRepositoryProvider)
        .questionsForPaper(paper.id);
    if (!context.mounted) return;
    await launchPractice(
      context,
      ref,
      mode: mock ? PracticeMode.mock : PracticeMode.paper,
      title: mock ? '${paper.title} · 模考' : paper.title,
      questions: questions,
      paperId: paper.id,
      revealMode: mock ? RevealMode.afterSubmit : RevealMode.immediate,
      timeLimitSeconds: mock ? paper.durationSeconds : null,
    );
  }
}

class _ContinuePanel extends ConsumerWidget {
  const _ContinuePanel({required this.session});

  final PracticeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = session.currentIndex.clamp(0, session.actualCount - 1) + 1;
    // 「已答」必须单独取：currentIndex 只是当前停留位置。用户只答 1 题、
    // 用答题卡翻到最后一题时，只看位置会显示「第 5 / 5 题」，像练完了。
    final submitted = ref
        .watch(activeSessionAnsweredProvider(session.id))
        .maybeWhen(data: (value) => value, orElse: () => null);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上次练到第 $position / ${session.actualCount} 题',
            style: TextStyle(
              color: AppColors.onInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            submitted == null
                ? '正在读取已答数量…'
                : submitted == 0
                ? '这一组还没有提交答案'
                : '已答 $submitted 题，还剩 '
                      '${(session.actualCount - submitted).clamp(0, session.actualCount)} 题',
            style: TextStyle(color: AppColors.onInkMuted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            session.title,
            style: TextStyle(color: AppColors.onInkMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/practice/${session.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onInk,
              foregroundColor: AppColors.ink,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('继续练习'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 17),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({required this.onSequence, required this.onRandom});

  final VoidCallback onSequence;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有正在进行的练习',
            style: TextStyle(
              color: AppColors.onInk,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '先做一组 20 题，系统会从第一道错题开始安排复习。',
            style: TextStyle(color: AppColors.onInkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRandom,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.onInk,
                    foregroundColor: AppColors.ink,
                  ),
                  child: const Text('随机开始'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSequence,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onInk,
                    side: BorderSide(color: AppColors.muted),
                  ),
                  child: const Text('顺序练习'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        // 卡片高度随系统字号线性放大，避免大字号下标题/描述溢出。
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent:
              (columns == 4 ? 100 : 118) * textScale.clamp(0.8, 2.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.index,
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String index;
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    index,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(icon, size: 19, color: AppColors.ink),
                ],
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPapers extends ConsumerWidget {
  const _RecentPapers({required this.onStartPaper});

  final Future<void> Function(
    BuildContext context,
    WidgetRef ref,
    Paper paper, {
    bool mock,
  })
  onStartPaper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papers = ref.watch(recentPapersProvider);
    return papers.when(
      loading: () => const _LoadingBlock(label: '正在读取最近试卷'),
      error: (error, stack) => _ErrorBlock(error: error),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(title: '题库为空', message: '请先导入离线题库。');
        }
        return HairlineList(
          children: [
            for (final paper in items.take(2))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                title: Text(paper.title),
                subtitle: Text(
                  '${paper.year} · ${paper.region} · ${paper.paperType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.arrow_forward, size: 17),
                onTap: () => onStartPaper(context, ref, paper),
              ),
          ],
        );
      },
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.negativeFill,
      child: Text(
        '读取练习记录失败：$error',
        style: TextStyle(color: AppColors.negative, fontSize: 13),
      ),
    );
  }
}

String _dayKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
