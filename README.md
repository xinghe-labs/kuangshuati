# 狂刷题

面向本人和少量熟人的行测真题工具。产品以“下载或安装后完全离线使用”为前提，核心闭环是：

```text
开始/继续练习 -> 作答 -> 判题解析 -> 结果 -> 错题复习 -> 下一组练习
```

当前仓库已进入 **Android Flutter 全量题库 MVP** 阶段：完整题库已转换为带图片的本地 SQLite 内容库，手机端练习、恢复、错题、统计、收藏与设置闭环已通过 真机 真机集成测试。

## 交付内容

| 文件 | 内容 |
|---|---|
| [需求发现](docs/requirements-discovery.md) | 30 轮用户视角自问自答、事实基线、行为规则、发布边界与 97% 置信度结论 |
| [开发文档](docs/development-plan.md) | 技术架构、数据模型、核心算法、同步与离线策略、迁移、测试和里程碑 |
| [UI 规范](docs/ui-spec.md) | 信息架构、视觉系统、页面与组件状态、响应式、无障碍和验收记录 |
| [HTML 原型](ui/index.html) | 可直接在浏览器运行的移动优先交互原型 |
| [交互脚本](ui/app.js) | 练习会话、筛选、错题、统计、设置和本地持久化 |
| [视觉样式](ui/styles.css) | 桌面与手机布局、视觉 Token、组件状态和动效降级 |
| [Flutter 客户端](app/) | Android/iOS 共用的本地离线刷题应用 |
| [题库导入器](tools/import_question_bank.py) | 从已验证 JSONL 构建带图片的 SQLite 内容库并生成 16 MiB 分片 |

## 查看原型

直接用浏览器打开：

```text
ui/index.html
```

或者在本目录运行本地静态服务器：

```bash
python -m http.server 4174 --directory ui
```

然后访问 `http://127.0.0.1:4174/`。

原型使用 6 道演示题验证交互，不代表生产题库的查询性能和真实题量。界面在题量偏好选择 30 或 50 时仍会显示实际可用的 `1 / 6`，这是演示数据限制。

## 已验证范围

浏览器原型已验证：

- 首页、题库、错题、统计、我的五个主区域。
- 随机、试卷、错题、自定义组卷和整卷模考五类入口。
- 答题、收藏、跳过、答题卡、交卷和结果。
- 逐题解析与交卷后解析两种答案时机。
- 练习恢复、替换确认、计时和自动交卷。
- 键盘作答、焦点管理和弹层焦点返回。
- 768 px、390 px、320 px 手机布局与 1440 px 桌面布局。
- 本地设置持久化、数据导出和进度清除。
- 页面无横向溢出，主要触控目标不小于 44 px。

完整的逐项证据见 [UI 规范](docs/ui-spec.md#11-本地验收记录)。

## Flutter 手机端

```bash
cd app
flutter pub get
flutter run
```

启动时会把 `assets/content/parts/` 中的 19 个分片依次写入应用支持目录，再以只读 SQLite 打开。分片方式避免一次性把约 298 MiB 数据库读入内存。题库更新会替换内容库，用户记录保存在独立的 `kuangshuati_user` 数据库中。

当前已验证：

- `flutter analyze` 无问题。
- 46 个本地单元测试全部通过（组件、数据库、真实资产、备份/恢复、更新下载校验）。
- 真机 真机集成测试通过，实际加载 58,890 道题、515 份试卷。
- 正式 release APK 已在 真机 冷启动通过，3.2 秒完成首屏并加载全量题库。
- 题图从 SQLite BLOB 读取并完成 Flutter 图片解码测试。
- Release APK 约 197 MiB，APK v2 签名与 4 字节对齐验证通过；完整题库分片约 298 MiB。
- Web 端（`flutter build web -t lib/main_web.dart`，或一键 `python tools/build_web.py`）：浏览器内装入 187 MB 核心题库，六种练习模式全部实测可进入（`artifacts/web-modes-e2e.cjs` 11/11），答题/刷新恢复/错题入册/缓存复用实测通过（`artifacts/web-ui-e2e.cjs` 10/10、`artifacts/web-wrong-e2e.cjs` 7/7、`artifacts/web-e2e.cjs` 5/5）。
- Web 端备份与恢复：导出触发浏览器真实下载 `.gkbackup`，选回文件后确认弹窗恢复成功（`artifacts/web-backup-e2e.cjs` 8/8）。两端信封格式一致，手机导出的备份可在 Web 恢复。

## 当前不包含

- iOS 签名、Windows 桌面端发布包和商店上架流程（Windows 本机缺 Visual Studio 构建链，iOS 需 macOS）。
- 题库公开分发授权和正式 HTTPS 更新源（R2 更新源已搭建，上线发布待确认）。

## 如何运行

- Android：`release/` 目录有签名 APK，直接安装后下载数据包即可。
- Web：`python tools/build_web.py` 构建并组装 `app/build/web`（含题库与图片），再 `python tools/serve_web.py` 起一个自带 `Cross-Origin-Opener-Policy: same-origin` / `Cross-Origin-Embedder-Policy: require-corp` 响应头的静态服务器（默认 `http://127.0.0.1:8080`，加 `--lan` 可让同 Wi-Fi 的手机访问），首次打开自动下载题库到浏览器。
  - 不能直接用普通静态服务器：缺这两个头时 `crossOriginIsolated` 为 false，数据库 worker 起不来，题库装不上。
  - 该服务器本身已实测：`artifacts/web-serve-e2e.cjs` 5/5（`crossOriginIsolated=true` → 题库装载 → 进入练习 → 选答提交出答案）。
- Windows/iOS：见「当前不包含」。

Android APK 的签名、发布和自动更新流程见 [release/README.md](release/README.md)。源码保存在私有仓库，`.github/workflows/android-release.yml` 会把签名 APK 和更新清单发布到公开只读的 S3 兼容对象存储。

## 题库基线

开发文档基于现有清洗结果：

- 来源 516 套试卷，排除 1 个无题目的模块索引后导入 515 套。
- 58,890 道题。
- 39,463 个图片引用，39,196 张去重题图成功导入。
- 2 张源文件缺失图片保留缺图状态。
- 原始图片 268,103,439 字节，优化后存储 101,953,886 字节。
- 最终 SQLite 311,713,792 字节，构建后拆为 19 个 16 MiB 分片。

题库版权授权未确认前，不应公开分发完整数据。

## 关键决策

- Windows、Android、iOS 优先共用 Flutter 业务层和本地 SQLite。
- Web 使用 OPFS/SQLite WASM，并明确浏览器持久存储可能被清理。
- 第一版不做账号和云同步，以本地文件备份替代复杂跨设备合并。
- 不为了“看起来功能多”加入社区、排行榜、金币或 AI 功能。
