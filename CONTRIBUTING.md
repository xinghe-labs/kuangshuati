# 贡献指南

先说清楚这个项目的边界，能省掉双方不少时间。

## 这个项目是什么

一个离线优先的 Flutter 刷题 App，做的是**公务员行测**的真题练习。核心承诺写在
[README 的「隐私承诺」](README.md#隐私承诺) 里：没有账号、没有云同步、没有埋点。
任何让这些承诺打折扣的改动都不会被合并，包括为了「体验优化」而引入第三方 SDK。

## 欢迎什么

- **Bug 修复**。优先处理有明确复现步骤的，模板见
  [新建 Issue](https://github.com/xinghe-labs/kuangshuati/issues/new/choose)。
- **测试**。尤其是能拦住真实回归的用例。这个项目有过一次教训：用页面级用例
  验证滚动位置不可靠（解析区被 `ListView` 懒构建，等页面就绪的时间足够跳过
  图片加载窗口，回退修复照样通过），拦截最后落在组件级用例上。别重复这个坑。
- **文档**。上手步骤、常见问题、iOS 自签流程，写清楚就行，不需要文采。
- **无障碍与布局**。320 px 宽不横向溢出、焦点可达、正误状态不只靠颜色——
  这几条有现成的用例兜底（`app/test/layout_overflow_matrix_test.dart` 等）。
- **性能**。有实测数字的 PR 最受欢迎：改前 / 改后各是多少，在什么设备上。

## 不接收什么

**题库内容**。题目、解析、图片的版权不属于本项目，仓库里不包含题库数据，
Release 也不分发题库。请不要提交题库文件、真题原文、或内联真题素材的测试用例
（公开视图会剔除这类文件，别让它们先被搜到再被删）。

**重写式 PR**。不先开 Issue 讨论就提交大范围重构，通常会被搁置。改之前先说
要解决什么问题。

## 开发流程

```bash
cd app
flutter pub get
flutter analyze   # 必须零问题
flutter test      # 必须全绿
```

CI（[ci.yml](.github/workflows/ci.yml)）跑的就是 `flutter analyze` + `flutter test`，
绿灯是合并前提。会有少数用例显式 `skip`：它们依赖真实题库分片，拿不到私有资源时
自动跳过，不设 `KSQ_BANKS_DIR` 也能全绿。

真机集成测试需要设备：

```bash
cd app
flutter test integration_test/app_flow_test.dart -d <设备序列号>
```

## 约定

- **提交信息**：中文，一句话说清「改了什么、为什么」。不写「fix bug」。
- **粒度**：一个逻辑改动一个提交。别把格式化重排和功能改动混在一起——
  项目里已有 `dart format` 的独立提交，混着来会让 review 和回滚都变难。
- **格式**：提交前跑 `dart format .`。
- **依赖**：新增依赖要在 PR 里说明为什么现成的做不到。这个项目的依赖清单
  是可以被用户逐个审计的，多一个包就是多一份需要解释的东西。
- **数据库迁移**：`app/lib/data/database/app_database.dart` 的 `schemaVersion`
  每次提升都要配迁移，且要能被旧备份导入。测试见 `app/test/app_database_test.dart`。

## 题库与自托管

想用自己的题库，不需要改代码：

- **导入 JSON**：App 内「设置 → 导入题库」，格式见
  [question-bank-format.md](docs/question-bank-format.md)。
- **换掉默认下载源**：`--dart-define=CONTENT_MANIFEST_URL=...`，见
  [self-host-content.md](docs/self-host-content.md)。

## 安全问题

不要开 Issue。走 [SECURITY.md](SECURITY.md) 里的私密渠道。
