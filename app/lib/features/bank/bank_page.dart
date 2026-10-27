import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

class BankPage extends ConsumerStatefulWidget {
  const BankPage({super.key});

  @override
  ConsumerState<BankPage> createState() => _BankPageState();
}

class _BankPageState extends ConsumerState<BankPage> {
  final _searchController = TextEditingController();
  var _scope = _BankScope.papers;
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageIntro(title: '题库', description: '按试卷练习，或从收藏中挑出需要反复看的题。'),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: _scope == _BankScope.papers ? '搜索年份、地区或试卷' : '搜索收藏题目',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_BankScope>(
          segments: const [
            ButtonSegment(
              value: _BankScope.papers,
              label: Text('试卷'),
              icon: Icon(Icons.description_outlined, size: 17),
            ),
            ButtonSegment(
              value: _BankScope.favorites,
              label: Text('收藏'),
              icon: Icon(Icons.bookmark_outline, size: 17),
            ),
          ],
          selected: {_scope},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() => _scope = selection.first);
          },
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _scope == _BankScope.papers
              ? _PaperList(
                  key: const ValueKey('papers'),
                  query: _query,
                  onStart: _startPaper,
                )
              : _FavoriteList(
                  key: const ValueKey('favorites'),
                  query: _query,
                  onStart: _startFavorite,
                ),
        ),
      ],
    );
  }

  Future<void> _startPaper(Paper paper, {bool mock = false}) {
    return launchPractice(
      context,
      ref,
      mode: mock ? PracticeMode.mock : PracticeMode.paper,
      title: mock ? '${paper.title} · 模考' : paper.title,
      questions: ref
          .read(contentRepositoryProvider)
          .questionsForPaper(paper.id),
      paperId: paper.id,
      revealMode: mock ? RevealMode.afterSubmit : RevealMode.immediate,
      timeLimitSeconds: mock ? paper.durationSeconds : null,
    );
  }

  Future<void> _startFavorite(List<QuestionContent> questions) {
    return launchPractice(
      context,
      ref,
      mode: PracticeMode.custom,
      title: '收藏题目练习',
      questions: questions,
    );
  }
}

enum _BankScope { papers, favorites }

class _PaperList extends ConsumerWidget {
  const _PaperList({required this.query, required this.onStart, super.key});

  final String query;
  final Future<void> Function(Paper paper, {bool mock}) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papers = ref
        .read(contentRepositoryProvider)
        .searchPapers(query: query);
    if (papers.isEmpty) {
      return const AppEmptyState(title: '没有匹配的试卷', message: '换一个年份、地区或试卷名称试试。');
    }
    return Column(
      children: [
        for (final paper in papers) ...[
          _PaperRow(paper: paper, onStart: onStart),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({required this.paper, required this.onStart});

  final Paper paper;
  final Future<void> Function(Paper paper, {bool mock}) onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => onStart(paper),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 58,
                alignment: Alignment.center,
                color: AppColors.ink,
                child: Text(
                  '${paper.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${paper.region} · ${paper.paperType} · 120 分钟',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '选择练习方式',
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) => onStart(paper, mock: value == 'mock'),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'practice', child: Text('普通练习')),
                  PopupMenuItem(value: 'mock', child: Text('整卷模考')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteList extends ConsumerWidget {
  const _FavoriteList({required this.query, required this.onStart, super.key});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return favorites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('读取收藏失败：$error'),
      data: (items) {
        final repository = ref.read(contentRepositoryProvider);
        final normalized = query.trim().toLowerCase();
        final questions = [
          for (final item in items)
            if (repository.findQuestion(item.questionId) case final question?)
              if (normalized.isEmpty ||
                  question.stem.toLowerCase().contains(normalized))
                question,
        ];
        if (questions.isEmpty) {
          return AppEmptyState(
            title: query.isEmpty ? '还没有收藏题目' : '没有匹配的收藏',
            message: query.isEmpty ? '做题时点一下书签，题目会出现在这里。' : '换一个题干关键词试试。',
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => onStart(questions),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('练习全部 ${questions.length} 题'),
              ),
            ),
            const SizedBox(height: 10),
            HairlineList(
              children: [
                for (final question in questions)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    title: Text(
                      question.stem,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${question.module} · 第 ${question.questionNo} 题',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: '取消收藏',
                      onPressed: () => ref
                          .read(databaseProvider)
                          .toggleFavorite(question.id),
                      icon: const Icon(
                        Icons.bookmark,
                        size: 20,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
