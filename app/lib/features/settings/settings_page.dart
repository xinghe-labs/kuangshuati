import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../content/content_install_page.dart';
import '../updates/update_flow.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider).value ?? 1;
    final revealImmediately =
        ref.watch(revealImmediatelyProvider).value ?? true;
    final showTimer = ref.watch(showTimerProvider).value ?? true;
    final contentStats = ref.watch(contentStatsProvider);
    final contentManager = ref.watch(contentManagerProvider);
    final database = ref.read(databaseProvider);

    return AppPage(
      children: [
        const PageIntro(title: '设置', description: '偏好立即生效并保存在本机。'),
        const SectionHeading(title: '阅读'),
        Container(
          padding: const EdgeInsets.all(14),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('题目字号', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                '长题干保持清晰，选项不会因此被遮挡。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 13),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('小')),
                  ButtonSegment(value: 1, label: Text('标准')),
                  ButtonSegment(value: 1.15, label: Text('大')),
                  ButtonSegment(value: 1.3, label: Text('特大')),
                ],
                selected: {_nearestScale(fontScale)},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  database.setSetting('fontScale', selection.first.toString());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '练习'),
        HairlineList(
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: const Text('作答后立即显示答案'),
              subtitle: const Text('关闭后，交卷或模考结束时再显示解析'),
              value: revealImmediately,
              onChanged: (value) =>
                  database.setSetting('revealImmediately', value.toString()),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: const Text('练习时显示计时'),
              subtitle: const Text('计时仍会记录，只影响练习页显示'),
              value: showTimer,
              onChanged: (value) =>
                  database.setSetting('showTimer', value.toString()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '本机数据'),
        HairlineList(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: const Icon(Icons.offline_bolt_outlined, size: 21),
              title: const Text('离线题库'),
              subtitle: Text(
                contentStats.when(
                  data: (stats) =>
                      '${stats.questionCount} 道题 · '
                      '${stats.paperCount} 份试卷 · '
                      '${stats.imageCount} 张图片',
                  loading: () => '正在读取离线题库',
                  error: (error, stackTrace) => '题库读取失败',
                ),
              ),
              trailing: _StatePill(
                label: contentManager.updateAvailable ? '有更新' : '已下载',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ContentInstallPage(),
                ),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(Icons.lock_outline, size: 21),
              title: Text('练习记录'),
              subtitle: Text('答题、错题、收藏和笔记仅保存在这台设备'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '关于'),
        HairlineList(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: const Icon(Icons.system_update_alt, size: 21),
              title: const Text('应用更新'),
              subtitle: const Text('启动自动检查，也支持下 SHA-256 校验'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => checkForAppUpdate(context, ref, manual: true),
            ),
            const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 14),
              title: Text('狂刷题'),
              subtitle: Text('移动端首版 · 本地离线运行'),
              trailing: Text(
                '1.0.0',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _nearestScale(double value) {
    const allowed = [0.9, 1.0, 1.15, 1.3];
    return allowed.reduce(
      (best, current) =>
          (current - value).abs() < (best - value).abs() ? current : best,
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.positiveFill,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.positive,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
