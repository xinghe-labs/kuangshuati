import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'backup_service.dart';
import 'web_backup_io.dart';

/// Web 端的备份与恢复页。
///
/// 浏览器里没有本地文件系统，导出是触发一次浏览器下载，恢复是从文件选择框
/// 读回 .gkbackup。格式与 Android 端完全一致，两端备份可以互导。
///
/// 恢复流程与原生页一致：先展示备份里的记录条数，用户确认后先把当前数据
/// 下载为安全备份，再执行事务内替换（失败自动回滚）。
class WebBackupPage extends ConsumerStatefulWidget {
  const WebBackupPage({super.key});

  @override
  ConsumerState<WebBackupPage> createState() => _WebBackupPageState();
}

class _WebBackupPageState extends ConsumerState<WebBackupPage> {
  BackupCounts? _counts;
  bool _busy = false;
  String? _status;
  _StatusTone _statusTone = _StatusTone.info;

  BackupService get _service => ref.read(backupServiceProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final counts = await _service.currentCounts();
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (error) {
      if (!mounted) return;
      _showStatus('读取当前数据失败：$error', tone: _StatusTone.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: AppPage(
        children: [
          const PageIntro(
            title: '备份与恢复',
            description:
                '练习记录只保存在这个浏览器里。导出一份备份文件保存到你的电脑，'
                '清理浏览器数据或换设备后都能接回来；文件也能在手机 App 里恢复。',
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            _StatusBar(message: _status!, tone: _statusTone),
          ],
          const SectionHeading(title: '当前数据'),
          _CountsCard(counts: _counts, busy: _busy),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('导出备份'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '导出会通过浏览器下载一个 .gkbackup 文件（gzip 压缩，只含练习记录，不含题库），'
            '请妥善保存。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          const SectionHeading(title: '从备份文件恢复'),
          _GroupCard(
            children: [
              _ActionTile(
                icon: Icons.folder_open_outlined,
                title: '选择备份文件',
                subtitle: '选择之前导出的 .gkbackup 文件恢复',
                onTap: _busy ? null : _import,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '恢复会覆盖当前的练习记录、错题本、收藏和统计。执行前会先自动下载当前数据的'
            '安全备份，请确认下载完成后再继续；题库内容不受影响。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } on BackupFormatException catch (error) {
      _showStatus('备份文件无法读取：${error.message}', tone: _StatusTone.warning);
    } catch (error) {
      _showStatus('操作失败：$error', tone: _StatusTone.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  void _showStatus(String message, {_StatusTone tone = _StatusTone.info}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusTone = tone;
    });
  }

  Future<void> _export() => _runBusy(() async {
    final envelope = await _service.buildEnvelope();
    await downloadBackupBytes(envelope.bytes, envelope.fileName);
    if (!mounted) return;
    _showStatus('已开始下载 ${envelope.fileName}，请在浏览器下载列表确认保存。');
  });

  Future<void> _import() => _runBusy(() async {
    final picked = await pickBackupFile();
    if (picked == null) {
      if (!mounted) return;
      _showStatus('没有选择文件，未做任何改动。');
      return;
    }
    final snapshot = await _service.parseBackupBytes(
      picked.bytes,
      sourceName: picked.name,
    );
    if (!mounted) return;
    final confirmed = await _confirmRestore(snapshot);
    if (confirmed != true) return;
    // 先把当前数据下载为安全备份（与原生页「自动另存本机备份」对应），
    // 再执行替换。替换在事务里进行，失败会整体回滚。
    final safety = await _service.buildEnvelope();
    await downloadBackupBytes(safety.bytes, safety.fileName);
    await _service.restore(snapshot, keepSafetyBackup: false);
    if (!mounted) return;
    ref.invalidate(contentStatsProvider);
    _showStatus(
      '已恢复 ${snapshot.createdAtLabel} 的备份；恢复前的数据已下载为 '
      '${safety.fileName}，需要的话可以用它恢复回来。',
      tone: _StatusTone.success,
    );
  });

  Future<bool?> _confirmRestore(BackupSnapshot snapshot) {
    final counts = snapshot.counts;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复这份备份？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件：${snapshot.sourceName}'),
            const SizedBox(height: 4),
            Text('备份时间：${snapshot.createdAtLabel}'),
            const SizedBox(height: 4),
            Text('应用版本：${snapshot.appVersion}'),
            const SizedBox(height: 4),
            Text('题库版本：${snapshot.contentVersion}'),
            const SizedBox(height: 12),
            for (final entry in counts.entries)
              if (entry.$2 > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${entry.$1}：${entry.$2}'),
                ),
            if (counts.isEmpty) const Text('这份备份里没有练习记录，恢复后当前进度会被清空。'),
            const SizedBox(height: 12),
            const Text(
              '当前数据会先自动下载为安全备份，再被这份备份覆盖。',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }
}

enum _StatusTone { info, warning, success }

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.message, required this.tone});

  final String message;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _StatusTone.warning => AppColors.warningFill,
      _StatusTone.success => AppColors.positiveFill,
      _StatusTone.info => AppColors.surface,
    };
    final foreground = switch (tone) {
      _StatusTone.warning => AppColors.warning,
      _StatusTone.success => AppColors.positive,
      _StatusTone.info => AppColors.ink,
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: background,
      child: Text(
        message,
        style: TextStyle(color: foreground, fontSize: 12.5, height: 1.5),
      ),
    );
  }
}

class _CountsCard extends StatelessWidget {
  const _CountsCard({required this.counts, required this.busy});

  final BackupCounts? counts;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final current = counts;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: current == null
          ? const Text('正在读取当前数据…', style: TextStyle(color: AppColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in current.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.$1,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${entry.$2}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
            const Icon(Icons.chevron_right, size: 20),
          ],
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
