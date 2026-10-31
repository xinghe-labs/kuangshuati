import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/backup/backup_platform.dart';
import 'package:kuangshuati/features/backup/backup_service.dart';

void main() {
  late AppDatabase database;
  late Directory tempDirectory;
  final repository = SeedContentRepository();
  final questions = repository.allQuestions.take(3).toList();

  BackupService buildService() => BackupService(
    database: database,
    directoryOf: () async => tempDirectory,
    appVersionLabel: () async => '1.7.0 (17)',
    contentInfo: () async => {
      'contentVersion': '2026.02',
      'questionCount': questions.length,
      'paperCount': 1,
    },
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    tempDirectory = await Directory.systemTemp.createTemp('kst-backup-test');
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> seedPracticeData() async {
    await database.createSession(
      id: 'session-1',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: 'session-1',
      questionId: questions[0].id,
      selected: questions[0].correctAnswers,
      submitted: true,
      isCorrect: true,
      durationMs: 900,
    );
    await database.saveAnswer(
      sessionId: 'session-1',
      questionId: questions[1].id,
      selected: const {'Z'},
      submitted: true,
      isCorrect: false,
      durationMs: 1200,
    );
    await database.saveProgress(
      sessionId: 'session-1',
      currentIndex: 2,
      durationMs: 2100,
    );
  }

  test(
    'export writes a verifiable backup file with counts and manifest',
    () async {
      await seedPracticeData();
      final service = buildService();

      final file = await service.export();
      expect(await file.exists(), isTrue);
      expect(file.path.endsWith(BackupService.extension), isTrue);

      final snapshot = await service.read(file);
      expect(snapshot.manifest['format'], BackupService.format);
      expect(snapshot.manifest['formatVersion'], BackupService.formatVersion);
      expect(snapshot.appVersion, '1.7.0 (17)');
      expect(snapshot.contentVersion, '2026.02');
      expect(snapshot.counts.sessions, 1);
      expect(snapshot.counts.answeredQuestions, 2);
      expect(snapshot.counts.isEmpty, isFalse);
      expect(snapshot.byteSize, greaterThan(0));
    },
  );

  test('restore replaces current practice data with the snapshot', () async {
    await seedPracticeData();
    final service = buildService();
    final file = await service.export();
    final snapshot = await service.read(file);

    await database.clearPracticeData();
    expect((await service.currentCounts()).sessions, 0);

    final outcome = await service.restore(snapshot);
    expect(outcome.safetyBackup, isNotNull);
    expect(await outcome.safetyBackup!.exists(), isTrue);

    final counts = await service.currentCounts();
    expect(counts.sessions, 1);
    expect(counts.answeredQuestions, 2);
  });

  test(
    'restore keeps practice answers from the snapshot after a wrong guess',
    () async {
      await seedPracticeData();
      final service = buildService();
      final snapshot = await service.read(await service.export());

      await database.clearPracticeData();
      await service.restore(snapshot);

      final answers = await database
          .customSelect(
            'SELECT question_id, is_correct FROM session_answers ORDER BY question_id',
          )
          .get();
      expect(answers, hasLength(2));
      final correctFlags = answers
          .map((row) => row.data['is_correct'])
          .toList();
      expect(
        correctFlags.where((value) => value == 1 || value == true),
        hasLength(1),
      );
    },
  );

  test('parseBackupBytes rejects corrupted payloads', () async {
    await seedPracticeData();
    final service = buildService();
    final file = await service.export();
    final bytes = await file.readAsBytes();

    // 破坏压缩流中段，解压或摘要校验必须拦住，且只能是 BackupFormatException。
    final corrupted = Uint8List.fromList(bytes);
    corrupted[corrupted.length ~/ 2] ^= 0xFF;
    expect(
      () => service.parseBackupBytes(corrupted, sourceName: 'broken.gkbackup'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test(
    'parseBackupBytes rejects payload whose digest no longer matches',
    () async {
      await seedPracticeData();
      final service = buildService();
      final bytes = await (await service.export()).readAsBytes();
      final envelope =
          jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
      final tables = Map<String, Object?>.from(
        envelope['tables']! as Map<String, Object?>,
      );
      final answers = Map<String, Object?>.from(
        tables['session_answers']! as Map<String, Object?>,
      );
      final rows = List<Object?>.from(
        answers['rows']! as List,
      ).map((row) => List<Object?>.from(row! as List)).toList();
      expect(rows, isNotEmpty);
      // 把第一条答案的正误标志反过来，但不更新 manifest 里的摘要。
      rows[0][rows[0].length - 1] = 'tampered-value';
      answers['rows'] = rows;
      tables['session_answers'] = answers;
      envelope['tables'] = tables;
      final tampered = Uint8List.fromList(
        gzip.encode(utf8.encode(jsonEncode(envelope))),
      );

      expect(
        () =>
            service.parseBackupBytes(tampered, sourceName: 'tampered.gkbackup'),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.message,
            'message',
            contains('校验失败'),
          ),
        ),
      );
    },
  );

  test(
    'listBackups returns newest first and prunes to five files',
    () async {
      final service = buildService();
      for (var index = 0; index < 7; index++) {
        final file = await service.export();
        // 保证文件名和时间戳有区分度（同秒导出会互相覆盖）。
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(await file.exists(), isTrue);
      }
      final backups = await service.listBackups();
      expect(backups, hasLength(5));
      final times = <DateTime>[];
      for (final backup in backups) {
        times.add(await backup.lastModified());
      }
      for (var index = 1; index < times.length; index++) {
        expect(
          times[index - 1].isAfter(times[index]) ||
              times[index - 1].isAtSameMomentAs(times[index]),
          isTrue,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('分享备份的临时副本在下次分享前被清掉，不会无限堆积', () async {
    // 早先每次「分享备份」都在系统临时目录写一份完整数据库副本，
    // 分享 N 次就留 N 份，长期白占存储空间。
    final temp = await Directory.systemTemp.createTemp('kst-share-test');
    addTearDown(() => temp.delete(recursive: true));

    // 模拟用户分享过两次，留下两份旧副本。
    for (final name in ['kst-share-a.gkbackup', 'kst-share-b.gkbackup']) {
      await File('${temp.path}/$name').writeAsBytes([1, 2, 3]);
    }
    // 同时放一个无关文件，必须不能被误删。
    final keep = File('${temp.path}/keep.txt');
    await keep.writeAsString('不要删我');

    final removed = await pruneShareTempFiles(temp);

    expect(removed, 2);
    expect(
      temp.listSync().map((entity) => entity.uri.pathSegments.last).toList(),
      ['keep.txt'],
    );
    expect(await keep.readAsString(), '不要删我');
  });

  test('临时目录不可读时清理不抛异常', () async {
    final missing = Directory('${Directory.systemTemp.path}/kst-not-exist-xyz');
    expect(await pruneShareTempFiles(missing), 0);
  });
}
