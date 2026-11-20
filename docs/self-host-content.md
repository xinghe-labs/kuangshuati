# 自托管题库源

本项目的**代码**与**题库**是分开的两件事：

- **代码**：Apache-2.0，在本仓库。
- **官方题库包**：不在本仓库。App 首次启动时从
  `https://kuangshuati.124145.xyz/content-manifest.json` 下载（约 145 MB，
  gzip 后），SHA-256 校验通过才安装。

如果你 fork 了这个项目、或者想给一群人部署，**不应该依赖作者的服务器**。
下面两条路，按成本从低到高。

---

## 路 1：导入 JSON 题库（无需服务器，先试这条）

App 内「设置 → 导入题库 → 选择 JSON 文件」可以直接导入自己整理的题库，
与官方题库并存，不动已有练习记录。

- 字段说明：[question-bank-format.md](question-bank-format.md)
- 可复制的最小示例：[question-bank.example.json](question-bank.example.json)
- 导入器实现（可审计）：`app/lib/features/content/content_import_service.dart`

这条路的适用面比看上去宽：只要题库能整理成 JSON，就不需要打包成 SQLite，
也不需要任何托管。缺点是图片题需要图片在本地可访问，且全量大数据集启动解析较慢。

---

## 路 2：换掉默认下载源

App 读取清单的地址是**编译期常量**，所以构建时覆盖即可，不必改代码：

```dart
// app/lib/features/content/content_package_service.dart
const contentManifestUrl = String.fromEnvironment(
  'CONTENT_MANIFEST_URL',
  defaultValue: 'https://kuangshuati.124145.xyz/content-manifest.json',
);
```

构建命令：

```bash
cd app
flutter build apk --release \
  --dart-define=CONTENT_MANIFEST_URL=https://你的域名/content-manifest.json \
  --dart-define=APP_VERSION_CODE=14
```

**`APP_VERSION_CODE` 必须传。** 未注入时它的默认值是 `0`，表示「版本未知」，
此时客户端**跳过** `minimumAppVersionCode` 门槛检查（否则忘传 define 的正常构建
会被远程清单永久挡住，用户看到「版本过低」却无从更新）。要考这个门槛，
就得同时注入真实 versionCode。

---

## 清单要求

字段与含义以 [content-manifest.example.json](content-manifest.example.json) 为准。
客户端 `ContentPackageManifest.parse()` 的硬校验：

| 字段 | 要求 |
| --- | --- |
| `packageUrl` | 必须是 `https`（网络清单） |
| `packageSha256` / `databaseSha256` | 必须正好 64 位十六进制 |
| `packageBytes` / `databaseBytes` | 必须 > 0 |
| `questionCount` / `paperCount` | 必须 > 0 |
| `imageCount` / `minimumAppVersionCode` | 必须 ≥ 0 |

两组字节数和 SHA-256 指的不是同一份东西，别填反：

- `packageBytes` / `packageSha256` —— **gzip 之后**的包（网络传输的那份）
- `databaseBytes` / `databaseSha256` —— **解压之后**的 SQLite 文件

示例里两个 SHA-256 是 `0000…` 占位，能通过解析，但下载后必然校验失败。
换成你自己文件的真实值。

---

## 服务器要求

客户端是**分片并发下载**的，不是整包 GET。以下几条硬性要求：

1. **必须支持 HTTP Range，且返回 `206 Partial Content`。**
   客户端发 `Range: bytes=<start>-<end>`，收到非 206 会直接报
   「题库服务器不支持分段下载：HTTP xxx」。静态文件服务器和主流 CDN 默认满足；
   某些反向代理或网盘直链不满足。
2. **`packageBytes` 必须精确**。下载进度按已收字节数除以它来算，
   分片边界也按它切。填大了会卡在 99%，填小了会报「题库分片大小超出清单」。
3. **HTTPS**。清单里的 `packageUrl` 强制 https。
4. 单连接读超时 20 秒、连接超时 15 秒，失败重试 4 次——大文件请放 CDN 或支持
   长连接的静态服务器。

分片策略（`content_package_service.dart`）：最小片 6 MB，最多 24 片，
最多 16 个并发连接。所以 145 MB 的包会自动切成 24 片并发拉。

断点续传靠本地 `download.json` 记录 `packageSha256` / `packageBytes` / 分片数，
三者与当前清单一致才续传，否则整目录重下。

---

## 已知限制：生成 `.sqlite.gz` 的流水线不在公开视图里

本仓库的公开视图不包含题库构建与上传脚本（题库管线、发布基建被有意剔除），
所以「从原始题库素材构建出一个 `content.sqlite.gz`」这一步**无法仅凭公开仓库完成**。

公开可用的完整内容是：

- 自定义题库的 JSON 导入（路 1，端到端可用）
- 题库清单格式与示例
- 客户端的下载、校验、安装、续传逻辑（全部可审计）

如果你要自建完整包，需要自己产出 `content.sqlite.gz` 并写清单。
客户端的数据库 schema 在 `app/lib/data/database/`，它会直接打开你提供的
SQLite 文件并读 `questions` / `papers` 等表——schema 是最直接的那份约定。

这条限制如果挡住了你的用法，开个 Issue 说明场景，比自己猜 schema 强。
