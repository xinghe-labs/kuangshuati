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
                      _BankScope.questions => '搜索题干、材料或选项文字',
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
                      value: _BankScope.questions,
                      label: Text('题目'),
                      icon: Icon(Icons.manage_search, size: 17),
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
              _BankScope.questions => _QuestionSearchList(
                query: normalized,
                onStart: _startQuestions,
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
    final List<QuestionContent> questions;
    try {
      questions = await ref
          .read(contentRepositoryProvider)
          .questionsForPaper(paper.id);
    } on Object catch (error) {
      // 题库读取失败时以前什么都不做，用户点试卷没反应。
      if (mounted) showContentError(context, error);
      return;
    }
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

  /// 把搜到的题目直接组成一次练习。
  /// 用户搜题的目的通常就是“把这批题再做一遍”，所以不要求先勾选。
  Future<void> _startQuestions(List<QuestionContent> questions) {
    return launchPractice(
      context,
      ref,
      mode: PracticeMode.custom,
      title: '搜索题目练习',
      questions: questions,
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

enum _BankScope { papers, questions, favorites, notes }

/// 题目搜索结果：题库全量按题干/材料/选项匹配。
///
/// 搜索词为空时不查库（返回空列表），避免一进题库页就把 58890 道题
/// 全拉出来。key 带上 limit，搜索词变化时自动重新请求。
const questionSearchLimit = 200;

final questionSearchProvider =
    FutureProvider.family<List<QuestionContent>, String>((ref, query) {
      if (query.trim().isEmpty) return Future.value(const []);
      return Future.value(
        ref
            .watch(contentRepositoryProvider)
            .searchQuestions(query, limit: questionSearchLimit),
      );
    });

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
            children: [
              AppEmptyState(
                title: '没有匹配的试卷',
                // 用户搜的往往是题干里的词（“基层治理”“追及问题”），
                // 而不是试卷名。这里直接告诉他该切到哪个标签页，
                // 否则他会以为题库里根本没有这道题。
                message: query.isEmpty
                    ? '换一个年份、地区或试卷名称试试。'
                    : '试卷名里没有「$query」。想按题干、材料或选项文字找题，'
                          '请切换到上方「题目」。',
              ),
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

/// 按题干 / 材料 / 选项文字搜题。
class _QuestionSearchList extends ConsumerWidget {
  const _QuestionSearchList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return ListView(
        children: const [
          AppEmptyState(
            title: '搜索题库',
            message: '输入题干、材料或选项里的任意文字，就能找到那道题。',
          ),
        ],
      );
    }
    final results = ref.watch(questionSearchProvider(query));
    return results.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text('搜索题目失败：$error'),
      ),
      data: (questions) {
        if (questions.isEmpty) {
          return ListView(
            children: [
              AppEmptyState(
                title: '没有匹配的题目',
                message: '题库里没有包含「$query」的题干、材料或选项。换一个更短的关键词试试。',
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // 命中数到上限时，实际命中可能远不止这些，
                      // 直接写“找到 200 道题”会让用户以为题库里只有 200 道。
                      questions.length >= questionSearchLimit
                          ? '匹配很多，先显示前 $questionSearchLimit 道题'
                          : '找到 ${questions.length} 道题',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => onStart(questions),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      questions.length >= questionSearchLimit
                          ? '练习这 $questionSearchLimit 题'
                          : '练习这 ${questions.length} 题',
                    ),
                  ),
                ],
              ),
            ),
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
                      child: Text(
                        '${question.module} · 第 ${question.sequence} 题',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    // 搜索结果整行可点：只给一个「练习这 N 题」的话，
                    // 用户搜到想确认的那道题没法单独打开看解析，
                    // 只能把 200 道全开成一组练习再翻。
                    onTap: () => onStart([question]),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FavoriteList extends ConsumerStatefulWidget {
  const _FavoriteList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  ConsumerState<_FavoriteList> createState() => _FavoriteListState();
}

class _FavoriteListState extends ConsumerState<_FavoriteList> {
  Future<List<QuestionContent>>? _future;
  String? _signature;

  /// 收藏列表在搜索框每敲一个字都会重建。原来直接在 build 里调
  /// `questionsByIds` 并把结果包成新的 Future，于是每按一个键就重新查一遍
  /// 题库、整个列表闪一次转圈（收藏多了还会卡）。这里按 id 列表做缓存，
  /// 只有收藏集合真的变了才重新查。
  Future<List<QuestionContent>> _questionsFor(List<Favorite> items) {
    final signature = items.map((item) => item.questionId).join('\u0000');
    if (_future == null || _signature != signature) {
      _signature = signature;
      _future = Future.value(
        ref
            .read(contentRepositoryProvider)
            .questionsByIds(items.map((item) => item.questionId)),
      );
    }
    return _future!;
  }

  /// 取消收藏给一条带「撤销」的提示。
  ///
  /// 收藏列表里的书签图标就在标题右侧，很容易误触：以前点一下，那一行
  /// 立刻从列表里消失，既没有提示也没有撤销入口，用户只能去题库里重新搜。
  Future<void> _removeFavorite(String questionId) async {
    final database = ref.read(databaseProvider);
    await database.toggleFavorite(questionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('已取消收藏，笔记仍然保留'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => database.toggleFavorite(questionId),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final query = widget.query;
    final noteById = {
      for (final item in favorites.value ?? const <Favorite>[])
        item.questionId: item.note,
    };
    return favorites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('读取收藏失败：$error'),
      data: (items) {
        final loaded = _questionsFor(items);
        return FutureBuilder<List<QuestionContent>>(
          future: loaded,
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
                      question.plainStem.toLowerCase().contains(query) ||
                      // 收藏列表本来就显示笔记，搜索却只搜题干：用户明明看到
                      // 那行写着“笔记：网格化”，搜“网格化”却提示没有匹配。
                      (noteById[question.id] ?? '').toLowerCase().contains(
                        query,
                      ),
                )
                .toList(growable: false);
            if (questions.isEmpty) {
              return ListView(
                children: [
                  AppEmptyState(
                    title: query.isEmpty ? '还没有收藏题目' : '没有匹配的收藏',
                    message: query.isEmpty
                        ? '做题时点一下书签，题目会出现在这里。'
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
                    onPressed: () => widget.onStart(questions),
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
                        // 收藏行也整行可点：以前只有右上角的书签按钮能点，
                        // 想打开这道题看解析、看自己写的笔记，只能把整组收藏
                        // 变成一次练习再翻到它。
                        onTap: () => widget.onStart([question]),
                        trailing: IconButton(
                          tooltip: '取消收藏',
                          onPressed: () => _removeFavorite(question.id),
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
class _NoteList extends ConsumerStatefulWidget {
  const _NoteList({required this.query, required this.onStart});

  final String query;
  final Future<void> Function(List<QuestionContent> questions) onStart;

  @override
  ConsumerState<_NoteList> createState() => _NoteListState();
}

class _NoteListState extends ConsumerState<_NoteList> {
  Future<List<QuestionContent>>? _future;
  String? _signature;

  /// 与收藏列表同理：搜索框每敲一个字都会重建，不能每次都重查题库。
  Future<List<QuestionContent>> _questionsFor(List<Favorite> items) {
    final signature = items.map((item) => item.questionId).join('\u0000');
    if (_future == null || _signature != signature) {
      _signature = signature;
      _future = Future.value(
        ref
            .read(contentRepositoryProvider)
            .questionsByIds(items.map((item) => item.questionId)),
      );
    }
    return _future!;
  }

  /// 删除笔记要确认。原来点一下垃圾桶就直接清空，长按也救不回来，
  /// 而笔记是用户自己一个字一个字敲的，误触代价很大。
  Future<void> _deleteNote(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条笔记？'),
        content: const Text('笔记内容删除后无法恢复，题目本身不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).setFavoriteNote(questionId, '');
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final query = widget.query;
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('读取笔记失败：$error'),
      data: (items) {
        final loaded = _questionsFor(items);
        final noteById = {for (final item in items) item.questionId: item.note};
        return FutureBuilder<List<QuestionContent>>(
          future: loaded,
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
                    onPressed: () => widget.onStart(questions),
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
                        onTap: () => widget.onStart([question]),
                        trailing: IconButton(
                          tooltip: '删除笔记',
                          onPressed: () => _deleteNote(question.id),
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
