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

<sub>真机 release 构建截图，不是原型图。</sub>

## 下载安装

不想编译源码？直接从 [Releases](https://github.com/xinghe-labs/kuangshuati/releases) 下载最新 APK（当前 v1.0.8）。首次启动在应用内下载题库（约 145 MB，分片下载 + SHA-256 校验），之后全程离线。

## 功能

- **真离线**：58,890 道题、515 套试卷、39,196 张题图存进本地 SQLite（约 297 MB），装好题库断网可用。
- **六种练习入口**：顺序、随机、试卷、错题复习、自定义组卷、整卷模考；逐题解析或交卷后统一出解析。
- **完整闭环**：作答 → 判题 → 解析 → 结果 → 错题入册 → 到期复习；中断后能接着上次的进度继续。
- **统计与备份**：作答统计、最近练习正确率、跨端 `.gkbackup` 备份与恢复（原生端与 Web 端互导已实测）。
- **体验细节**：资料分析题图内联排版、深色模式跟随系统、键盘作答与快捷键、模考倒计时自动交卷。
- **本地优先**：没有账号体系、没有云同步、没有第三方埋点 SDK。

## 快速开始

```bash
git clone <repo>
cd app
flutter pub get
flutter run          # 首次启动自动下载题库（约 145 MB），之后离线
```

- 拿不到题库时（离线或下载失败），debug 构建回落到内置 12 道演示题，先把交互跑通；`--dart-define=KUANGSHUATI_DEMO=false` 可关闭兜底。
- 要用自己的题库：清单格式见 [`docs/content-manifest.example.json`](docs/content-manifest.example.json)，运行时用 `--dart-define=CONTENT_MANIFEST_URL=https://your-host/content-manifest.json` 指向你的清单；题库生成工具未随开源发布。
- Web 端：`app/web` 保留完整的 Flutter Web 壳（OPFS + SQLite WASM），部署时需静态服务器带 `Cross-Origin-Opener-Policy: same-origin` 与 `Cross-Origin-Embedder-Policy: require-corp` 响应头。

## 架构

```text
app/
  lib/data/content/     内容库读取：分片安装、只读 SQLite、题图 BLOB
  lib/data/database/    用户数据（作答、错题、收藏、笔记）—— drift，与内容库物理隔离
  lib/features/         首页 / 题库 / 练习 / 错题 / 统计 / 设置
```

几个刻意的取舍：内容库与用户库分离，换题库不动作答记录；题库按 16 MiB 分片并发下发，避免一次性把 297 MB 读进内存；不做账号和云同步，用本地文件备份替代，省掉一整套服务端和隐私面。

## 测试与 CI

```bash
cd app
flutter analyze && flutter test    # 126 个测试通过
```

覆盖组件渲染、数据库、备份恢复、多选题判分、演示题库兜底等回归用例。依赖真实题库分片的集成测试在拿不到分片时自动跳过，CI 无需任何私有资源或密钥（配置见 `.github/workflows/ci.yml`）。

## 题库来源与授权（请先读这条）

- **本仓库只开源代码，不包含题库数据**——仓库里没有任何一道真实题目的正文、解析或题图；App 首次启动从作者的内容源下载题库包。
- 题目为公考真题的网友回忆整理，题目与解析的权利归原出处；**本项目未取得原出处的公开分发授权**，题库仅供 App 内个人学习使用，请勿转售或再分发。

## 已知限制

- **iOS**：仅编译验证（无签名与真机包）；**Windows 桌面**：未验证。
- **Web 端**：首次要装约 187 MB 核心题库，弱网体验一般；OPFS 可能被浏览器清理。
- **演示题库**：仅 12 道题，只用于跑通交互，不能评估做题体验。
- **图片类题目**：题库里 2 张源图缺失，保留缺图状态而不是静默删题。

## 许可证

代码以 [Apache License 2.0](LICENSE) 发布；题库数据不在许可范围内（见上节）。
