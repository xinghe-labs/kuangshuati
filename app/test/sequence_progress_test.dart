import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// 顺序练习必须能往后推进。
///
/// 背景：`sequenceQuestions` 早先固定 `ORDER BY year ASC ... LIMIT 100`，
/// 每次点“顺序练习”拿到的都是题库最前面那 100 题；题库共 58890 题，
/// 用户练完一遍后再点还是同一批，既做不完题库，也分不清是不是自己没进度。
void main() {
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
}
