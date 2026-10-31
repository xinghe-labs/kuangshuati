import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart' show Favorite;
import '../../domain/models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../practice/practice_launcher.dart';

/// 全量试卷列表，进程内缓存一次；搜索在内存里过滤。
final papersProvider = FutureProvider<List<Paper>>((ref) {
  return ref.watch(contentRepositoryProvider).searchPapers();
});

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
    final normalized = _query.trim().toLowerCase();
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageIntro(
                  title: '题库',
                  description: '按试卷练习，或从收藏中挑出需要反复看的题。',
                ),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: switch (_scope) {
                      _BankScope.papers => '搜索年份、地区或试卷',
                      _BankScope.favorites => '搜索收藏题目',
                      _BankScope.notes => '搜索笔记内容',
                    },
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
                    ButtonSegment(
                      value: _BankScope.notes,
                      label: Text('笔记'),
                      icon: Icon(Icons.sticky_note_2_outlined, size: 17),
                    ),
                  ],
                  selected: {_scope},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _scope = selection.first);
                  },
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Expanded(
            child: switch (_scope) {
              _BankScope.papers => _PaperList(
                query: normalized,
                onStart: _startPaper,
              ),
              _BankScope.favorites => _FavoriteList(
                query: normalized,
                onStart: _startFavorite,
              ),
              _BankScope.notes => _NoteList(
                query: normalized,
                onStart: _startFavorite,
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startPaper(Paper paper, {bool mock = false}) async {
    final questions = await ref
        .read(contentRepositoryProvider)
        .questionsForPaper(paper.id);
    if (!mounted) return;
    await launchPractice(
      context,
      ref,
      mode: mock ? PracticeMode.mock : PracticeMode.paper,
      title: mock ? '${paper.title} · 模考' : paper.title,
      questions: questions,
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

enum _BankScope { papers, favorites, notes }

class _PaperList extends ConsumerWidget {
  const _PaperList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(Paper paper, {bool mock}) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papers = ref.watch(papersProvider);
    return papers.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text('读取试卷失败：$error'),
      ),
      data: (items) {
        final filtered = query.isEmpty
            ? items
            : items
                  .where(
                    (paper) =>
                        paper.title.toLowerCase().contains(query) ||
                        paper.region.toLowerCase().contains(query) ||
                        paper.year.toString().contains(query),
                  )
                  .toList(growable: false);
        if (filtered.isEmpty) {
          return ListView(
            children: const [
              AppEmptyState(title: '没有匹配的试卷', message: '换一个年份、地区或试卷名称试试。'),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _PaperRow(paper: filtered[index], onStart: onStart),
          separatorBuilder: (context, index) => const SizedBox(height: 9),
        );
      },
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
                  style: TextStyle(
                    color: AppColors.onInk,
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
                      '${paper.region} · ${paper.paperType} · '
                      '${paper.durationSeconds ~/ 60} 分钟',
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
  const _FavoriteList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final noteById = {
      for (final item in favorites.value ?? const <Favorite>[])
        item.questionId: item.note,
    };
    return favorites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('读取收藏失败：$error'),
      data: (items) {
        final loaded = ref
            .read(contentRepositoryProvider)
            .questionsByIds(items.map((item) => item.questionId));
        return FutureBuilder<List<QuestionContent>>(
          future: Future.value(loaded),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('读取收藏失败：${snapshot.error}');
            }
            final questions = (snapshot.data ?? const <QuestionContent>[])
                .where(
                  (question) =>
                      query.isEmpty ||
                      question.plainStem.toLowerCase().contains(query),
                )
                .toList(growable: false);
            if (questions.isEmpty) {
              return ListView(
                children: [
                  AppEmptyState(
                    title: query.isEmpty ? '还没有收藏题目' : '没有匹配的收藏',
                    message: query.isEmpty
                        ? '做题时点一下书签，题目会出现在这里。'
                        : '换一个题干关键词试试。',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
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
                          question.plainStem,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${question.module} · 第 ${question.sequence} 题',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              // 收藏列表里直接看到自己写的笔记，
                              // 不用再点进题目才能回看。
                              if (noteById[question.id]?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '笔记：${noteById[question.id]}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.positive),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '取消收藏',
                          onPressed: () => ref
                              .read(databaseProvider)
                              .toggleFavorite(question.id),
                          icon: Icon(
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
      },
    );
  }
}

/// 笔记列表：所有写过笔记的题（无论是否收藏），支持直接开练和删除笔记。
class _NoteList extends ConsumerWidget {
  const _NoteList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('读取笔记失败：$error'),
      data: (items) {
        final loaded = ref
            .read(contentRepositoryProvider)
            .questionsByIds(items.map((item) => item.questionId));
        final noteById = {for (final item in items) item.questionId: item.note};
        return FutureBuilder<List<QuestionContent>>(
          future: Future.value(loaded),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('读取笔记失败：${snapshot.error}');
            }
            final questions = (snapshot.data ?? const <QuestionContent>[])
                .where(
                  (question) =>
                      query.isEmpty ||
                      question.plainStem.toLowerCase().contains(query) ||
                      (noteById[question.id] ?? '').toLowerCase().contains(
                        query,
                      ),
                )
                .toList(growable: false);
            if (questions.isEmpty) {
              return ListView(
                children: [
                  AppEmptyState(
                    title: query.isEmpty ? '还没有笔记' : '没有匹配的笔记',
                    message: query.isEmpty
                        ? '做题时点一下便签图标，就能给题目记笔记。'
                        : '换一个题干或笔记关键词试试。',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => onStart(questions),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('复习全部 ${questions.length} 题'),
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
                          question.plainStem,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${question.module} · 第 ${question.sequence} 题',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  noteById[question.id] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.positive),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '删除笔记',
                          onPressed: () => ref
                              .read(databaseProvider)
                              .setFavoriteNote(question.id, ''),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
