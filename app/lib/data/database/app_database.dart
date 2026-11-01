import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import 'database_connection_io.dart'
    if (dart.library.js_interop) 'database_connection_web.dart';

part 'app_database.g.dart';

class PracticeSessions extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get title => text()();
  TextColumn get paperId => text().nullable()();
  TextColumn get filtersJson => text().withDefault(const Constant('{}'))();
  TextColumn get questionIdsJson => text()();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  IntColumn get requestedCount => integer().nullable()();
  IntColumn get actualCount => integer()();
  IntColumn get timeLimitSeconds => integer().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get deadlineAt => integer().nullable()();
  TextColumn get revealMode => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get finalizedAt => integer().nullable()();
  TextColumn get contentVersion =>
      text().withDefault(const Constant('demo-1'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SessionQuestions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get questionId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, questionId};
}

class SessionAnswers extends Table {
  TextColumn get sessionId => text()();
  TextColumn get questionId => text()();
  TextColumn get selectedJson => text().withDefault(const Constant('[]'))();
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();
  BoolColumn get isCorrect => boolean().nullable()();
  BoolColumn get uncertain => boolean().withDefault(const Constant(false))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get answeredAt => integer().nullable()();

  /// 这道题是否已经计入过「模块统计」（题数 + 正确数）。
  ///
  /// 练习模式（答完立刻出答案）在 saveAnswer 里就累计了模块，
  /// 交卷时必须跳过它，否则同一题会被算两次；
  /// 模考/交卷后统一判分的题在交卷时才算，标记后同样不会重复。
  ///
  /// 注意它必须保持单调（一旦 true 不再回 false）：saveAnswer 用
  /// insertOnConflictUpdate 整行覆盖，未提交的保存不能把它洗回 false，
  /// 否则交卷时会重复累加。
  BoolColumn get moduleCounted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, questionId};
}

class ReviewItems extends Table {
  TextColumn get questionId => text()();
  TextColumn get source => text().withDefault(const Constant('practice'))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get blankCount => integer().withDefault(const Constant(0))();
  IntColumn get stage => integer().withDefault(const Constant(0))();
  IntColumn get nextReviewAt => integer().nullable()();
  BoolColumn get mastered => boolean().withDefault(const Constant(false))();
  TextColumn get lastResult => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

class Favorites extends Table {
  TextColumn get questionId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// 收藏与笔记分离：只写笔记不强制收藏。
  /// favorited=false 的行是“纯笔记”，不出现在收藏列表里；
  /// 取消收藏只翻转这个标记，不删行，笔记得以保留。
  BoolColumn get favorited => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

class DailyStats extends Table {
  TextColumn get day => text()();
  IntColumn get answeredCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sessionsCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

class ModuleStats extends Table {
  TextColumn get module => text()();
  IntColumn get answeredCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {module};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    PracticeSessions,
    SessionQuestions,
    SessionAnswers,
    ReviewItems,
    Favorites,
    DailyStats,
    ModuleStats,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : _clock = null,
      super(openUserDatabase(name: 'kuangshuati_user'));

  AppDatabase.forTesting(super.executor, {DateTime Function()? clock})
    : _clock = clock; // ignore: prefer_initializing_formals

  /// 测试用的可控时钟：连续天数、每日统计都依赖本地自然日，
  /// 不能靠真等一天来验证“断档”和“回拨不增加”。
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(sessionAnswers, sessionAnswers.uncertain);
      }
      if (from < 3) {
        // Demo question IDs are not part of the imported content database.
        await customStatement('DELETE FROM session_answers');
        await customStatement('DELETE FROM session_questions');
        await customStatement('DELETE FROM practice_sessions');
        await customStatement('DELETE FROM review_items');
        await customStatement('DELETE FROM favorites');
        await customStatement('DELETE FROM daily_stats');
        await customStatement('DELETE FROM module_stats');
      }
      if (from < 4) {
        // 收藏/笔记分离：旧行都是真收藏，默认 favorited=true 即可，
        // 不清理任何用户数据。
        await migrator.addColumn(favorites, favorites.favorited);
      }
      if (from < 5) {
        // 模块统计改成“提交即累计”，需要记住哪些题已经计过，
        // 避免交卷时重复累加。旧数据都是交卷时算的，保持默认 false。
        await migrator.addColumn(sessionAnswers, sessionAnswers.moduleCounted);
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await batch((batch) {
        batch.insertAll(appSettings, [
          const AppSettingsCompanion(
            key: Value('revealImmediately'),
            value: Value('true'),
          ),
          const AppSettingsCompanion(
            key: Value('showTimer'),
            value: Value('true'),
          ),
          const AppSettingsCompanion(
            key: Value('fontScale'),
            value: Value('1.0'),
          ),
          const AppSettingsCompanion(
            key: Value('defaultCount'),
            value: Value('10'),
          ),
        ]);
      });
    },
  );

