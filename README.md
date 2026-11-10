# 狂刷题

**把行测真题装进手机，断网也能刷。不注册、不登录、不埋点，作答记录只留在这台设备上。**

[![CI](https://github.com/xinghe-labs/kuangshuati/actions/workflows/ci.yml/badge.svg)](https://github.com/xinghe-labs/kuangshuati/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44.1-02569B)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-3DDC84)

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" alt="首页：今日概览与练习入口" width="170"><br><sub>首页 · 今日概览</sub></td>
    <td align="center"><img src="docs/screenshots/papers.png" alt="题库页：试卷列表" width="170"><br><sub>题库 · 试卷列表</sub></td>
    <td align="center"><img src="docs/screenshots/practice.png" alt="资料分析题，题干带两个图表" width="170"><br><sub>资料分析题（带图）</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/selected.png" alt="已选答案 A，计时中" width="170"><br><sub>作答 · 计时</sub></td>
    <td align="center"><img src="docs/screenshots/solution.png" alt="回答错误后的解析页" width="170"><br><sub>错题解析</sub></td>
    <td align="center"><img src="docs/screenshots/result.png" alt="练习结果与逐题回顾" width="170"><br><sub>结果 · 逐题回顾</sub></td>
  </tr>
</table>

<sub>真机 release 构建截图，不是原型图。</sub>

## 下载安装

不想编译源码？直接从 [Releases](https://github.com/xinghe-labs/kuangshuati/releases) 下载最新 APK（当前 v1.1.1）。首次启动在应用内下载题库（约 145 MB，SHA-256 校验后安装），之后全程离线。

### 在线试用（不用装）

**👉 [xinghe-labs.github.io/kuangshuati](https://xinghe-labs.github.io/kuangshuati/)**

浏览器直接打开就能点：练习流程、逐题解析、整卷模考倒计时、交卷后统一判分、错题本、统计都能跑通。

> ⚠️ 试用版只内置 **12 道演示题**（完整题库源自私有仓库，不随公开版分发）。想真正刷真题，请下载 APK。
>
> 试用版数据存在浏览器本地，清理站点数据即清空。

## 功能

- **真离线**：题库与题图全部落在本地 SQLite，装好题库断网可用。
- **六种练习入口**：顺序、随机、试卷、错题复习、自定义组卷、整卷模考（含按题库模块占比随机组卷的「随机模考」）；逐题解析或交卷后统一出解析。
- **自定义题库**：导入自己整理的 JSON 题库（支持图片、多选、主观自评题），与官方题库并存，练习记录互不干扰；格式见 [docs/question-bank-format.md](docs/question-bank-format.md)；App 内「设置 → 导入题库 → 查看格式与示例」也有一份可复制的最小示例。
- **完整闭环**：作答 → 判题 → 解析 → 结果 → 错题入册 → 到期复习；中断后能接着上次的进度继续。
- **统计与备份**：作答统计、最近练习正确率、跨端 `.gkbackup` 备份与恢复（原生端与 Web 端互导已实测）。
- **体验细节**：资料分析题图内联排版、深色模式跟随系统、键盘作答与快捷键、模考倒计时自动交卷。

## 隐私承诺

- **没有账号体系**：不注册、不登录，App 不知道你是谁。
- **数据只在本机**：没有云同步，卸载即清除；要迁移就用 `.gkbackup` 备份文件，它由你自己保管。
- **无埋点**：依赖清单里没有任何第三方统计或广告 SDK，全部依赖可公开审计。
- **网络只用于两件事**：首次下载题库包（SHA-256 校验）和应用内检查更新，仅此而已。

## Roadmap

- [x] Android 正式发布（v1.1.1）
- [x] Web 构建支持，在线试用版已部署到 GitHub Pages
- [ ] iOS 支持：代码同构，CI 已做编译验证；缺签名证书，上架时间待定
- [ ] 题库内容更新：应用内已支持版本检查，公开的更新节奏待定

---

以下内容面向开发者。

## 快速开始

环境要求：Flutter 3.44.1（CI 使用同一版本）、Dart ^3.12.1。

```bash
git clone https://github.com/xinghe-labs/kuangshuati.git
cd kuangshuati/app
flutter pub get
flutter run
```

Web 版：

```bash
flutter run -d chrome --target=lib/main_web.dart        # 本地调试
flutter build web --target=lib/main_web.dart            # 构建产物在 build/web
```

Web 端有独立入口 `lib/main_web.dart`（原生入口 `lib/main.dart` 依赖 `dart:ffi`/sqlite3，不能用于 Web 构建）。

公开在线试用版由 `.github/workflows/web-demo.yml` 自动构建部署，额外加两个参数：

```bash
flutter build web --release \
  --target=lib/main_web.dart \
  --dart-define=KSQ_WEB_TRIAL=seed \
  --base-href=/kuangshuati/
```

- `KSQ_WEB_TRIAL=seed`：跳过题库下载流程，直接用内置的 12 道演示题（公开试用版不能分发私有题库）；
- `--base-href=/kuangshuati/`：GitHub Pages 的仓库子路径。

不带 `KSQ_WEB_TRIAL=seed` 时，Web 版走正常题库下载流程，行为与之前一致。

测试：

```bash
flutter test
```

依赖真实题库的集成测试在拿不到题库分片时自动跳过，所以无需私有资源即可跑通全部测试。

## 项目结构

```
app/                  # Flutter 应用主体
  lib/core/           # 基础设施（配置、常量、工具）
  lib/data/           # 数据层（drift/SQLite、题库下载、备份）
  lib/domain/         # 领域模型与业务逻辑
  lib/features/       # 按功能划分的页面与状态（practice、papers、stats…）
  lib/shared/         # 跨功能共享的组件
  web/                # Web 端入口（sqlite3.wasm、drift_worker）
docs/                 # 内容清单示例、自定义题库格式文档与示例
.github/workflows/    # CI（静态分析+测试）、iOS 编译验证、Web 试用版部署
```

## 题库数据

题库数据**不在本仓库内**。这里有两个容易混的 JSON，用途完全不同：

| 文件 | 用途 |
| --- | --- |
| [`docs/content-manifest.example.json`](docs/content-manifest.example.json) | **官方题库包的清单**。应用首次启动按它下载题库包，普通用户不用管。 |
| [`docs/question-bank-format.md`](docs/question-bank-format.md) | **自定义题库的导入格式**。自己整理题库时看这个，可导入的完整示例见 [`docs/question-bank.example.json`](docs/question-bank.example.json)。 |

导入入口在「设置 → 导入题库」，里面两个选项：「选择 JSON 文件」直接导入，「查看格式与示例」给出必填字段与可复制的最小示例。

## 许可证与题库版权

- 代码以 [Apache License 2.0](LICENSE) 发布。
- 题库来源于公开数据的整理与汇总，权利归原出处所有。题库仅随 App 以个人学习用途提供，请勿转售或再分发。

## English

**Kuangshuati** ("Crazy Drills") is an offline-first Flutter app for practicing the aptitude section (行测 / xingce) of China's civil-service exam. No account, no sign-in, no analytics — your answers never leave your device. The full question bank (one-time in-app download, ~145 MB, SHA-256 verified) lives in local SQLite, and everything works fully offline afterwards: six practice modes, error review, mock exams with countdown auto-submit, cross-device backup via `.gkbackup` files. Source is open under Apache-2.0 — grab the Android APK from [Releases](https://github.com/xinghe-labs/kuangshuati/releases); a Web build is supported, and iOS compiles in CI (signed release pending).

---

## 🔗 Friend Links

- 🐧 [**LinuxDO**](https://linux.do)
