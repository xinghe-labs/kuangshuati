import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

/// 「模块弱项」的最小样本量（开发文档 §11.1）：已作答不足 10 道的模块只标“数据较少”，
/// 不参与弱项评选，避免“3 题错 1 题”被当成薄弱模块。
const int kWeakModuleMinAnswered = 10;

/// 一组练习的默认题量（requirements-discovery Q18：默认 20 题）。
const int kDefaultPracticeCount = 20;

/// 选出最需要补强的模块（开发文档 §11.1）。
///
/// 已作答不足 [kWeakModuleMinAnswered] 道的模块不参与评选，
/// 避免“3 题错 1 题”被说成薄弱模块；没有合格模块时返回 null。
///
/// 排序先比正确率，正确率相同时比作答量：
/// 早先只比正确率，两个模块都是 100% 时会返回排序靠前的那个，
/// 于是“答了 200 道全对”和“答了 10 道全对”被同等对待，
/// 甚至刚做满 10 道的模块会被判成“当前最需要补强”。
ModuleStat? weakestModule(List<ModuleStat> modules) {
  final eligible =
      modules
          .where((item) => item.answeredCount >= kWeakModuleMinAnswered)
          .toList()
        ..sort((a, b) {
          final aRate = a.correctCount / a.answeredCount;
          final bRate = b.correctCount / b.answeredCount;
          final byRate = aRate.compareTo(bRate);
          if (byRate != 0) return byRate;
          // 正确率相同：作答越多说明样本越可靠，优先当作弱项。
          return b.answeredCount.compareTo(a.answeredCount);
        });
  return eligible.isEmpty ? null : eligible.first;
}

