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

不想编译源码？直接从 [Releases](https://github.com/xinghe-labs/kuangshuati/releases) 下载最新 APK（当前 v1.0.8）。首次启动在应用内下载题库（约 145 MB），之后全程离线。

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
flutter run
```

## 许可证

代码以 [Apache License 2.0](LICENSE) 发布。题库数据不在本仓库内，也不在许可范围内。
