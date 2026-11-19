# iOS 安装：未签名 ipa + 自行签名

本项目**不提供**签名好的 iOS 安装包。GitHub Actions 只负责在 macOS 上编译，产出一个**未签名 ipa**；把它装进 iPhone 这一步需要你用**自己的 Apple ID** 完成签名。

- 想了解为什么这样分工、以及不这么做的替代方案，见 [README 的 iOS 小节](../README.md)。
- 本文只讲操作：从拿到 ipa 到装进手机、到期续签、出问题怎么查。

## 前提

| 项 | 要求 |
| --- | --- |
| iPhone 系统 | iOS 14.0 及以上（`app/ios/Runner.xcodeproj/project.pbxproj` 里 `IPHONEOS_DEPLOYMENT_TARGET = 14.0`） |
| 电脑 | Windows 或 macOS（Linux 需额外配 usbmuxd，不推荐首次尝试） |
| 账号 | 一个能登录的 Apple ID，**免费账号即可**，不需要开发者付费 |
| 网络 | 装完之后首次启动要联网下载题库（约 145 MB） |

免费 Apple ID 的签名有硬性限制，这些是 Apple 的规则、绕不过去：

- 签名 **7 天**后失效，App 打不开，需要重签；
- 同一台设备最多同时存在 **3 个**自签 App；
- 每 7 天最多注册 10 个 App ID（反复改 bundle id 会撞上这条）。

## 第一步：拿到未签名 ipa

触发构建，两种方式任选：

- **自动**：向 `main` 推送改动，只要碰到 `app/ios/**`、`app/lib/**`、`app/pubspec.yaml`、`.github/workflows/ios-build.yml` 之一就会触发；
- **手动**：GitHub → Actions → 「iOS Build Check」→ Run workflow。

等它跑完（约 15–30 分钟）后拿包，ipa 和 APK 在**同一个版本 Release** 里（匿名可下，不需要 GitHub 账号）：打开 [Releases](https://github.com/xinghe-labs/kuangshuati/releases)，点 `v1.1.2`，下载 `kuangshuati-1.1.2-12-unsigned.ipa`。备选：run 页面底部的 **Artifacts** → `ios-unsigned-ipa-1.1.2-12`（这条需要登录 GitHub，只当备用）。

**这个 ipa 不能直接拖进手机**，iOS 会拒绝安装未签名的 App。

## 第二步：在电脑上签名并安装

以 [Sideloadly](https://sideloadly.io/) 为例（Windows / macOS 都有）：

1. 安装 Sideloadly。Windows 首次运行会提示安装 Apple 驱动（iTunes 组件），按提示装完再重启 Sideloadly。
2. 数据线连上 iPhone，手机上点「信任此电脑」，Sideloadly 顶部出现设备信息即连接成功。
3. 把 ipa 拖进 Sideloadly 的 IPA 框。
4. Apple ID 填自己的账号，点 **Start**。密码由 Sideloadly 直接提交给 Apple 验证，不经过第三方服务器；开了双重认证的话会提示你输入验证码。
5. 看到 `Done` 即安装完成。

> **不要**随手勾选「Change Bundle ID」。改了 bundle id 等于换了一个 App，原来的作答记录读不到。只有在提示 bundle id 冲突、装不上时才考虑，并接受数据不互通。

替代工具：macOS 上也可以用 Xcode（打开 `app/ios/Runner.xcworkspace`，选自己的 Team 后直接 Run 到设备）。iPhone 端的 [AltStore](https://altstore.io/) / [SideStore](https://sidestore.io/) 可以做到「不插电脑续签」，但首次配置更麻烦，建议先用 Sideloadly 跑通。

## 第三步：iPhone 上放行

不做完这两步，App 会闪退或提示「无法验证 App」：

1. **开发者模式**（iOS 16 及以上）：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机 → 重启后确认开启。
2. **信任开发者**：设置 → 通用 → VPN 与设备管理 → 在「开发者 App」下点你的 Apple ID → 信任。

如果仍然提示「无法验证 App」：先断网（飞行模式）打开一次 App，再恢复联网。

## 第四步：首次启动下载题库

ipa 里**不含题库**（这也是它能公开分发的原因）。第一次打开会下载约 145 MB 的题库包，校验 SHA-256 后导入本地 SQLite，之后全程离线。

下载失败通常是网络问题，不是签名问题；换个网络重试即可。

## 续签（每 7 天）

签名过期后 App 图标还在，但点开就闪退。处理方式：

1. 电脑上打开 Sideloadly，连手机；
2. 把**同一个 ipa** 再拖进去，Start 一次；
3. 手机上的 App 和数据都在，不需要重新下载题库。

因为 bundle id 不变，属于覆盖安装，App 内的作答记录、错题本、练习进度通常会保留。但**别赌**：安装完第一次就做一次备份（设置 → 备份，导出 `.gkbackup` 存到「文件」App 或电脑），升级或重签前也备份一次。

## 升级到新版本

iOS 端**不能在应用内安装更新**（只装签名包，自签还 7 天过期），但能**发现新版本**：启动时和设置页「检查更新」都会读同一份 [update-manifest.json](https://kuangshuati.124145.xyz/update-manifest.json)，有新版本就弹窗，「去下载」会打开 [Releases](https://github.com/xinghe-labs/kuangshuati/releases) 让你下新 ipa（打不开浏览器时自动把链接复制到剪贴板）。版本比较用的是 `Info.plist` 里的 `CFBundleVersion`，即 pubspec 的 `+N`。

升级流程：

1. 等新版本 CI 跑完，下载新的 `kuangshuati-<新版本>-unsigned.ipa`；
2. 先导出一次 `.gkbackup` 备份；
3. Sideloadly 用新 ipa 覆盖安装（同一个 Apple ID）；
4. 打开后确认数据还在，必要时用备份恢复。

## 常见问题

| 现象 | 原因与处理 |
| --- | --- |
| 点开立刻闪退 | 证书过期，按上面「续签」重签 |
| 「无法验证 App」 | 没信任开发者，或没开开发者模式；也试一次断网启动 |
| 安装报 `maximum number of apps for free development profiles has been reached` | 免费账号同时最多 3 个自签 App，删掉不用的再装 |
| 安装报 App ID 数量超限 | 免费账号每 7 天最多注册 10 个 App ID，等一周，别反复改 bundle id |
| 题库下载卡住 / 失败 | 网络问题；换个网络重试，与签名无关 |
| 装了但数据是空的 | 之前改过 bundle id，或换了 Apple ID 签名；用 `.gkbackup` 恢复 |

## 明确不提供的东西

- 开发者证书（`.p12`）、provisioning profile、别人的签名服务；
- 带签名的 ipa、TestFlight 或 App Store 版本。

共享证书属于违规使用开发者账号，也会让你的设备暴露在他人控制之下。只用自己的 Apple ID 签名。

## 已知未验收项

iOS 侧目前只有 **CI 编译通过** 的证据，没有真机验收记录（见 [`docs/development-plan.md`](development-plan.md) 的验收清单）。首次在真机上跑，建议按下面顺序过一遍，发现问题请开 issue 并附上现象：

1. 首次启动 → 下载题库 → 完成后断网打开，确认能离线刷题；
2. 顺序练习 + 逐题解析，含带图表的资料分析题（题图内联排版）；
3. 整卷模考 → 倒计时 → 交卷统一判分；
4. 错题本、到期复习；
5. 设置 → 备份导出 `.gkbackup` → 删 App 重装 → 导入恢复；
6. 深色模式、后台切回后计时是否连续。
