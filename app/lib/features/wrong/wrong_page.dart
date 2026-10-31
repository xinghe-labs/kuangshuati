import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

class WrongPage extends ConsumerStatefulWidget {
  const WrongPage({super.key});

  @override
  ConsumerState<WrongPage> createState() => _WrongPageState();
}

class _WrongPageState extends ConsumerState<WrongPage> {
  var _showMastered = false;

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewItemsProvider);
    return AppPage(
      children: [
        PageIntro(
          title: '错题',
          description: '答错的题按阶段自动回来；也可以提前重做或标记已掌握。',
          trailing: PopupMenuButton<bool>(
            tooltip: '筛选错题',
            initialValue: _showMastered,
            onSelected: (value) => setState(() => _showMastered = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: false, child: Text('待复习')),
              PopupMenuItem(value: true, child: Text('已掌握')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ),
        reviewState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Text('读取错题失败：$error'),
          data: (items) {
            final filtered = items
                .where((item) => item.mastered == _showMastered)
                .toList();
            if (!_showMastered) {
              filtered.sort((a, b) {
                final aDue = a.nextReviewAt;
                final bDue = b.nextReviewAt;
                if (aDue == null) return 1;
                if (bDue == null) return -1;
                return aDue.compareTo(bDue);
              });
            }
            if (filtered.isEmpty) {
              return AppEmptyState(
                title: _showMastered ? '还没有已掌握题' : '暂无待复习错题',
                message: _showMastered
                    ? '在待复习列表中把稳定掌握的题标记过来。'
                    : '继续练习，答错的题会自动进入这里。',
              );
            }
            final now = DateTime.now().millisecondsSinceEpoch;
            // 题目表一次性取回：顶部计数只数题库里还能打开的题，
            // 失效记录不虚报到期数量，行内也不再逐条查询。
            return FutureBuilder<Map<String, QuestionContent>>(
              future:
                  Future.value(
                    ref
                        .read(contentRepositoryProvider)
                        .questionsByIds(
                          filtered.map((item) => item.questionId),
                        ),
                  ).then(
                    (questions) => {
                      for (final question in questions) question.id: question,
                    },
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final questions =
                    snapshot.data ?? const <String, QuestionContent>{};
                final dueQuestions = filtered
                    .where(
                      (item) =>
                          questions.containsKey(item.questionId) &&
                          !item.mastered &&
                          (item.nextReviewAt == null ||
                              item.nextReviewAt! <= now),
                    )
                    .map((item) => item.questionId);
                return Column(
                  children: [
                    if (!_showMastered)
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: AppColors.ink,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${dueQuestions.length} 道到期，'
                                '${filtered.length - dueQuestions.length} 道未到期',
                                style: TextStyle(
                                  color: AppColors.onInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: dueQuestions.isEmpty
                                  ? null
                                  : () => _start(dueQuestions),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.onInk,
                                disabledForegroundColor: AppColors.onInkMuted,
                              ),
                              child: const Text('开始复习'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    for (final item in filtered) ...[
                      _ReviewRow(
                        item: item,
                        question: questions[item.questionId],
                        showMastered: _showMastered,
                        onStart: () => _start([item.questionId]),
                        onMastered: (value) => ref
                            .read(databaseProvider)
                            .markReviewMastered(item.questionId, value),
                        onDelete: () => ref
                            .read(databaseProvider)
                            .deleteReviewItems([item.questionId]),
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _start(Iterable<String> ids) async {
    final questions = await questionsFromIds(ref, ids);
    if (!mounted) return;
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.wrong,
      title: '错题复习',
      questions: questions,
    );
  }
}

class _ReviewRow extends ConsumerWidget {
  const _ReviewRow({
    required this.item,
    required this.question,
    required this.showMastered,
    required this.onStart,
    required this.onMastered,
    required this.onDelete,
  });

  final ReviewItem item;
  final QuestionContent? question;
  final bool showMastered;
  final VoidCallback onStart;
  final ValueChanged<bool> onMastered;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = this.question;
    if (question == null) {
      // 题库换版后该题已不存在：不再隐藏成空白行，
      // 让用户看到原因并可手动清理这条记录。
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '题目已随题库更新失效',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '这条错题记录已无法复习，可以从错题本中清理。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onDelete, child: const Text('清理')),
          ],
        ),
      );
    }
    final due =
        item.nextReviewAt != null &&
        item.nextReviewAt! <= DateTime.now().millisecondsSinceEpoch;
    return Container(
      color: AppColors.surface,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '阶段 ${item.stage + 1} / 5',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    color: due && !item.mastered
                        ? AppColors.negativeFill
                        : AppColors.softFill,
                    child: Text(
                      item.mastered
                          ? '已掌握'
                          : due
                          ? '今日到期'
                          : _nextReviewLabel(item.nextReviewAt),
                      style: TextStyle(
                        color: due && !item.mastered
                            ? AppColors.negative
                            : AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                question.plainStem,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    '${question.module} · 错 ${item.wrongCount} 次 · 空 ${item.blankCount} 次',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => onMastered(!showMastered),
                    icon: Icon(
                      showMastered ? Icons.undo : Icons.check,
                      size: 16,
                    ),
                    label: Text(showMastered ? '恢复复习' : '标记掌握'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nextReviewLabel(int? timestamp) {
    if (timestamp == null) return '待安排';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}月${date.day}日';
  }
}
