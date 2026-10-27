# 狂刷题 Flutter 客户端

本地离线的行测刷题应用。内容题库与用户记录分别保存在两个 SQLite 数据库中：内容库只读，用户库保存会话、答案、错题、收藏、笔记和统计。

## 运行

```bash
flutter pub get
flutter run
```

题库资产位于 `assets/content/`：

- `content-manifest.json`：版本、数量、总字节数和分片信息。
- `parts/content.sqlite.part000` 至 `part018`：最终 SQLite 的 16 MiB 分片。

## 验证

```bash
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart -d <device-id>
```

连接 Android 设备后，集成测试会真实验证全量题库加载、随机练习、提交、恢复、继续练习和主页面导航。
