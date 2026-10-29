import 'dart:math';
import 'dart:typed_data';

import '../../domain/models.dart';
import 'content_repository.dart';

class SeedContentRepository implements ContentRepository {
  static const papers = <Paper>[
    Paper(
      id: 'demo-2026-national',
      title: '2026 国考行测演示卷',
      year: 2026,
      region: '国考',
      paperType: '副省级',
      durationSeconds: 7200,
    ),
    Paper(
      id: 'demo-2026-jiangsu',
      title: '2026 江苏省考行测演示卷',
      year: 2026,
      region: '江苏',
      paperType: '省考',
      durationSeconds: 7200,
    ),
    Paper(
      id: 'demo-2025-shandong',
      title: '2025 山东省考行测演示卷',
      year: 2025,
      region: '山东',
      paperType: '省考',
      durationSeconds: 7200,
    ),
    Paper(
      id: 'demo-2025-national',
      title: '2025 国考行测演示卷',
      year: 2025,
      region: '国考',
      paperType: '市地级',
      durationSeconds: 7200,
    ),
    Paper(
      id: 'demo-2024-zhejiang',
      title: '2024 浙江省考行测演示卷',
      year: 2024,
      region: '浙江',
      paperType: '省考',
      durationSeconds: 7200,
    ),
  ];

  static const questions = <QuestionContent>[
    QuestionContent(
      id: 'q-2026n-01',
      paperId: 'demo-2026-national',
      questionNo: 1,
      sequence: 1,
      module: '数量关系',
      stem: '甲、乙两车同时从相距 240 千米的两地相向而行，速度分别为每小时 55 千米和 45 千米。两车相遇需要多少小时？',
      options: {'A': '2.0', 'B': '2.4', 'C': '2.6', 'D': '3.0'},
      correctAnswers: {'B'},
      solution: '相向而行时使用速度和：240 ÷ (55 + 45) = 2.4 小时。',
    ),
    QuestionContent(
      id: 'q-2026n-02',
      paperId: 'demo-2026-national',
      questionNo: 2,
      sequence: 2,
      module: '言语理解',
      stem: '真正有效的复盘，不是把答案重新看一遍，而是找出当时做出错误判断的原因。这段话意在强调复盘应当：',
      options: {'A': '尽量缩短用时', 'B': '记住全部答案', 'C': '追溯错误决策过程', 'D': '优先重做难题'},
      correctAnswers: {'C'},
      solution: '转折后的“而是”引出重点，强调找出错误判断的原因，即追溯决策过程。',
    ),
    QuestionContent(
      id: 'q-2026n-03',
      paperId: 'demo-2026-national',
      questionNo: 3,
      sequence: 3,
      module: '判断推理',
      stem: '所有参加集训的队员都通过了体能测试，小林没有通过体能测试。由此可以确定：',
      options: {
        'A': '小林没有参加集训',
        'B': '小林参加了集训但没有通过测试',
        'C': '没有参加集训的队员都未通过测试',
        'D': '通过体能测试的队员都参加了集训',
      },
      correctAnswers: {'A'},
      solution: '“参加集训 → 通过测试”的逆否命题为“未通过测试 → 未参加集训”。',
    ),
    QuestionContent(
      id: 'q-2026n-04',
      paperId: 'demo-2026-national',
      questionNo: 4,
      sequence: 4,
      module: '常识判断',
      stem: '在标准大气压下，下列现象与物态变化对应正确的是：',
      options: {
        'A': '冰雪消融——凝固',
        'B': '露珠形成——液化',
        'C': '湿衣晾干——升华',
        'D': '霜的形成——融化',
      },
      correctAnswers: {'B'},
      solution: '空气中的水蒸气遇冷凝结成小水滴形成露珠，属于液化。',
    ),
    QuestionContent(
      id: 'q-2026j-01',
      paperId: 'demo-2026-jiangsu',
      questionNo: 1,
      sequence: 1,
      module: '资料分析',
      material: '某单位一季度完成项目 24 个，二季度完成 30 个，三季度完成 36 个。',
      stem: '若三季度项目数保持环比增速继续增长，四季度预计完成多少个项目？',
      options: {'A': '42', 'B': '43', 'C': '44', 'D': '45'},
      correctAnswers: {'B'},
      solution:
          '二季度环比增量为 6，三季度增量也为 6，增速由 25% 变为 20%，不能直接用增量外推。按三季度环比增速 20% 计算，36 × 1.2 = 43.2，选项中应结合整数口径选 43。',
    ),
    QuestionContent(
      id: 'q-2026j-02',
      paperId: 'demo-2026-jiangsu',
      questionNo: 2,
      sequence: 2,
      module: '判断推理',
      stem: '图形规律题中，正方形、圆形、三角形依次循环出现。第 100 个图形是什么？',
      options: {'A': '正方形', 'B': '圆形', 'C': '三角形', 'D': '无法确定'},
      correctAnswers: {'A'},
      solution: '三种图形循环，100 ÷ 3 余 1，因此第 100 个与第 1 个相同，是正方形。',
    ),
    QuestionContent(
      id: 'q-2025s-01',
      paperId: 'demo-2025-shandong',
      questionNo: 1,
      sequence: 1,
      module: '数量关系',
      stem: '一件商品先提价 20%，再打八折出售，最终价格与原价相比：',
      options: {'A': '提高 4%', 'B': '不变', 'C': '降低 4%', 'D': '降低 20%'},
      correctAnswers: {'C'},
      solution: '1 × 1.2 × 0.8 = 0.96，最终价格为原价的 96%，降低 4%。',
    ),
    QuestionContent(
      id: 'q-2025s-02',
      paperId: 'demo-2025-shandong',
      questionNo: 2,
      sequence: 2,
      module: '言语理解',
      stem: '城市更新不能只看短期面貌变化，还要关注公共空间是否持续可用。最适合作为这段文字标题的是：',
      options: {
        'A': '城市面貌的变化',
        'B': '公共空间的设计',
        'C': '城市更新要重长效',
        'D': '短期建设更有效率',
      },
      correctAnswers: {'C'},
      solution: '文段强调不能只看短期，还要看持续可用，核心是城市更新应注重长期效果。',
    ),
    QuestionContent(
      id: 'q-2025n-01',
      paperId: 'demo-2025-national',
      questionNo: 1,
      sequence: 1,
      module: '资料分析',
      material: '某地区 2023 年粮食产量为 500 万吨，2024 年同比增长 8%。',
      stem: '2024 年该地区粮食产量约为多少万吨？',
      options: {'A': '508', 'B': '520', 'C': '532', 'D': '540'},
      correctAnswers: {'D'},
      solution: '500 × (1 + 8%) = 540 万吨。',
    ),
    QuestionContent(
      id: 'q-2025n-02',
      paperId: 'demo-2025-national',
      questionNo: 2,
      sequence: 2,
      module: '常识判断',
      stem: '下列关于我国国家制度表述正确的是：',
      options: {
        'A': '全国人民代表大会每届任期四年',
        'B': '宪法具有最高的法律效力',
        'C': '行政法规由全国人大常委会制定',
        'D': '地方性法规不得规定本行政区域事务',
      },
      correctAnswers: {'B'},
      solution: '宪法是国家的根本法，具有最高的法律效力。',
    ),
    QuestionContent(
      id: 'q-2024z-01',
      paperId: 'demo-2024-zhejiang',
      questionNo: 1,
      sequence: 1,
      module: '判断推理',
      stem: '甲比乙高，乙比丙高，丁比甲高。下列一定正确的是：',
      options: {'A': '丁比乙高', 'B': '乙比丁高', 'C': '丙比甲高', 'D': '甲比丁高'},
      correctAnswers: {'A'},
      solution: '丁高于甲，甲高于乙，因此丁一定高于乙。',
    ),
    QuestionContent(
      id: 'q-2024z-02',
      paperId: 'demo-2024-zhejiang',
      questionNo: 2,
      sequence: 2,
      module: '数量关系',
      stem: '某班男生与女生人数比为 3:2，转入 5 名女生后人数相等。原来女生有多少人？',
      options: {'A': '10', 'B': '12', 'C': '15', 'D': '18'},
      correctAnswers: {'A'},
      solution: '设男、女生分别为 3x、2x。3x = 2x + 5，得 x = 5，原女生为 10 人。',
    ),
  ];

