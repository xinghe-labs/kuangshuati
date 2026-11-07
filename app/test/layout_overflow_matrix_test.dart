// 回归：多页面 × 小屏 × 大字号 不允许出现布局溢出。
//
// 早先实测到：错题页 360 宽默认字号就向右溢出 52px（「标记掌握」被切掉），
// 统计页 320 宽 + 字号 1.3 向右溢出 25px，首页 320 宽默认字号向下溢出 34px，
// 设置页 320 宽 + 字号 2.0 向右溢出 6px。这些都已修，用这个矩阵钉住。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/bank/bank_page.dart';
import 'package:kuangshuati/features/content/content_manager_base.dart';
import 'package:kuangshuati/features/home/home_page.dart';
import 'package:kuangshuati/features/settings/settings_page.dart';
import 'package:kuangshuati/features/backup/backup_page.dart';
import 'package:kuangshuati/features/content/content_install_page.dart';
import 'package:kuangshuati/features/practice/practice_page.dart';
import 'package:kuangshuati/features/result/result_page.dart';
import 'package:kuangshuati/features/stats/stats_page.dart';
import 'package:kuangshuati/features/wrong/wrong_page.dart';

class _StubContentRepository extends SeedContentRepository {
  _StubContentRepository(this.questions);

  final List<QuestionContent> questions;

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    final byId = {for (final question in questions) question.id: question};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  List<QuestionContent> get allQuestions => questions;

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};
}

QuestionContent _question(int index) => QuestionContent(
  id: 'q-$index',
  paperId: 'paper-1',
  questionNo: index,
  sequence: index,
  module: '判断推理',
  stem: '第 $index 题的题干，用来测试大字号下的换行与布局是否溢出',
  options: const {'A': '甲选项内容', 'B': '乙选项内容'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

class _StubContentManager extends ContentManagerBase {
  _StubContentManager(this.repository);

  @override
  final ContentRepository repository;

  @override
  ContentManagerPhase get phase => ContentManagerPhase.ready;

  @override
  double get progress => 1;

  @override
  String get stage => '';

  @override
  String? get errorMessage => null;

  @override
  bool get hasFullContent => true;

  @override
  String? get errorDetail => null;

  @override
  bool get hasManifest => true;

  @override
  bool get updateAvailable => false;

  @override
  Future<void> checkForManifest() async {}

  @override
  Future<void> downloadAndInstall() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> importBankFile(
    String path, {
    void Function(double progress, String stage)? onProgress,
  }) async {}
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  final questions = [for (var i = 1; i <= 6; i++) _question(i)];
  final repository = _StubContentRepository(questions);

  Future<void> seed() async {
    await database.createSession(
      id: 's1',
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: questions,
      revealMode: RevealMode.immediate,
      requestedCount: questions.length,
    );
    for (final question in questions.take(3)) {
      await database.saveAnswer(
        sessionId: 's1',
        questionId: question.id,
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 1200,
        module: question.module,
      );
    }
    await database.toggleFavorite(questions.first.id);
    await database.setFavoriteNote(
      questions.first.id,
      '这是一条比较长的收藏笔记内容，用来测试大字号换行',
    );
  }

  final pages = <String, Widget>{
    'home': const Scaffold(body: HomePage()),
    'bank': const Scaffold(body: BankPage()),
    'wrong': const Scaffold(body: WrongPage()),
    'stats': const Scaffold(body: StatsPage()),
    'settings': const Scaffold(body: SettingsPage()),
    'practice': const PracticePage(sessionId: 's1'),
    'result': const ResultPage(sessionId: 's1'),
    'backup': const BackupPage(),
    'content': const ContentInstallPage(),
  };

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('矩阵 ${width.toInt()}x$scale', (tester) async {
        await tester.runAsync(seed);
        tester.view.physicalSize = Size(width, 720) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        for (final entry in pages.entries) {
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final full = details.toString().replaceAll('\n', ' ~ ');
            errors.add(
              '${details.exception.toString().split('\n').first} || '
              '${full.length > 1400 ? full.substring(0, 1400) : full}',
            );
          };
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                contentRepositoryProvider.overrideWithValue(repository),
                contentManagerProvider.overrideWith(
                  (ref) => _StubContentManager(repository),
                ),
              ],
              child: MaterialApp(
                theme: buildAppTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          await tester.pump();
          FlutterError.onError = previous;
          tester.takeException();
          expect(
            errors,
            isEmpty,
            reason:
                'w=$width scale=$scale page=${entry.key} 出现布局溢出：'
                '${errors.join(" | ")}',
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
