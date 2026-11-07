import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// 顺序练习必须能往后推进。
///
/// 背景：`sequenceQuestions` 早先固定 `ORDER BY year ASC ... LIMIT 100`，
/// 每次点“顺序练习”拿到的都是题库最前面那 100 题；题库共 58890 题，
/// 用户练完一遍后再点还是同一批，既做不完题库，也分不清是不是自己没进度。
void main() {
  // 题库不随仓库分发：拿不到 content.sqlite 时整组跳过，避免公开仓库的
  // CI 因为缺少私有题库资源而变红。
  if (!File('assets/content/content.sqlite').existsSync()) {
    test('缺少题库，跳过', () {}, skip: '未提供 assets/content/content.sqlite');
    return;
  }
  late Database database;
  late FullContentRepository repository;

  setUpAll(() {
    database = sqlite3.open(
      'assets/content/content.sqlite',
      mode: OpenMode.readOnly,
    );
    repository = FullContentRepository.forTesting(database);
  });

  tearDownAll(() => database.close());

  test('不传排除列表时从第一题开始', () async {
    final first = await repository.sequenceQuestions(limit: 5);
    expect(first, hasLength(5));
  });

  test('排除已做过的题后，返回的是后面没做过的那批', () async {
    final firstBatch = await repository.sequenceQuestions(limit: 5);
    final firstIds = firstBatch.map((question) => question.id).toList();

    final nextBatch = await repository.sequenceQuestions(
      limit: 5,
      excludeIds: firstIds,
    );
    expect(nextBatch, hasLength(5));
    final nextIds = nextBatch.map((question) => question.id).toList();
    expect(
      nextIds.toSet().intersection(firstIds.toSet()),
      isEmpty,
      reason: '已做过的题不能再出现',
    );
    // 顺序不能乱：仍然是题库顺序里的下一批。
    expect(nextIds.first, isNot(firstIds.first));
  });

  test('排除量很大时仍然只返回 limit 条', () async {
    final all = await repository.sequenceQuestions(limit: 200);
    final ids = all.map((question) => question.id).toList();
    final next = await repository.sequenceQuestions(limit: 10, excludeIds: ids);
    expect(next, hasLength(10));
    expect(
      next.map((question) => question.id).toSet().intersection(ids.toSet()),
      isEmpty,
    );
  });

  test('已做过的题超过 SQLite 参数上限（32766）时也能继续往后做', () async {
    // 老用户很容易做过 4 万道以上（题库共 58890 道）。
    // 早先用 `id NOT IN (?,?,...)` 拼参数，超过 32766 个直接报
    // “too many SQL variables”，顺序练习点不动。
    final all = await repository.sequenceQuestions(limit: 40000);
    final ids = all.map((question) => question.id).toList();
    expect(ids.length, greaterThan(32766));

    final next = await repository.sequenceQuestions(limit: 100, excludeIds: ids);
    expect(next, hasLength(100));
    expect(
      next.map((question) => question.id).toSet().intersection(ids.toSet()),
      isEmpty,
      reason: '已做过的题不能再出现',
    );
  });

  test('全部题都做过时返回空列表（首页据此提示“已全部练过”）', () async {
    final all = await repository.sequenceQuestions(limit: 60000);
    final ids = all.map((question) => question.id).toList();
    expect(ids.length, greaterThan(50000));
    final next = await repository.sequenceQuestions(limit: 100, excludeIds: ids);
    expect(next, isEmpty);
  });
}
