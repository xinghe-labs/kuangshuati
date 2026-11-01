// 题库读取失败（文件损坏 / I/O 错误）时，首页各入口必须给出提示。
// 旧行为：异常直接抛到手势回调，用户点了「随机 20 题」屏幕毫无反应。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/home/home_page.dart';

/// 题库文件坏了：任何读取都抛异常。
class _BrokenRepository extends SeedContentRepository {
  @override
  List<QuestionContent> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  }) => throw StateError('题库文件损坏');

  @override
  List<QuestionContent> randomQuestions(int count, {String? module}) =>
      throw StateError('题库文件损坏');

  @override
  List<Paper> recentPapers({int limit = 5}) => const [];

  @override
  List<Paper> searchPapers({String query = '', int? year}) => const [];
}

Future<void> _settle(WidgetTester tester, [int ms = 250]) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms ~/ 5)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .toList();

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(_BrokenRepository()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await _settle(tester, 400);
  }

  testWidgets('题库读取失败时点「随机 20 题」必须给出提示，不能毫无反应', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('随机 20 题'));
    await _settle(tester, 400);

    expect(
      _texts(tester).any((text) => text.contains('题库读取失败')),
      isTrue,
      reason: '点随机练习没有任何反馈：${_texts(tester).join(" | ")}',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('题库读取失败时点「顺序练习」也要提示', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('顺序练习').first);
    await _settle(tester, 400);

    expect(
      _texts(tester).any((text) => text.contains('题库读取失败')),
      isTrue,
      reason: '点顺序练习没有任何反馈：${_texts(tester).join(" | ")}',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