  /// 清空全部练习记录（答题历史、错题本、收藏、统计），
  /// 不影响题库、图片和设置。
  Future<void> clearPracticeData() async {
    await batch((batch) {
      batch.deleteWhere(sessionAnswers, (_) => const Constant(true));
      batch.deleteWhere(sessionQuestions, (_) => const Constant(true));
      batch.deleteWhere(practiceSessions, (_) => const Constant(true));
      batch.deleteWhere(reviewItems, (_) => const Constant(true));
      batch.deleteWhere(favorites, (_) => const Constant(true));
      batch.deleteWhere(dailyStats, (_) => const Constant(true));
      batch.deleteWhere(moduleStats, (_) => const Constant(true));
    });
    // 连续天数是派生自练习日的汇总，清空练习记录时一并重置。
    await setSetting('streakDays', '0');
    await (delete(
      appSettings,
    )..where((row) => row.key.equals('streakLastDay'))).go();
  }

  Stream<PracticeSession?> watchLatestActiveSession() {
    return (select(practiceSessions)
          ..where((row) => row.status.equals(SessionStatus.active.value))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<PracticeSession?> latestActiveSession() {
    return (select(practiceSessions)
          ..where((row) => row.status.equals(SessionStatus.active.value))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PracticeSession?> sessionById(String id) {
    return (select(
      practiceSessions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<List<SessionQuestion>> sessionQuestionRows(String sessionId) {
    return (select(sessionQuestions)
          ..where((row) => row.sessionId.equals(sessionId))
          ..orderBy([(row) => OrderingTerm.asc(row.position)]))
        .get();
  }

  /// 用户提交过的题目 id（跨所有会话）。
  ///
  /// 顺序练习用它跳过已经做过的题：早先固定从题库最前面取 100 题，
  /// 练完一遍后再点“顺序练习”还是那 100 题。
  Future<List<String>> answeredQuestionIds() async {
    final rows = await (selectOnly(sessionAnswers, distinct: true)
          ..addColumns([sessionAnswers.questionId])
          ..where(sessionAnswers.submitted.equals(true)))
        .get();
    return [for (final row in rows) ?row.read(sessionAnswers.questionId)];
  }

  Future<List<SessionAnswer>> answersForSession(String sessionId) {
    return (select(
      sessionAnswers,
    )..where((row) => row.sessionId.equals(sessionId))).get();
  }

  /// 某次练习里已经作答的题目数（首页「继续练习」的“已答 N 题”）。
  ///
  /// 必须是 Stream：首页早先用 Future 只读一次，用户回首页继续做几题后
  /// 数字不会变（实测答完 5 题仍显示 1），看起来像进度丢了。
  ///
  /// 不能只看 submitted：模考和「关闭立即出答案」模式下，练习页每选一个
  /// 选项就落库一次，但 submitted 要等交卷才置 true。只看 submitted 的话，
  /// 模考答了 3 题退出，首页仍然写“这一组还没有提交答案”。
  /// 所以改成“选过选项就算已答”，与练习页/答题卡的口径一致。
  Stream<int> watchSubmittedCount(String sessionId) {
    return (select(sessionAnswers)
          ..where((row) => row.sessionId.equals(sessionId)))
        .watch()
        .map(
          (rows) => rows
              .where((row) => _decodeSelected(row.selectedJson).isNotEmpty)
              .length,
        );
  }

  /// 一次性读取已作答题数（弹「结束旧练习？」确认时用）。
  Future<int> submittedCountFor(String sessionId) async {
    final rows = await answersForSession(sessionId);
    return rows
        .where((row) => _decodeSelected(row.selectedJson).isNotEmpty)
        .length;
  }

  Future<List<ReviewItem>> allReviewItems() {
    return (select(reviewItems)..orderBy([
          (row) => OrderingTerm.asc(row.mastered),
          (row) => OrderingTerm.asc(row.nextReviewAt),
        ]))
        .get();
  }

  Stream<List<ReviewItem>> watchReviewItems() {
    return (select(reviewItems)..orderBy([
          (row) => OrderingTerm.asc(row.mastered),
          (row) => OrderingTerm.asc(row.nextReviewAt),
        ]))
        .watch();
  }

  Stream<List<DailyStat>> watchDailyStats() {
    return (select(
      dailyStats,
    )..orderBy([(row) => OrderingTerm.desc(row.day)])).watch();
  }

  /// 最近完成（已交卷/已结束）的练习记录。
  ///
  /// 以前只有结果页能看成绩：一离开结果页，sessionId 就再也拿不到，
  /// 用户想回看「昨天那组模考多少分」完全无处可去。
  Stream<List<PracticeSession>> watchRecentSessions({int limit = 20}) {
    return (select(practiceSessions)
          ..where(
            (row) =>
                row.status.equals(SessionStatus.submitted.value) |
                row.status.equals(SessionStatus.abandoned.value),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(limit))
        .watch();
  }

  /// 某次练习的作答概况（回看历史成绩用）。
  Future<SessionSummary> summarizeSession(String sessionId) async {
    final rows = await sessionQuestionRows(sessionId);
    final answers = await answersForSession(sessionId);
    final byQuestion = {for (final answer in answers) answer.questionId: answer};
    var answered = 0;
    var correct = 0;
    var graded = 0;
    for (final row in rows) {
      final answer = byQuestion[row.questionId];
      final selected = _decodeSelected(answer?.selectedJson);
      if (selected.isEmpty) continue;
      answered++;
      // isCorrect 为 null 表示这道题选了选项但从未判过分：
      // 没交卷就被结束的练习就是这种情况，不能算作答错。
      if (answer?.isCorrect != null) {
        graded++;
        if (answer!.isCorrect == true) correct++;
      }
    }
    return SessionSummary(
      totalCount: rows.length,
      answeredCount: answered,
      correctCount: correct,
      gradedCount: graded,
    );
  }

  /// 连续练习天数与总练习天数（开发文档 §11.3）。
  ///
  /// 规则：以本地自然日去重；当天只有完成过至少一道已提交题目才计入；
  /// 隔一天未练习即断档；回拨系统时间不增加连续天数。
  Future<PracticeStreak> practiceStreak() async {
    final totalRow = await customSelect(
      'SELECT COUNT(*) AS n FROM daily_stats WHERE answered_count > 0',
      readsFrom: {dailyStats},
    ).getSingle();
    final totalDays = totalRow.data['n'] as int? ?? 0;
    final streakDays = int.tryParse(await getSetting('streakDays', '0')) ?? 0;
    final lastDay = await getSettingOrNull('streakLastDay');
    // 断档归零：最后练习日不是今天也不是昨天时，连续天数已中断，
    // 展示层不能再拿历史峰值当“当前连续”。
    var currentDays = totalDays == 0 ? 0 : streakDays;
    if (lastDay != null && currentDays > 0) {
      final gap = _daysBetween(lastDay, _localDay(_now()));
      if (gap > 1) currentDays = 0;
    }
    return PracticeStreak(
      currentDays: currentDays,
      totalDays: totalDays,
      lastDay: lastDay,
    );
  }

  Stream<PracticeStreak> watchPracticeStreak() {
    return (select(dailyStats)..orderBy([(row) => OrderingTerm.desc(row.day)]))
        .watch()
        .asyncMap((_) => practiceStreak());
  }

  /// 在交卷写入当日统计后推进连续天数。
  ///
  /// 只比较日期字符串，不依赖时钟单调：回拨到更早的日期时既不推进也不清零，
  /// 因此回拨系统时间无法把连续天数拉高。
  Future<void> _bumpPracticeStreak({
    required String day,
    required int answeredCount,
  }) async {
    if (answeredCount <= 0) return;
    final lastDay = await getSettingOrNull('streakLastDay');
    final days = int.tryParse(await getSetting('streakDays', '0')) ?? 0;
    final next = switch (lastDay) {
      null => 1,
      _ when lastDay == day => days,
      _ when lastDay.compareTo(day) > 0 => days,
      _ when _daysBetween(lastDay, day) == 1 => days + 1,
      _ => 1,
    };
    final nextLastDay = lastDay == null || day.compareTo(lastDay) > 0
        ? day
        : lastDay;
    await setSetting('streakDays', '$next');
    await setSetting('streakLastDay', nextLastDay);
  }

  static int _daysBetween(String from, String to) {
    final start = DateTime.tryParse(from);
    final end = DateTime.tryParse(to);
    if (start == null || end == null) return -1;
    return end.difference(start).inDays;
  }

  Stream<List<ModuleStat>> watchModuleStats() {
    return (select(
      moduleStats,
    )..orderBy([(row) => OrderingTerm.desc(row.answeredCount)])).watch();
  }

  /// 收藏列表：只显示用户主动收藏的题；写笔记但不收藏的行不在这里。
  Stream<List<Favorite>> watchFavoriteItems() {
    return (select(
      favorites,
    )..where((row) => row.favorited.equals(true))).watch();
  }

  /// 笔记列表：所有写过笔记的题（无论是否收藏）。
  Stream<List<Favorite>> watchNoteItems() {
    return (select(
      favorites,
    )..where((row) => row.note.equals('').not())).watch();
  }

  Stream<List<Favorite>> watchFavorites() => select(favorites).watch();

  Future<List<Favorite>> allFavorites() => select(favorites).get();

  Future<bool> isFavorite(String questionId) async {
    final row = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    return row?.favorited ?? false;
  }

  /// 取消收藏不再删除整行（旧行为会连笔记一起永久删除），
  /// 只翻转 favorited 标记；再次收藏时笔记还在。
  Future<bool> toggleFavorite(String questionId) async {
    final existing = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    if (existing == null) {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          questionId: questionId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return true;
    }
    final favorited = !existing.favorited;
    await (update(favorites)
          ..where((item) => item.questionId.equals(questionId)))
        .write(FavoritesCompanion(favorited: Value(favorited)));
    return favorited;
  }

  /// 保存笔记不强制收藏（favorited 保持原状；没收藏过则为 false）。
  Future<void> setFavoriteNote(String questionId, String note) async {
    final existing = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    if (existing == null && note.trim().isEmpty) return;
    await into(favorites).insertOnConflictUpdate(
      FavoritesCompanion.insert(
        questionId: questionId,
        createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        note: Value(note.trim()),
        favorited: Value(existing?.favorited ?? false),
      ),
    );
  }

  Future<String> favoriteNote(String questionId) async {
    final row = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    return row?.note ?? '';
  }

  Future<String> getSetting(String key, String fallback) async {
    final value = await getSettingOrNull(key);
    return value ?? fallback;
  }

  Future<String?> getSettingOrNull(String key) async {
    final row = await (select(
      appSettings,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) {
    return (select(appSettings)..where((item) => item.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<String> createSession({
    required String id,
    required PracticeMode mode,
    required String title,
    required List<QuestionContent> questions,
    required RevealMode revealMode,
    String? paperId,
    int? requestedCount,
    int? timeLimitSeconds,
    Map<String, Object?> filters = const {},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadline = timeLimitSeconds == null
        ? null
        : now + timeLimitSeconds * 1000;
    await transaction(() async {
      // 同一时间只保留一组“进行中”：旧的 active 会话在任何界面上都
      // 回不去了（首页只展示最新一组），留在 active 状态只会制造
      // “继续练习”指向另一组的错觉，这里统一标记为 abandoned。
      await (update(practiceSessions)..where(
            (row) =>
                row.status.equals(SessionStatus.active.value) &
                row.id.equals(id).not(),
          ))
          .write(
            PracticeSessionsCompanion(
              status: Value(SessionStatus.abandoned.value),
              updatedAt: Value(now),
            ),
          );
      await into(practiceSessions).insert(
        PracticeSessionsCompanion.insert(
          id: id,
          mode: mode.name,
          title: title,
          paperId: Value(paperId),
          filtersJson: Value(jsonEncode(filters)),
          questionIdsJson: jsonEncode(
            questions.map((question) => question.id).toList(),
          ),
          requestedCount: Value(requestedCount),
          actualCount: questions.length,
          timeLimitSeconds: Value(timeLimitSeconds),
          deadlineAt: Value(deadline),
          revealMode: revealMode.value,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await batch((batch) {
        batch.insertAll(sessionQuestions, [
          for (var index = 0; index < questions.length; index++)
            SessionQuestionsCompanion.insert(
              sessionId: id,
              questionId: questions[index].id,
              position: index,
            ),
        ]);
      });
    });
    return id;
  }

  Future<void> saveAnswer({
    required String sessionId,
    required String questionId,
    required Set<String> selected,
    required bool submitted,
    required bool? isCorrect,
    required int durationMs,
    bool uncertain = false,
    String? module,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (select(sessionAnswers)..where(
              (row) =>
                  row.sessionId.equals(sessionId) &
                  row.questionId.equals(questionId),
            ))
            .getSingleOrNull();
    // 只要真的选过选项就算“做了这题”，不能只看 submitted：
    //
    // 模考和“关闭立即出答案”的练习模式下，练习页每选一个选项就落库一次
    // （submitted=false），要等交卷才置 true。早先这里只数 submitted，
    // 于是用户在一场 100 题模考里答了 60 题后退出：
    //   - 首页「继续练习」显示「已答 60 题」（submittedCountFor 按选过选项算）
    //   - 统计页「今日已答」却是 0（只在 firstSubmit 时累计）
    //   - 结果页又写「已答 60」
    // 同一个事实三处数字互相矛盾，用户会以为统计坏了。
    final nowSelected = selected.isNotEmpty;
    final wasSelected =
        existing != null && _decodeSelected(existing.selectedJson).isNotEmpty;
    final firstAnswer = nowSelected && !wasSelected;
    // 模块的题数和正确数必须“确定判过分”才记：
    // 模考中途选完选项但没交卷时 isCorrect 是 null，把它当 0 分计入，
    // 会凭空拉低该模块正确率；交卷时 finalizeSession 会按真实判分补计。
    final graded = isCorrect != null;
    // 当日「正确」必须按“第一次拿到明确对错”记，不能只在 firstAnswer 时记。
    //
    // 练习页的真实调用顺序是：点选项先落一次库（selected 有值、isCorrect=null，
    // 这一次就是 firstAnswer），再点「提交答案」落第二次（submitted=true、
    // isCorrect=true）。早先 correct 只跟 firstAnswer 走，于是每道答对的题
    // 都只在第一次（isCorrect 还是 null）时被统计：
    //   首页「今日概览」显示「已答 10 题 / 正确 0 题」，
    //   统计页近 7 天正确率恒为 0%，
    //   而模块正确率却是正常的（它按 graded 记）——同一份数据两处矛盾。
    final firstGraded = graded && nowSelected && existing?.isCorrect == null;
    // 模块统计的题数/正确数只能算一次：用 moduleCounted 记住是否已计过，
    // 后续重存（改选项、翻题、标记不确定、退出前保存）只补时长增量。
    final countedBefore = existing?.moduleCounted ?? false;
    final countsNow =
        nowSelected && graded && module != null && module.isNotEmpty;
    // 时长是累计值（练习页每次都传本题的累计用时），只能补增量，
    // 否则每翻一次题都会把模块总时长再加一遍。
    final previousDurationMs = existing?.durationMs ?? 0;
    final durationDelta = durationMs > previousDurationMs
        ? durationMs - previousDurationMs
        : 0;
    await into(sessionAnswers).insertOnConflictUpdate(
      SessionAnswersCompanion.insert(
        sessionId: sessionId,
        questionId: questionId,
        selectedJson: Value(jsonEncode(selected.toList()..sort())),
        submitted: Value(submitted),
        isCorrect: Value(isCorrect),
        uncertain: Value(uncertain),
        durationMs: Value(durationMs),
        answeredAt: Value(now),
        // 已经计过就必须保持 true：insertOnConflictUpdate 会整行覆盖，
        // 否则一次未提交的保存就能把它清回 false，交卷时又重复计一次。
        moduleCounted: Value(countedBefore || countsNow),
      ),
    );
    final session = await sessionById(sessionId);
    await (update(practiceSessions)..where((row) => row.id.equals(sessionId)))
        .write(PracticeSessionsCompanion(updatedAt: Value(now)));
    final shouldCount = countsNow && !countedBefore;
    if (firstAnswer || firstGraded || shouldCount || durationDelta > 0) {
      await _accumulateDailyStats(
        answered: firstAnswer ? 1 : 0,
        correct: firstGraded && isCorrect == true ? 1 : 0,
        durationMs: durationDelta,
        bumpStreak: firstAnswer,
      );
      // 模块统计也要实时累计：原来只写在 finalizeSession 里，
      // 用户做了几十题但没交卷（直接退出、或点了别的练习把旧会话挤掉），
      // 统计页的「各模块正确率」「最该补的模块」会一直是空的，
      // 而「今日已答」却有数字，看起来像数据对不上。
      if (module != null && module.isNotEmpty && (shouldCount || countedBefore)) {
        await _accumulateModuleStats(
          module: module,
          answered: shouldCount ? 1 : 0,
          correct: shouldCount && isCorrect == true ? 1 : 0,
          durationMs: durationDelta,
        );
      }
    }
    // 答错的题立刻进错题本，不必等到交卷。
    //
    // 练习页每道题提交后就已经判分并显示“回答错误”，但错题本只在
    // finalizeSession 里写：用户做了十几题、错了好几道，直接退出，
    // 或者点「随机 20 题」把旧会话挤成 abandoned，这些错题就永远
    // 进不了错题本（首页还写着“答错的题会自动进入错题本”）。
    //
    // 注意判定条件不能用 firstAnswer（= 第一次选中选项）：
    // 模考里选 B（未判分）→ 改成 C（判分后仍是 submitted=false）时，
    // firstAnswer 已经是 false，这道错题会彻底漏掉。改成“第一次拿到
    // 明确判错的结论”：翻题/标不确定/退出前保存的 isCorrect 是 null，
    // 不会把白卷或未判分的题写进错题本。
    // 已交卷的会话由 finalizeSession 统一处理，这里跳过以免重复计数。
    final firstWrongResult = isCorrect == false &&
        existing?.isCorrect != false &&
        selected.isNotEmpty &&
        session != null &&
        session.status == SessionStatus.active.value;
    if (firstWrongResult) {
      await _updateReview(
        questionId: questionId,
        isCorrect: false,
        uncertain: uncertain,
        now: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }
  }

  Future<void> _accumulateModuleStats({
    required String module,
    required int answered,
    required int correct,
    required int durationMs,
  }) async {
    if (answered == 0 && correct == 0 && durationMs == 0) return;
    final existing = await (select(
      moduleStats,
    )..where((row) => row.module.equals(module))).getSingleOrNull();
    await into(moduleStats).insertOnConflictUpdate(
      ModuleStatsCompanion.insert(
        module: module,
        answeredCount: Value((existing?.answeredCount ?? 0) + answered),
        correctCount: Value((existing?.correctCount ?? 0) + correct),
        durationMs: Value((existing?.durationMs ?? 0) + durationMs),
        updatedAt: _now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 把一份答题增量并入当日统计；需要时推进连续天数。
  Future<void> _accumulateDailyStats({
    required int answered,
    required int correct,
    required int durationMs,
    bool bumpStreak = false,
  }) async {
    if (answered == 0 && correct == 0 && durationMs == 0 && !bumpStreak) {
      return;
    }
    final now = _now();
    final day = _localDay(now);
    final daily = await (select(
      dailyStats,
    )..where((row) => row.day.equals(day))).getSingleOrNull();
    await into(dailyStats).insertOnConflictUpdate(
      DailyStatsCompanion.insert(
        day: day,
        answeredCount: Value((daily?.answeredCount ?? 0) + answered),
        correctCount: Value((daily?.correctCount ?? 0) + correct),
        durationMs: Value((daily?.durationMs ?? 0) + durationMs),
        // 冲突更新时会整行覆盖，必须带上已有值，否则会把当天的开组数清零。
        sessionsCount: Value(daily?.sessionsCount ?? 0),
      ),
    );
    if (bumpStreak) {
      await _bumpPracticeStreak(day: day, answeredCount: answered);
    }
  }

  Future<void> saveProgress({
    required String sessionId,
    required int currentIndex,
    required int durationMs,
  }) {
    return (update(
      practiceSessions,
    )..where((row) => row.id.equals(sessionId))).write(
      PracticeSessionsCompanion(
        currentIndex: Value(currentIndex),
        durationMs: Value(durationMs),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> finalizeSession({
    required String sessionId,
    required Map<String, QuestionContent> questionLookup,
  }) async {
    final session = await sessionById(sessionId);
    if (session == null || session.status != SessionStatus.active.value) return;
    final questions = await sessionQuestionRows(sessionId);
    final answers = await answersForSession(sessionId);
    final answerByQuestion = {
      for (final answer in answers) answer.questionId: answer,
    };
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;
    // 已提交过的答案在 saveAnswer 时已实时计入当日统计，
    // 这里只补交卷时才首次提交的题（模考/交卷后统一判分的练习）。
    var freshAnswered = 0;
    var freshCorrect = 0;
    var freshDurationMs = 0;

    await transaction(() async {
      for (final row in questions) {
        final question = questionLookup[row.questionId];
        if (question == null) continue;
        final answer = answerByQuestion[row.questionId];
        final selected = _decodeSelected(answer?.selectedJson);
        final isCorrect = selected.isNotEmpty && question.isCorrect(selected);
        final blank = selected.isEmpty;
        final alreadySubmitted = answer?.submitted ?? false;
        if (!blank && !alreadySubmitted) {
          freshAnswered++;
          if (isCorrect) freshCorrect++;
          freshDurationMs += answer?.durationMs ?? 0;
        }

        await into(sessionAnswers).insertOnConflictUpdate(
          SessionAnswersCompanion.insert(
            sessionId: sessionId,
            questionId: row.questionId,
            selectedJson: Value(jsonEncode(selected.toList()..sort())),
            submitted: const Value(true),
            isCorrect: Value(isCorrect),
            uncertain: Value(answer?.uncertain ?? false),
            durationMs: Value(answer?.durationMs ?? 0),
            answeredAt: Value(answer?.answeredAt ?? nowMs),
          ),
        );

        // 未作答的题只落答案记录，不进错题本：
        // 白卷、翻完没做的题不应该被当成“做错”来复习。
        // 但若这题已经在错题本里（之前错/空过），仍要累计一次“空”次数：
        // 错题本每行都写着“空 N 次”，而早先 blankCount 从未被写入过，
        // 无论空多少次都恒显“空 0 次”。
        if (blank) {
          await _recordBlank(questionId: row.questionId, now: now);
          continue;
        }
        // 练习中“立即出答案”的模式下，答错的那一题在 saveAnswer 时
        // 就已经写进错题本了（见 saveAnswer）。这里再写一次会把
        // “错 N 次”翻倍，所以跳过；答对/不确定仍由这里处理。
        if (alreadySubmitted && !isCorrect) continue;
        await _updateReview(
          questionId: row.questionId,
          isCorrect: isCorrect,
          uncertain: answer?.uncertain ?? false,
          now: now,
        );
      }

      final day = _localDay(now);
      final daily = await (select(
        dailyStats,
      )..where((row) => row.day.equals(day))).getSingleOrNull();
      await into(dailyStats).insertOnConflictUpdate(
        DailyStatsCompanion.insert(
          day: day,
          answeredCount: Value((daily?.answeredCount ?? 0) + freshAnswered),
          correctCount: Value((daily?.correctCount ?? 0) + freshCorrect),
          durationMs: Value((daily?.durationMs ?? 0) + freshDurationMs),
          sessionsCount: Value((daily?.sessionsCount ?? 0) + 1),
        ),
      );
      await _bumpPracticeStreak(day: day, answeredCount: freshAnswered);

      final moduleTotals = <String, _ModuleTotal>{};
      for (final row in questions) {
        final question = questionLookup[row.questionId];
        if (question == null) continue;
        final answer = answerByQuestion[row.questionId];
        final selected = _decodeSelected(answer?.selectedJson);
        // 已经在 saveAnswer 里实时计过模块统计的题不能在这里重复累加：
        // 「答完立即出答案」模式下，保存答案时就把这道题连同模块算进去了。
        // 这里只补“交卷时才第一次判分”的题（模考 / 关闭立即出答案）。
        if (answer?.moduleCounted == true) continue;
        final total = moduleTotals.putIfAbsent(
          question.module,
          _ModuleTotal.new,
        );
        if (selected.isNotEmpty) {
          total.answered++;
          if (question.isCorrect(selected)) total.correct++;
        }
        total.durationMs += answer?.durationMs ?? 0;
      }
      for (final entry in moduleTotals.entries) {
        await _accumulateModuleStats(
          module: entry.key,
          answered: entry.value.answered,
          correct: entry.value.correct,
          durationMs: entry.value.durationMs,
        );
      }
      // 标记为已计入模块统计，避免重复交卷或其他路径再累加一次。
      if (moduleTotals.isNotEmpty) {
        await (update(sessionAnswers)
              ..where((row) => row.sessionId.equals(sessionId)))
            .write(const SessionAnswersCompanion(moduleCounted: Value(true)));
      }

      await (update(
        practiceSessions,
      )..where((row) => row.id.equals(sessionId))).write(
        PracticeSessionsCompanion(
          status: Value(SessionStatus.submitted.value),
          finalizedAt: Value(nowMs),
          updatedAt: Value(nowMs),
        ),
      );
    });
  }

  Future<void> markReviewMastered(String questionId, bool mastered) async {
    await (update(
      reviewItems,
    )..where((row) => row.questionId.equals(questionId))).write(
      ReviewItemsCompanion(
        mastered: Value(mastered),
        nextReviewAt: Value(
          mastered ? null : DateTime.now().millisecondsSinceEpoch,
        ),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 题库换版后，部分错题/收藏指向的题可能已不存在；
  /// 提供“清理失效记录”，避免错题页永远留着打不开的空行。
  Future<int> deleteReviewItems(Iterable<String> questionIds) async {
    final ids = questionIds.toList();
    if (ids.isEmpty) return 0;
    var deleted = 0;
    for (final id in ids) {
      deleted += await (delete(
        reviewItems,
      )..where((row) => row.questionId.equals(id))).go();
    }
    return deleted;
  }

  /// 已存在的错题记录累计一次“空”。不存在时什么也不做：
  /// 空白不把题拉进错题本，只是如实记录“这题我又空了一次”。
  Future<void> _recordBlank({
    required String questionId,
    required DateTime now,
  }) async {
    final existing = await (select(
      reviewItems,
    )..where((row) => row.questionId.equals(questionId))).getSingleOrNull();
    if (existing == null) return;
    await (update(
      reviewItems,
    )..where((row) => row.questionId.equals(questionId))).write(
      ReviewItemsCompanion(
        blankCount: Value(existing.blankCount + 1),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _updateReview({
    required String questionId,
    required bool isCorrect,
    required bool uncertain,
    required DateTime now,
  }) async {
    final existing = await (select(
      reviewItems,
    )..where((row) => row.questionId.equals(questionId))).getSingleOrNull();
    // 答对且从未进过错题本：不需要复习；
    // 但标记过“不确定”的答对题要进一次复习（明天到期），
    // 否则用户的不确定标记在交卷后彻底消失。
    if (isCorrect && existing == null) {
      if (!uncertain) return;
      await into(reviewItems).insert(
        ReviewItemsCompanion.insert(
          questionId: questionId,
          source: const Value('uncertain'),
          stage: const Value(0),
          nextReviewAt: Value(
            now.add(const Duration(days: 1)).millisecondsSinceEpoch,
          ),
          lastResult: const Value('uncertain'),
          updatedAt: now.millisecondsSinceEpoch,
        ),
      );
      return;
    }

    // 用户自己标了“不确定”，说明他也没把握。结果页会告诉他“已加入明天的
    // 复习计划”，所以这里必须真的排到明天（stage 回到 0），
    // 不能因为蒙对就推进到 3 天/7 天后，否则结果页的承诺就是假的。
    final currentStage = existing?.stage ?? 0;
    final nextStage = isCorrect
        ? (uncertain ? 0 : (currentStage + 1).clamp(0, 4))
        : 0;
    final mastered = isCorrect && !uncertain && nextStage >= 4;
    final intervalDays = const [1, 3, 7, 15, 30][nextStage];
    await into(reviewItems).insertOnConflictUpdate(
      ReviewItemsCompanion.insert(
        questionId: questionId,
        source: Value(existing?.source ?? 'practice'),
        wrongCount: Value((existing?.wrongCount ?? 0) + (isCorrect ? 0 : 1)),
        blankCount: Value(existing?.blankCount ?? 0),
        stage: Value(nextStage),
        nextReviewAt: Value(
          mastered
              ? null
              : now.add(Duration(days: intervalDays)).millisecondsSinceEpoch,
        ),
        mastered: Value(mastered),
        lastResult: Value(
          uncertain ? 'uncertain' : (isCorrect ? 'correct' : 'wrong'),
        ),
        updatedAt: now.millisecondsSinceEpoch,
      ),
    );
  }

  Set<String> _decodeSelected(String? value) {
    if (value == null || value.isEmpty) return {};
    return (jsonDecode(value) as List<dynamic>).cast<String>().toSet();
  }

  String _localDay(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}

class _ModuleTotal {
  int answered = 0;
  int correct = 0;
  int durationMs = 0;
}
