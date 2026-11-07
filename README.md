# 狂刷题

**把 5.8 万道行测真题装进手机，断网也能刷。不注册、不登录、不埋点，作答记录只留在这台设备上。**

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-3DDC84)

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" alt="首页：今日概览与练习入口" width="170"><br><sub>首页 · 今日概览</sub></td>
    <td align="center"><img src="docs/screenshots/papers.png" alt="题库页：试卷列表" width="170"><br><sub>题库 · 515 套试卷</sub></td>
    <td align="center"><img src="docs/screenshots/practice.png" alt="资料分析题，题干带两个图表" width="170"><br><sub>资料分析题（带图）</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/selected.png" alt="已选答案 A，计时中" width="170"><br><sub>作答 · 计时</sub></td>
    <td align="center"><img src="docs/screenshots/solution.png" alt="回答错误后的解析页" width="170"><br><sub>错题解析</sub></td>
    <td align="center"><img src="docs/screenshots/result.png" alt="练习结果与逐题回顾" width="170"><br><sub>结果 · 逐题回顾</sub></td>
  </tr>
</table>

<sub>截图来自真机上的 release 构建，不是原型图。</sub>

## 下载安装

不想编译源码？直接从 [Releases](https://github.com/xinghe-labs/kuangshuati/releases) 下载最新 APK 安装（当前 v1.0.8）。首次启动在应用内下载题库（约 145 MB，分片下载、SHA-256 校验），之后全程离线。APK 的 SHA-256 见对应 Release 说明。

## 它能做什么

- **真离线**：58,890 道题、515 套试卷、39,196 张题图放在本地 SQLite（约 297 MB），装好题库后全程不需要网络。
- **六种练习入口**：顺序练习、随机练习、试卷练习、错题复习、自定义组卷、整卷模考。
- **两种答案时机**：逐题解析，或交卷后统一出解析。
- **完整闭环**：作答 → 判题 → 解析 → 结果 → 错题入册 → 下一组；中断后能接着上次的进度继续。
- **错题本与收藏**：到期复习队列、掌握标记、笔记与收藏分离。
- **统计与备份**：作答统计、最近练习正确率、跨端 `.gkbackup` 备份与恢复（原生端与 Web 端互导已实测）。
- **细节**：资料分析题图内联排版、深色模式跟随系统、键盘作答与快捷键、模考倒计时与自动交卷。
- **本地优先**：没有账号体系、没有云同步、没有第三方埋点 SDK（`pubspec.yaml` 里没有 analytics 依赖，代码里没有上报逻辑）。

## 快速开始

```bash
git clone <repo>
cd app
flutter pub get
flutter run          # 首次启动自动下载并安装题库（约 145 MB），之后全程离线
```

题库默认从作者的内容源拉取（地址即 `app/lib/features/content/content_package_service.dart` 里 `CONTENT_MANIFEST_URL` 的默认值）。要换成自己的题库有两条路：

**A. 指向自己的清单**（清单格式见 [`docs/content-manifest.example.json`](docs/content-manifest.example.json)，其中的 SHA-256 是全零占位，填你自己包的真值）

```bash
flutter run --dart-define=CONTENT_MANIFEST_URL=https://your-host/content-manifest.json
```

首次启动会下载、校验 SHA-256 并安装题库包，之后离线使用。

**B. 自己生成题库包**：题库导入与内容包构建工具未包含在开源范围。内容包的格式与清单结构见 [docs/content-manifest.example.json](docs/content-manifest.example.json)，可自行实现生成器后用 `--dart-define=CONTENT_MANIFEST_URL` 指向自己的清单。

> 拿不到题库时（离线、或下载失败），debug 构建会回落到内置的 12 道演示题，方便先把交互跑通；`--dart-define=KUANGSHUATI_DEMO=false` 可关掉这个兜底。

### Web 端

`app/web` 保留完整的 Flutter Web 壳（OPFS + SQLite WASM，需 `Cross-Origin-Opener-Policy: same-origin` 与 `Cross-Origin-Embedder-Policy: require-corp` 响应头才能起数据库 worker）。构建与本地预览脚本未包含在开源范围，需自行解决静态服务器的响应头。

## 架构

```text
app/         Flutter 客户端（Android 已验证，iOS 仅编译验证）
  lib/data/content/     内容库读取：分片安装、只读 SQLite、题图 BLOB
  lib/data/database/    用户数据（作答、错题、收藏、笔记）—— drift，与内容库物理隔离
  lib/features/         首页 / 题库 / 练习 / 错题 / 统计 / 设置
docs/        截图与内容清单示例
```

几个刻意的取舍：

- **内容库与用户库分离**。题库更新只替换内容库，作答记录不会丢。
- **题库按 16 MiB 分片下发**。避免把 297 MB 一次性读进内存，也支持并发分片下载（并发数换带宽，实测 24 路 1.54 MB/s vs 2 路 0.27 MB/s）。
- **不做账号和云同步**。用本地文件备份替代跨设备合并，省掉一整套服务端和隐私面。
- **不为了显得功能多加社区、排行榜、金币、AI 对话**。

## 测试

```bash
cd app
flutter analyze     # 无问题
flutter test        # 126 个测试通过
```

覆盖组件渲染（含题图内联/块级分流）、数据库、备份恢复、更新包校验、多选题判分、空白题不入错题本、收藏与笔记分离、深色色表切换、演示题库兜底等回归用例。依赖真实题库分片的集成测试在拿不到分片时会自动跳过，所以公开仓库的 CI 不需要私有资源。

CI 配置见 `.github/workflows/ci.yml`。

## 题库来源与授权（请先读这条）
- **本仓库只开源代码，不包含题库数据。** 仓库里没有任何一道真实题目的正文、解析或题图。
- App 首次启动从作者的内容源下载题库包（约 145 MB，按 16 MiB 分片）。题目为公考真题的网友回忆整理，题目与解析的权利归原出处；**本项目未取得原出处的公开分发授权**，题库仅以个人学习用途提供给 App 下载，请勿转售或再分发。
- 内置的 12 道演示题是自写的示例数据，仅用于跑通交互。

## 已知限制

- **iOS**：只有编译验证（`.github/workflows/ios-build.yml`），没有签名和真机包。
- **Windows 桌面**：没有验证过，本机缺 Visual Studio 构建链。
- **Web 端**：首次要装约 187 MB 核心题库，弱网体验一般；OPFS 可能被浏览器清理。
- **演示题库**：12 道题，只能验证交互，不能用来评估做题体验。
- **图片类题目**：题库里 2 张源图缺失，保留缺图状态而不是静默删题。
- 在 Windows 上跑 `flutter test` 偶发 `sqlite3.dll` 拒绝访问，是 native-assets 构建缓存被残留测试进程占用，关掉残留 `dart.exe`/`flutter_tester.exe` 重试即可。

CI 配置见 `.github/workflows/ci.yml`。

## 许可证

代码以 [Apache License 2.0](LICENSE) 发布。题库数据不在许可范围内（见上文）。
