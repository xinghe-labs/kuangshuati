# 安全策略

## 报告方式

**不要开公开 Issue。** 用 GitHub 的私密渠道：

[新建安全公告](https://github.com/xinghe-labs/kuangshuati/security/advisories/new)

如果那个入口不可用，可以先开一个 Issue 只写「有一个安全问题，请给我一个私密
联系方式」，不要写细节。

## 这个项目不承诺什么

先说清楚，省得白忙。以下都是**设计如此**，不是漏洞：

| 现象 | 为什么不算漏洞 |
| --- | --- |
| 直接读取 App 的 SQLite 能拿到答案 | 离线刷题必须把答案存在本地。安全目标只有「交卷前 UI 不渲染答案」 |
| 备份文件 `.gkbackup` 没有加密 | 它是 gzip 的 JSON，由用户自己保管。加密意味着要管密钥，与本项目「不引入账号体系」冲突 |
| APK 可以被反编译 | 代码本来就是 Apache-2.0 公开的 |
| 题库清单和题库包地址是公开的 | 有意为之，见 [self-host-content.md](docs/self-host-content.md) |
| 模拟器 / root 设备上能篡改数据 | 不设防，这不是防作弊产品 |

## 值得报告的问题

- **网络层**：HTTPS 校验被绕过、`CONTENT_MANIFEST_URL` 被降级为 http、
  HTTP 代理配置被用来劫持题库下载。
- **题库包导入**：恶意 `content-manifest.json` 或 `.sqlite.gz` 能造成
  **任意文件写入 / 路径穿越 / 覆盖用户数据**，或在校验失败时仍然安装。
  校验逻辑在 `app/lib/features/content/content_package_service.dart`，
  预期是 packageSha256、databaseSha256 与实际字节逐项比对。
- **备份导入**：`.gkbackup` 导入能越出应用数据目录写文件，或用畸形数据
  损坏数据库。解析逻辑在 `app/lib/features/backup/backup_service.dart`。
- **JSON 题库导入**：同上的路径穿越 / 资源耗尽问题，
  见 `app/lib/features/content/content_import_service.dart`。
- **数据丢失**：升级、清空记录、备份恢复流程中导致用户作答记录不可恢复的
  缺陷（这类请按 Bug 走 Issue，但涉及数据损坏请同时告知）。

## 响应预期

这是一个个人维护的项目，没有 SLA。能承诺的是：私密渠道来的报告会**优先于**
公开 Issue 处理，确认后会先在修复版本里解决，再考虑是否公开讨论。

## 支持的版本

只处理当前最新发布版本的问题（见 [README](README.md#下载安装) 与
[Releases](https://github.com/xinghe-labs/kuangshuati/releases)）。
旧版本的问题请先升级后复现。
