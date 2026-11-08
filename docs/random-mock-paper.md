# 方案：随机组卷模考（随机按模块配比组一套整卷，限时模考）

状态：待用户确认，未实施。日期：2026-11-08。

## 需求

从题库随机抽题，按模块配比组装一套整卷，以限时模考形式练习：
交卷后统一判分。练完即散，不保存卷子（与「随机 20 题」同一哲学）。

## 现有基础（已核实）

- `randomQuestions(count, {module})` 已实现且**材料组完整抽题**
  （整组不拆散、超大组降级单题，见 `app/lib/data/content/sql_content_repository.dart:170`），
  支持单模块过滤 —— 配比组卷最难的部分已就绪，逐模块调用即可，**无需改 SQL 层**。
- `launchPractice` 已支持 `mode / timeLimitSeconds / revealMode / requestedCount`
  （`app/lib/features/practice/practice_launcher.dart:14`）。
- `PracticeMode.mock` 全链路已通：整卷倒计时 + 分模块时间预算
  （`app/lib/features/practice/time_budget.dart:16` `moduleBudgetsSeconds` 自动按模块题数占比分摊）、
  交卷统一判分（`result_page.dart:94`）、模考强制 afterSubmit。
- 错题入账与 mode 无关（`app/lib/data/database/app_database.dart:745-750, 1062`），
  模考答错的题自动进错题本，无需额外处理。

## 设计

### 配比规则（不写死模块名）

题库 module 字段允许自定义（缺省「综合」，见 `docs/question-bank-format.md`），
写死「言语 40 / 数量 10 …」会匹配不上。改为数据驱动，两种配比：

1. **真题结构**（默认）：一次 `GROUP BY module` 取题库各模块总量占比，
   按占比把目标题量分给各模块（**最大余数法**保证总数精确等于目标题量）。
   题库主体是真题，其自然分布即真题结构；换题库也自适应。
2. **均匀分配**：各模块平均分（同样最大余数法凑齐）。

### 缺口处理

某模块可抽题数 < 配额时（材料组剔除后可能更少），
缺口按其余模块的占比一轮再分配；整体凑不齐目标题量时，
配置面板确认前提示「本次仅能组成 N 题」。

### 抽题与组卷

- 逐模块调用 `randomQuestions(quota, module: m)`，合并；
- 合并后按题库模块出现顺序排序（材料组内已按 sequence/question_no 排好），
  重编 sequence 为 1..N；
- 时长折算：**60 秒/题**（对齐主流省考 120 分钟/120 题的节奏），
  130 题卷 = 130 分钟。向上取整到 5 分钟。

### 模考启动

```dart
launchPractice(
  mode: PracticeMode.mock,
  title: '随机模考 · $total 题',
  questions: assembled,
  revealMode: RevealMode.afterSubmit,
  timeLimitSeconds: duration,
  requestedCount: total,
)
```

`paperId` 传 null（非真题卷）；分模块时间预算由 `moduleBudgetsSeconds`
按实际抽题结果自动计算，无需干预。

### 入口与 UI

- 入口：**首页**（与现有刷题入口同级；首页刚定稿不改版，本入口仅是新增一个功能入口，不动整体布局）。
- UI：bottom sheet，两个选项 + 确认：
  - 题量：105 / 120 / 130（默认 130）
  - 配比：真题结构（默认）/ 均匀分配
  - 确认行显示「将组 N 题 · 限时 M 分钟」（含缺口重算后的真实题量）。

## 改动清单

| 文件 | 改动 |
|---|---|
| `app/lib/features/practice/mock_paper.dart` | 新增纯函数：`moduleQuotas`（占比→最大余数配额）、`redistributeShortfall`（缺口再分配）、`durationForQuestions`；无 UI 无 IO，便于单测 |
| `app/lib/features/practice/practice_launcher.dart` | 新增 `launchRandomMock(...)`：拉模块分布 → 算配额 → 逐模块抽题 → 组卷 → 走现有 `launchPractice`；复用 `describeContentError` 错误处理 |
| `app/lib/features/home/home_page.dart` | 首页入口 + bottom sheet（或独立 `random_mock_sheet.dart`） |
| SQL / 仓库接口 / web / seed 仓库 | **不动**（纯组合现有 `randomQuestions`） |

测试：
- `mock_paper_test.dart`：配额精确凑齐、缺口再分配、时长折算边界；
- `random_mock_sheet` widget test：默认值、确认传参；
- 手动验收：真机组卷 → 模考 → 交卷 → 错题本核对。

## 不做（本期）

- 卷子保存 / 重刷（练完即散）
- 自定义配比滑杆
- 年份 / 地区 / 题型细分筛选（后续可在 sheet 加条件，管道不变）

## 工作量

约 1 天实现 + 测试。
