import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../content/content_install_page.dart';
import 'settings_platform_io.dart'
    if (dart.library.js_interop) 'settings_platform_web.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final label = await SettingsPlatform.versionLabel(ref);
    if (!mounted) return;
    setState(() {
      _versionLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider).value ?? 1;
    final revealImmediately =
        ref.watch(revealImmediatelyProvider).value ?? true;
    final showTimer = ref.watch(showTimerProvider).value ?? true;
    final contentStats = ref.watch(contentStatsProvider);
    final contentManager = ref.watch(contentManagerProvider);

    return AppPage(
      children: [
        const PageIntro(title: '设置', description: '偏好立即生效并保存在本机。'),
        const SectionHeading(title: '练习偏好'),
        _GroupCard(
          children: [
            _SettingTile(
              icon: Icons.format_size,
              title: '题目字号',
              subtitle: '调整题干和选项的文字大小',
              trailing: SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('小')),
                  ButtonSegment(value: 1, label: Text('标准')),
                  ButtonSegment(value: 1.15, label: Text('大')),
                ],
                selected: {_nearestScale(fontScale)},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (selection) {
                  ref
                      .read(databaseProvider)
                      .setSetting('fontScale', selection.first.toString());
                },
              ),
            ),
            _divider,
            _SettingTile(
              icon: Icons.lightbulb_outline,
              title: '作答后立即显示答案',
              subtitle: '关闭后，交卷或模考结束时再显示解析',
              trailing: Switch(
                value: revealImmediately,
                onChanged: (value) => ref
                    .read(databaseProvider)
                    .setSetting('revealImmediately', value.toString()),
              ),
            ),
            _divider,
            _SettingTile(
              icon: Icons.timer_outlined,
              title: '练习时显示计时',
              subtitle: '计时仍会记录，只影响练习页显示',
              trailing: Switch(
                value: showTimer,
                onChanged: (value) => ref
                    .read(databaseProvider)
                    .setSetting('showTimer', value.toString()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '题库与数据'),
        _GroupCard(
          children: [
            _SettingTile(
              icon: Icons.library_books_outlined,
              title: '离线题库',
              subtitle: contentStats.when(
                data: (stats) => '版本 ${stats.contentVersion}',
                loading: () => '正在读取题库',
                error: (error, stackTrace) => '题库读取失败',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (contentManager.updateAvailable) const _UpdatePill(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ContentInstallPage(),
                ),
              ),
            ),
            _divider,
            for (final action in SettingsPlatform.dataActions()) ...[
              _SettingTile(
                icon: action.icon,
                title: action.title,
                subtitle: action.subtitle,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => action.onTap(context, ref),
              ),
              _divider,
            ],
            _SettingTile(
              icon: Icons.delete_sweep_outlined,
              title: '清空练习记录',
              subtitle: '删除答题历史、错题本、收藏、笔记和统计，不影响题库；建议先导出备份',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _confirmClearData(),
            ),
            _divider,
            _SettingTile(
              icon: Icons.phone_android,
              title: SettingsPlatform.storageNoteTitle,
              subtitle: SettingsPlatform.storageNote,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '关于'),
        _GroupCard(
          children: [
            for (final action in SettingsPlatform.aboutActions()) ...[
              _SettingTile(
                icon: action.icon,
                title: action.title,
                subtitle: action.subtitle,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => action.onTap(context, ref),
              ),
              _divider,
            ],
            _SettingTile(
              icon: Icons.info_outline,
              title: '狂刷题',
              subtitle: '行测真题离线刷题',
              trailing: Text(
                _versionLabel.isEmpty ? '' : '版本 $_versionLabel',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              '题库来自公开真题整理，仅用于个人学习',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空练习记录'),
        content: const Text(
          '将删除答题历史、错题本、收藏（含你写的笔记）和统计数据。'
          '此操作不可恢复，题库不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).clearPracticeData();
    ref.invalidate(contentStatsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('练习记录已清空')));
  }

  double _nearestScale(double value) {
    const allowed = [0.9, 1.0, 1.15];
    return allowed.reduce(
      (best, current) =>
          (current - value).abs() < (best - value).abs() ? current : best,
    );
  }

  static const _divider = Divider(height: 1, indent: 50);
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppColors.muted),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class _UpdatePill extends StatelessWidget {
  const _UpdatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.positiveFill,
      child: Text(
        '有更新',
        style: TextStyle(
          color: AppColors.positive,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