  List<Paper> get allPapers => List.unmodifiable(papers);

  List<QuestionContent> get allQuestions => List.unmodifiable(questions);

  @override
  Paper? findPaper(String id) {
    for (final paper in papers) {
      if (paper.id == id) return paper;
    }
    return null;
  }

  @override
  QuestionContent? findQuestion(String id) {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  @override
  List<QuestionContent> questionsForPaper(String paperId) {
    return questions.where((question) => question.paperId == paperId).toList();
  }

  @override
  List<Paper> searchPapers({String query = '', int? year}) {
    final normalized = query.trim().toLowerCase();
    return papers.where((paper) {
      final matchesYear = year == null || paper.year == year;
      final matchesQuery =
          normalized.isEmpty ||
          paper.title.toLowerCase().contains(normalized) ||
          paper.region.toLowerCase().contains(normalized);
      return matchesYear && matchesQuery;
    }).toList();
  }

  @override
  List<Paper> recentPapers({int limit = 5}) {
    return [...papers]
      ..sort((a, b) {
        final yearOrder = b.year.compareTo(a.year);
        return yearOrder != 0 ? yearOrder : a.title.compareTo(b.title);
      })
      ..take(limit).toList();
  }

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    return [for (final id in ids) ?findQuestion(id)];
  }

  @override
  List<QuestionContent> randomQuestions(int count, {String? module}) {
    final pool = questions
        .where((question) => module == null || question.module == module)
        .toList();
    pool.shuffle(Random(42));
    return pool.take(count).toList(growable: false);
  }

  @override
  List<QuestionContent> sequenceQuestions({int limit = 100}) {
    return questions.take(limit).toList(growable: false);
  }

  @override
  Uint8List? imageBytes(String assetId) => null;

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};

  @override
  ContentStats stats() {
    return const ContentStats(
      questionCount: 12,
      paperCount: 5,
      imageCount: 0,
      contentVersion: 'demo',
    );
  }

  @override
  Future<void> close() async {}
}