/// 错题本状态卡：复习中/今日到期/已掌握，到期时点击直达错题页。
class _ReviewCard extends ConsumerWidget {
  const _ReviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewItemsProvider);
    return reviews.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stack) => Text('读取错题本失败：$error'),
      data: (items) {
        // 到期口径与错题页/首页保持一致：nextReviewAt <= now 就算待复习，
        // 不再用“当天 23:59:59”提前把明天的任务算进来。
        final now = DateTime.now().millisecondsSinceEpoch;
        final active = items.where((item) => !item.mastered).toList();
        final due = active
            .where(
              (item) => item.nextReviewAt == null || item.nextReviewAt! <= now,
            )
            .length;
        final mastered = items.length - active.length;
        final total = items.length;
        final progress = total == 0 ? 0.0 : mastered / total;
        return InkWell(
          onTap: due > 0 ? () => ref.read(routerProvider).go('/wrong') : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ReviewNumber('复习中', '${active.length}'),
                    _ReviewNumber('待复习', '$due', highlight: due > 0),
                    _ReviewNumber('已掌握', '$mastered'),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.softFill,
                    valueColor: AlwaysStoppedAnimation(AppColors.ink),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  total == 0
                      ? '答错的题会自动进入这里，安排复习'
                      : '掌握进度 $mastered / $total · ${due > 0 ? '有 $due 道现在待复习' : '暂时没有待复习的错题'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewNumber extends StatelessWidget {
  const _ReviewNumber(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.negative : AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyState = ref.watch(dailyStatsProvider);
    final moduleState = ref.watch(moduleStatsProvider);
    final reviews = ref.watch(reviewItemsProvider);
    final streak = ref.watch(practiceStreakProvider);

    return AppPage(
      children: [
        const PageIntro(title: '统计', description: '只看能指导下一步练习的数据，不做无关的排名和积分。'),
        dailyState.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stack) => Text('读取统计失败：$error'),
          data: (daily) {
            // 近 7 天按自然日统计：日表里没有记录的日子也是 0 题，
            // 不再把“最近 7 条有数据的记录”当成最近 7 天。
            final now = DateTime.now();
            String localDay(DateTime time) {
              final month = time.month.toString().padLeft(2, '0');
              final day = time.day.toString().padLeft(2, '0');
              return '${time.year}-$month-$day';
            }

            final lastSevenDays = {
              for (var i = 0; i < 7; i++)
                localDay(now.subtract(Duration(days: i))),
            };
            final lastSeven = daily
                .where((item) => lastSevenDays.contains(item.day))
                .toList(growable: false);
            final answered = lastSeven.fold<int>(
              0,
              (sum, item) => sum + item.answeredCount,
            );
            final correct = lastSeven.fold<int>(
              0,
              (sum, item) => sum + item.correctCount,
            );
            final accuracy = answered == 0 ? 0 : correct / answered;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricStrip(
                  items: [
                    MetricItem('近 7 天', '$answered', '题'),
                    MetricItem(
                      '正确率',
                      answered == 0 ? '—' : '${(accuracy * 100).round()}',
                      answered == 0 ? null : '%',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 开发文档 §11.3：连续天数按本地自然日去重，隔一天即断档。
                MetricStrip(
                  items: [
                    MetricItem(
                      '连续练习',
                      '${streak.value?.currentDays ?? 0}',
                      '天',
                    ),
                    MetricItem('累计练习', '${streak.value?.totalDays ?? 0}', '天'),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: '错题本'),
        _ReviewCard(),
        const SizedBox(height: 24),
        const SectionHeading(title: '模块表现'),
        moduleState.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stack) => Text('读取模块统计失败：$error'),
          data: (modules) {
            // 开发文档 §11.1：少于 10 道实际作答的模块不给出正确率，只标“数据较少”。
            final active = modules
                .where((item) => item.answeredCount > 0)
                .toList();
            if (active.isEmpty) {
              return const AppEmptyState(
                title: '还没有足够的模块数据',
                message: '完成一组练习后，这里会指出最需要补强的模块。',
              );
            }
            return Column(
              children: [
                for (final module in active) ...[
                  _ModuleRow(module: module),
                  const SizedBox(height: 9),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        moduleState.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => Text('读取建议失败：$error'),
          data: (modules) {
            // 弱项只在样本量够（至少 10 道已作答）的模块里选，避免“3 题错 1 题”被说成弱项。
            final weak = weakestModule(modules);
            final due =
                reviews.value
                    ?.where(
                      (item) =>
                          !item.mastered &&
                          (item.nextReviewAt == null ||
                              item.nextReviewAt! <=
                                  DateTime.now().millisecondsSinceEpoch),
                    )
                    .length ??
                0;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下一步建议',
                    style: TextStyle(
                      color: AppColors.onInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    weak == null
                        ? '先完成一组 20 题，建立你的第一份能力画像。'
                        : due > 0
                        ? '先清掉 $due 道到期错题，再针对“${weak.module}”做一组短练习。'
                        : '当前最需要补强的是“${weak.module}”，正确率 ${(weak.correctCount * 100 / weak.answeredCount).round()}%。',
                    style: TextStyle(
                      color: AppColors.onInkMuted,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  if (weak != null) ...[
                    const SizedBox(height: 13),
                    FilledButton.icon(
                      onPressed: () => _startModule(context, ref, weak.module),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.onInk,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('练这个模块'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _startModule(
    BuildContext context,
    WidgetRef ref,
    String module,
  ) async {
    // 弱项入口与首页一致：一组默认 20 题（requirements-discovery Q18/Q19）。
    final questions = await ref
        .read(contentRepositoryProvider)
        .randomQuestions(kDefaultPracticeCount, module: module);
    if (!context.mounted) return;
    await launchPractice(
      context,
      ref,
      mode: PracticeMode.custom,
      title: '$module · 定向练习',
      questions: questions,
      requestedCount: kDefaultPracticeCount,
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final ModuleStat module;

  @override
  Widget build(BuildContext context) {
    final rate = module.correctCount / module.answeredCount;
    final enough = module.answeredCount >= kWeakModuleMinAnswered;
    return Container(
      padding: const EdgeInsets.all(14),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  module.module,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                enough ? '${(rate * 100).round()}%' : '数据较少',
                style: TextStyle(
                  color: enough ? AppColors.ink : AppColors.muted,
                  fontSize: enough ? 17 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: enough ? rate.clamp(0, 1) : 0,
              minHeight: 5,
              backgroundColor: AppColors.softFill,
              valueColor: AlwaysStoppedAnimation(
                enough ? AppColors.ink : AppColors.softFill,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                '${module.correctCount} / ${module.answeredCount} 题',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                enough
                    ? '${(module.durationMs / 60000).round()} 分钟'
                    : '再做 ${kWeakModuleMinAnswered - module.answeredCount} 题后看正确率',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
