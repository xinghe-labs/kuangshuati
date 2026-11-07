// 开源试用路径的回归测试：没有已安装题库时，debug 构建必须能直接用
// 内置演示题库进入练习，而不是停在「需要下载约 145 MB 题库包」的页面。
//
// 这条路径是 `flutter run` 开箱可用的唯一保证，所以要有测试盯着，
// 避免以后有人在 initialize() 里把回落逻辑删掉。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/features/content/content_manager.dart';
import 'package:kuangshuati/features/content/content_manager_base.dart';

void main() {
  test('没有已安装题库时回落到内置演示题库', () async {
    expect(kDemoContentFallback, isTrue, reason: 'flutter test 跑在 debug 构建下');

    final root = await Directory.systemTemp.createTemp('kuangshuati-demo-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final manager = await ContentManager.create(supportDirectory: root);
    addTearDown(manager.dispose);
    await manager.initialize();

    expect(manager.phase, ContentManagerPhase.ready);
    expect(manager.hasFullContent, isFalse, reason: '演示题库不是完整题库');
    expect(manager.stage, contains('内置演示题库'));

    final stats = await manager.repository.stats();
    expect(stats.questionCount, SeedContentRepository.questions.length);
    expect(stats.paperCount, SeedContentRepository.papers.length);
  });
}
