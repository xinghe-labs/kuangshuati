import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              title: '随机 10 题',
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

  Future<void> _startSequence(BuildContext context, WidgetRef ref) {
    final questions = ref.read(contentRepositoryProvider).allQuestions;
    return launchPractice(
      context,
      ref,
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: questions,
    );
  }

  Future<void> _startRandom(BuildContext context, WidgetRef ref) {
    return launchPractice(
      context,
      ref,
      mode: PracticeMode.random,
      title: '随机练习',
      questions: randomQuestions(ref, 10),
      requestedCount: 10,
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
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.wrong,
      title: '到期错题复习',
      questions: questionsFromIds(ref, dueIds),
    );
  }

  Future<void> _startPaper(
    BuildContext context,
    WidgetRef ref,
    Paper paper, {
    bool mock = false,
  }) {
    final questions = ref
        .read(contentRepositoryProvider)
        .questionsForPaper(paper.id);
    return launchPractice(
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

class _ContinuePanel extends StatelessWidget {
  const _ContinuePanel({required this.session});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    final answered = session.currentIndex.clamp(0, session.actualCount - 1) + 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上次练到第 $answered / ${session.actualCount} 题',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            session.title,
            style: const TextStyle(color: Color(0xFFBDBDB7), fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/practice/${session.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
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
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '还没有正在进行的练习',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '先做一组 10 题，系统会从第一道错题开始安排复习。',
            style: TextStyle(color: Color(0xFFC9C9C3), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRandom,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
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
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF777771)),
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
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.35 : 1.18,
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
        side: const BorderSide(color: AppColors.line),
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
                    style: const TextStyle(
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
    final papers = ref.read(contentRepositoryProvider).allPapers.take(2);
    return HairlineList(
      children: [
        for (final paper in papers)
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
        style: const TextStyle(color: AppColors.negative, fontSize: 13),
      ),
    );
  }
}

String _dayKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
