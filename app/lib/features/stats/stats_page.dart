import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyState = ref.watch(dailyStatsProvider);
    final moduleState = ref.watch(moduleStatsProvider);
    final reviews = ref.watch(reviewItemsProvider);

    return AppPage(
      children: [
        const PageIntro(title: '统计', description: '只看能指导下一步练习的数据，不做无关的排名和积分。'),
        dailyState.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stack) => Text('读取统计失败：$error'),
          data: (daily) {
            final recent = daily.reversed.toList();
            final lastSeven = recent.length > 7
                ? recent.sublist(recent.length - 7)
                : recent;
            final answered = lastSeven.fold<int>(
              0,
              (sum, item) => sum + item.answeredCount,
            );
            final correct = lastSeven.fold<int>(
              0,
              (sum, item) => sum + item.correctCount,
            );
            final duration = lastSeven.fold<int>(
              0,
              (sum, item) => sum + item.durationMs,
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
                    MetricItem('投入', '${duration ~/ 60000}', '分钟'),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionHeading(title: '最近练习量'),
                _DailyBars(items: lastSeven),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: '模块表现'),
        moduleState.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stack) => Text('读取模块统计失败：$error'),
          data: (modules) {
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
            final active =
                modules.where((item) => item.answeredCount > 0).toList()
                  ..sort((a, b) {
                    final aRate = a.correctCount / a.answeredCount;
                    final bRate = b.correctCount / b.answeredCount;
                    return aRate.compareTo(bRate);
                  });
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
            final weak = active.isEmpty ? null : active.first;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '下一步建议',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    weak == null
                        ? '先完成一组 10 题，建立你的第一份能力画像。'
                        : due > 0
                        ? '先清掉 $due 道到期错题，再针对“${weak.module}”做一组短练习。'
                        : '当前最需要补强的是“${weak.module}”，正确率 ${(weak.correctCount * 100 / weak.answeredCount).round()}%。',
                    style: const TextStyle(
                      color: Color(0xFFD2D2CC),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  if (weak != null) ...[
                    const SizedBox(height: 13),
                    FilledButton.icon(
                      onPressed: () => _startModule(context, ref, weak.module),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
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
  ) {
    final questions =
        ref
            .read(contentRepositoryProvider)
            .allQuestions
            .where((question) => question.module == module)
            .toList()
          ..shuffle(Random.secure());
    return launchPractice(
      context,
      ref,
      mode: PracticeMode.custom,
      title: '$module · 定向练习',
      questions: questions,
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.items});

  final List<DailyStat> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 76,
        child: Center(
          child: Text(
            '完成练习后显示趋势',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    final maxValue = items.fold<int>(
      1,
      (value, item) => max(value, item.answeredCount),
    );
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${item.answeredCount}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 54 * (item.answeredCount / maxValue) + 3,
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.day.substring(5),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final ModuleStat module;

  @override
  Widget build(BuildContext context) {
    final rate = module.correctCount / module.answeredCount;
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
                '${(rate * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1),
              minHeight: 5,
              backgroundColor: AppColors.softFill,
              valueColor: const AlwaysStoppedAnimation(AppColors.ink),
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
                '${(module.durationMs / 60000).round()} 分钟',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
