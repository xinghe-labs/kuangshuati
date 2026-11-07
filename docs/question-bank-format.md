# 自定义题库导入格式

狂刷题支持从本地 JSON 文件导入自制题库（设置 → 题库与数据 → 导入题库）。
导入后题库与官方下载包完全等价：练习、模考、错题本、搜索全部可用，全程离线。

## 文件要求

- 单个 `.json` 文件，UTF-8 编码。
- 建议单文件不超过 128 MB（题库很大时请拆成多个小题库分次导入）。
- 图片以 base64 内嵌在 JSON 里（见下文「images」）。

## 顶层结构

```json
{
  "format": "kuangshuati-bank",
  "formatVersion": 1,
  "name": "我的题库",
  "contentVersion": "my-bank-2026-02",
  "papers": [ … ],
  "images": { … }
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `format` | ✅ | 固定为 `"kuangshuati-bank"` |
| `formatVersion` | ✅ | 固定为 `1` |
| `name` | ❌ | 题库显示名，导入完成后展示；缺省用「自定义题库」 |
| `contentVersion` | ❌ | 内容版本号（设置页「离线题库」里显示）；缺省自动生成 `custom-<时间戳>` |
| `papers` | ✅ | 试卷数组，至少一份 |
| `images` | ❌ | 图片字典：`图片ID → {mime, data}`，供题干/选项/材料内嵌 |

## papers[ ]

```json
{
  "id": "2025-guokao-xingce",
  "title": "2025 年度国考行测",
  "year": 2025,
  "region": "国家",
  "paperType": "行测",
  "durationSeconds": 7200,
  "questions": [ … ]
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | ✅ | 试卷唯一 ID，全库不可重复 |
| `title` | ✅ | 试卷标题（试卷列表按它搜索） |
| `year` | ❌ | 年份整数，用于排序筛选；缺省 `0` |
| `region` | ❌ | 地区（国考 / 江苏 / …）；缺省 `未知` |
| `paperType` | ❌ | 卷种；缺省 `行测` |
| `durationSeconds` | ❌ | 模考倒计时秒数；缺省 `7200`（2 小时） |
| `questions` | ✅ | 题目数组，至少一题 |

## papers[].questions[ ]

```json
{
  "id": "q-0001",
  "module": "判断推理",
  "type": "单选",
  "questionNo": 1,
  "groupId": "grp-1",
  "material": "材料文本……",
  "stem": "题干文本，支持 [[img:tu-1]] 内嵌图片",
  "stemText": "可选：检索用纯文本，缺省自动生成",
  "options": { "A": "选项 A", "B": "选项 B", "C": "选项 C", "D": "选项 D" },
  "answer": ["A"],
  "solution": "解析文本"
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | ✅ | 题目唯一 ID，全库不可重复 |
| `module` | ❌ | 模块名，建议用：言语理解与表达 / 数量关系 / 判断推理 / 资料分析 / 常识判断；缺省 `综合`。分类统计按它聚合 |
| `type` | ❌ | 题型备注（单选 / 多选…）；缺省空 |
| `questionNo` | ❌ | 原卷题号；缺省按文档顺序自动编号 |
| `groupId` | ❌ | 材料组 ID：同组题共享材料，随机练习按**整组**抽取；无材料留空或不填 |
| `material` | ❌ | 本题的材料文本（同组题每题各自填写）；缺省无材料 |
| `stem` | ✅ | 题干 |
| `stemText` | ❌ | 搜索用的纯文本题干；缺省自动由 `stem` 去掉图片标记生成 |
| `options` | ✅ | 选项字典：`A/B/C/D/… → 选项文本`，至少一项 |
| `answer` | ✅ | 正确答案数组，如 `["A"]`、多选 `["A","C"]`；每项必须是 `options` 的键 |
| `solution` | ❌ | 解析；缺省空 |

## 文本约定

- 纯文本，`\n` 表示换行；**不要**写 HTML。
- 内嵌图片：在 `stem` / `options` 值 / `material` / `solution` 的任意位置写
  `[[img:图片ID]]`，导入后渲染为对应图片（见 `docs/question-bank.example.json`）。

## images

```json
{
  "tu-1": { "mime": "image/png", "data": "iVBORw0KGgo…（base64）" }
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `mime` | ❌* | 图片类型；`data` 写的是 `data:image/webp;base64,…` 前缀时可以省略 |
| `data` | ✅ | 图片内容：裸 base64，或带 `data:<mime>;base64,<…>` 前缀 |

支持 PNG / JPEG / GIF / WebP；无法识别尺寸的图片会被标记为不可用（不渲染，不影响文字）。
图片按内容哈希去重：多张相同 `data` 只存一份。

## 导入行为

- 导入**替换**当前离线题库（官方包或上次导入的题库），练习记录、错题本、收藏、笔记、统计**全部保留**。
- 导入在本地完成，不联网。
- 导入后随时可在「离线题库」页重新下载官方题库覆盖回来。
- 校验失败会指出具体位置（如 `papers[2].questions[5].answer`），不会破坏现有题库。
