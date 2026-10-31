import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'backup_platform.dart';
import 'backup_service.dart';

/// 备份与恢复：导出、分享到其他应用、从本机历史备份或任意文件恢复。
///
/// 恢复一律「先备份当前数据再覆盖」，并允许用户在选择恢复前看清备份里的
/// 练习记录条数与时间，避免拿错文件把当前进度冲掉。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  BackupCounts? _counts;
  List<File> _localBackups = const [];
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
    final service = _service;
    try {
      final results = await Future.wait<Object>([
        service.currentCounts(),
        service.listBackups(),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = results[0] as BackupCounts;
        _localBackups = results[1] as List<File>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '读取本机数据失败：$error';
        _statusTone = _StatusTone.warning;
      });
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
            description: '练习记录只保存在这台手机。导出一份备份，换机、重装或误清空后都能完整接回来。',
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            _StatusBar(message: _status!, tone: _statusTone),
          ],
          const SectionHeading(title: '本机当前数据'),
          _CountsCard(counts: _counts, busy: _busy),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _exportToFile,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('导出到文件'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _shareBackup,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('分享备份'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '「导出到文件」保存到你选择的位置，例如下载目录或网盘；「分享备份」可直接发给自己或存到微信文件传输助手。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          SectionHeading(
            title: '本机备份记录',
            action: TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('刷新'),
            ),
          ),
          if (_localBackups.isEmpty)
            const _EmptyCard(message: '还没有本机备份。导出一次后，这里会保留最近几份。')
          else
            Column(
              children: [
                for (final file in _localBackups)
                  _LocalBackupTile(
                    file: file,
                    busy: _busy,
                    onRestore: () => _restoreFromFile(file),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          const SectionHeading(title: '从其他位置导入'),
          _GroupCard(
            children: [
              _ActionTile(
                icon: Icons.folder_open_outlined,
                title: '选择备份文件',
                subtitle: '从下载、网盘或聊天记录里选一个 .gkbackup 文件恢复',
                onTap: _busy ? null : _importFromPicker,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '恢复会覆盖当前的练习记录、错题本、收藏和统计。执行前会自动把当前数据另存一份本机备份，题库内容不受影响。',
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

  Future<void> _exportToFile() => _runBusy(() async {
    final file = await _service.export();
    final bytes = await file.readAsBytes();
    final saved = await BackupPlatform.saveToFile(
      suggestedName: file.uri.pathSegments.last,
      bytes: bytes,
    );
    if (!mounted) return;
    if (saved) {
      _showStatus('备份已保存：${file.uri.pathSegments.last}');
    } else {
      _showStatus(
        '已生成本机备份（${_service.describe(file)}），但没有保存到其他位置，可在下方本机备份记录里恢复。',
      );
    }
  });

  Future<void> _shareBackup() => _runBusy(() async {
    final file = await _service.export();
    final tempDirectory = await getTemporaryDirectory();
    final copy = File('${tempDirectory.path}/${file.uri.pathSegments.last}');
    await copy.writeAsBytes(await file.readAsBytes(), flush: true);
    final shared = await BackupPlatform.share(copy);
    if (!mounted) return;
    if (shared) {
      _showStatus('已生成备份并打开分享面板：${file.uri.pathSegments.last}');
    } else {
      _showStatus('已生成本机备份（${_service.describe(file)}），系统分享不可用，可在下方本机备份记录里恢复。');
    }
  });

  Future<void> _restoreFromFile(File file) => _runBusy(() async {
    final snapshot = await _service.read(file);
    if (!mounted) return;
    final confirmed = await _confirmRestore(snapshot);
    if (confirmed != true) return;
    final outcome = await _service.restore(snapshot);
    if (!mounted) return;
    _afterRestore(outcome);
  });

  Future<void> _importFromPicker() => _runBusy(() async {
    final picked = await BackupPlatform.pick();
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
    final outcome = await _service.restore(snapshot);
    if (!mounted) return;
    _afterRestore(outcome);
  });

  void _afterRestore(BackupRestoreOutcome outcome) {
    ref.invalidate(contentStatsProvider);
    final safety = outcome.safetyBackup;
    final message = safety == null
        ? '已恢复 ${outcome.snapshot.createdAtLabel} 的备份'
        : '已恢复 ${outcome.snapshot.createdAtLabel} 的备份，恢复前的数据已另存为本机备份'
              '（${safety.uri.pathSegments.last}），需要的话可以再恢复回来。';
    setState(() => _status = message);
  }

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
            Text(
              '当前数据会先自动另存一份本机备份，再被这份备份覆盖。',
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

enum _StatusTone { info, warning }

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.message, required this.tone});

  final String message;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final background = tone == _StatusTone.warning
        ? AppColors.warningFill
        : AppColors.positiveFill;
    final foreground = tone == _StatusTone.warning
        ? AppColors.warning
        : AppColors.positive;
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
          ? Text('正在读取本机数据…', style: TextStyle(color: AppColors.muted))
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

class _LocalBackupTile extends StatelessWidget {
  const _LocalBackupTile({
    required this.file,
    required this.busy,
    required this.onRestore,
  });

  final File file;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final name = file.uri.pathSegments.last;
    final size = file.lengthSync();
    final label = size < 1024
        ? '$size B'
        : '${(size / 1024).toStringAsFixed(1)} KB';
    return Container(
      color: AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(Icons.inventory_2_outlined, color: AppColors.muted),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(label, style: Theme.of(context).textTheme.bodySmall),
        trailing: TextButton(
          onPressed: busy ? null : onRestore,
          child: const Text('恢复'),
        ),
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Text(
        message,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12.5,
          height: 1.5,
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
