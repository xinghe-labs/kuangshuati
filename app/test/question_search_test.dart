import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// 题库搜索：用户能否按题干/材料/选项找到那道题。
///
/// 背景：题库 58890 题 / 515 份试卷，而题库页的搜索框原本只查 papers 表的
/// 标题和地区。用户想找回“做错过的那道题”时，按题干搜得到 0 条结果，只能
/// 一份份试卷点进去翻。
void main() {
  const databasePath =
      'assets/content/content.sqlite';

  late Database database;
  late FullContentRepository repository;

  setUpAll(() {
    database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    repository = FullContentRepository.forTesting(database);
  });

  tearDownAll(() => database.close());

  test('按题干片段能搜到题目，并带回完整选项和答案', () async {
    final results = await repository.searchQuestions('习近平');
    expect(results, isNotEmpty, reason: '题干里含“习近平”的题必须能被搜到');
    final question = results.first;
    expect(question.plainStem, isNotEmpty);
    expect(question.options, isNotEmpty);
    expect(question.correctAnswers, isNotEmpty);
  });

  test('按选项文字能搜到题目（用户常只记得选项里的词）', () async {
    // “基层治理”出现在选项里而不是题干里，也能命中。
    final results = await repository.searchQuestions('基层治理');
    expect(results, isNotEmpty);
    expect(
      results.any(
        (question) =>
            question.options.values.any((text) => text.contains('基层治理')) ||
            question.plainStem.contains('基层治理'),
      ),
      isTrue,
    );
  });

  test('空搜索词返回空列表，不会把整库拉出来', () async {
    expect(await repository.searchQuestions(''), isEmpty);
    expect(await repository.searchQuestions('   '), isEmpty);
  });

  test('搜索词里的 % 和 _ 按字面匹配，不当通配符', () async {
    // 早先用 LIKE '%...%' 时，用户搜“20%”会变成模糊匹配、结果全乱。
    final percent = await repository.searchQuestions('%');
    expect(
      percent.every(
        (question) =>
            question.plainStem.contains('%') ||
            (question.material ?? '').contains('%') ||
            question.options.values.any((text) => text.contains('%')),
      ),
      isTrue,
      reason: '搜 % 时只应返回真的含 % 字符的题',
    );
  });

  test('搜不到时返回空列表而不是抛异常', () async {
    expect(await repository.searchQuestions('这串字题库里绝对没有zzzz'), isEmpty);
  });
}
