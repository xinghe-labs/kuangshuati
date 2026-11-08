import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'content_install_page.dart';
import 'content_manager_base.dart';

/// 题库管理页：列出本机所有题库（官方 + 导入），支持删除释放空间。
class BankManagerPage extends ConsumerStatefulWidget {
  const BankManagerPage({super.key});

  @override
  ConsumerState<BankManagerPage> createState() => _BankManagerPageState();
}

class _BankManagerPageState extends ConsumerState<BankManagerPage> {
  bool _deleting = false;

  Future<void> _confirmDelete(InstalledBankView bank) async {
    final official = bank.source == 'official';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${bank.name}」？'),
        content: Text(
          official
              ? '官方题库删除后可以随时重新下载。练习记录和统计会保留。'
              : '导入的题库删除后无法恢复（导入文件还在的话可以重新导入）。练习记录和统计会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(contentManagerProvider).deleteBank(bank.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除「${bank.name}」')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(contentManagerProvider);
    final banks = manager.installedBanks;
    if (_deleting) {
      return const AppPage(
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    return AppPage(
      children: [
        PageIntro(
          title: '题库管理',
          description: '多套题库存放在本机，可以随时删除释放空间。',
        ),
        const SizedBox(height: 16),
        const SectionHeading(title: '题库更新'),
        _GroupCard(
          children: [
            _Tile(
              icon: Icons.cloud_download_outlined,
              title: '检查题库更新',
              subtitle: '下载或更新官方题库',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (manager.updateAvailable) const _UpdatePill(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ContentInstallPage(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeading(
          title: banks.isEmpty ? '已安装题库' : '已安装题库（${banks.length}）',
        ),
        if (banks.isEmpty)
          _GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '还没有题库。下载官方题库，或在设置页导入自制题库 JSON 文件。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          )
        else
          _GroupCard(
            children: [
              for (var i = 0; i < banks.length; i++) ...[
                if (i > 0) const _TileDivider(),
                _Tile(
                  icon: banks[i].source == 'official'
                      ? Icons.verified_outlined
                      : Icons.upload_file_outlined,
                  title: banks[i].name,
                  subtitle: [
                    '${banks[i].questionCount} 题 · ${banks[i].paperCount} 套卷',
                    banks[i].contentVersion,
                    _formatBytes(banks[i].databaseBytes),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除题库',
                    onPressed: () => _confirmDelete(banks[i]),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 12),
        Text(
          '练习记录与统计独立保存，删除题库不会丢失做题历史。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
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

class _Tile extends StatelessWidget {
  const _Tile({
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // SDK <3.8 不支援 null-aware elements 语法，忽略该 lint。
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1),
    );
  }
}
