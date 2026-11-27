import 'package:material_ui/material_ui.dart';

import '../models/context_story.dart';
import '../models/word.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 语境阅读：自己挑选最多 10 个单词，生成短文或对话。
///
/// 优先从待复习列表里选；待复习为空时，退回已学单词列表，规则一致。
class ContextScreen extends StatefulWidget {
  const ContextScreen({super.key});

  @override
  State<ContextScreen> createState() => _ContextScreenState();
}

class _ContextScreenState extends State<ContextScreen> {
  static const int _maxSelect = 10;

  String _mode = 'story';
  bool _loading = false;
  bool _earliestFirst = true;
  String? _error;
  ContextStory? _story;
  final Set<int> _selected = {};

  bool get _hasDue => appState.dueWords.isNotEmpty;

  List<Word> _buildPool() {
    final words = _hasDue
        ? appState.dueWords.toList()
        : appState.allWords
            .where((word) => appState.progress.containsKey(word.id))
            .toList();
    words.sort((a, b) {
      final dueA = appState.progress[a.id]?.due;
      final dueB = appState.progress[b.id]?.due;
      if (dueA == null || dueB == null) return 0;
      return _earliestFirst
          ? dueA.compareTo(dueB)
          : dueB.compareTo(dueA);
    });
    return words;
  }

  List<Word> get _selectedWords {
    final pool = _buildPool();
    return pool.where((word) => _selected.contains(word.id)).toList();
  }

  void _toggle(Word word) {
    setState(() {
      if (_selected.contains(word.id)) {
        _selected.remove(word.id);
        return;
      }
      if (_selected.length >= _maxSelect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最多只能选择 10 个单词'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _selected.add(word.id);
    });
  }

  void _selectFirstTen() {
    final pool = _buildPool();
    setState(() {
      _selected
        ..clear()
        ..addAll(pool.take(_maxSelect).map((word) => word.id));
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  Future<void> _generate({bool force = false}) async {
    final words = _selectedWords;
    if (_loading || words.isEmpty) return;
    final mode = _mode;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final story = await appState.api.generateContext(
        words: words.map((word) => word.word).toList(),
        mode: mode,
        force: force,
      );
      if (!mounted || mode != _mode) return;
      setState(() => _story = story);
    } catch (error) {
      if (!mounted || mode != _mode) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchMode(String mode) {
    if (_loading || mode == _mode) return;
    setState(() => _mode = mode);
    if (_story != null) {
      _generate(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语境阅读'),
        actions: [
          if (_story != null)
            IconButton(
              tooltip: '用相同单词重新生成',
              onPressed: _loading ? null : () => _generate(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _LoadingCard(),
              ),
            )
          : (_story == null ? _buildPicker() : _buildResult()),
    );
  }

  Widget _buildPicker() {
    final pool = _buildPool();
    if (pool.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_rounded,
        title: '还没有可以用的单词',
        message: '先学几个单词，再回来把它们编成语境。',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '自己挑选单词，生成一段可读、可听的语境。',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _modeChip('短文', 'story'),
                  const SizedBox(width: 8),
                  _modeChip('对话', 'dialogue'),
                ],
              ),
              if (!_hasDue) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: const Color(0xFFFFF7E6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '今天没有待复习单词，下面展示的是已经学过的单词。',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted.withValues(alpha: 0.95),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '已选 ${_selected.length} / $_maxSelect',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(
                  () => _earliestFirst = !_earliestFirst,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _earliestFirst ? '最早到期优先' : '最晚到期优先',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              TextButton(
                onPressed: pool.isEmpty ? null : _selectFirstTen,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '选中前 10 个',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 14),
              TextButton(
                onPressed: _selected.isEmpty ? null : _clearSelection,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '清空',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            itemCount: pool.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final word = pool[index];
              return _SelectTile(
                word: word,
                selected: _selected.contains(word.id),
                dueText: _dueText(word),
                overdue: _isOverdue(word),
                onTap: () => _toggle(word),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _selected.isEmpty ? null : () => _generate(),
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text('生成语境（${_selected.length} 个单词）'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final story = _story!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            _modeChip('短文', 'story'),
            const SizedBox(width: 8),
            _modeChip('对话', 'dialogue'),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _story = null;
                _error = null;
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '重新选择',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: story.words
              .map(
                (word) => TagPill(text: word, color: AppColors.seed),
              )
              .toList(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppCard(
            color: const Color(0xFFFFF7E6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.amber,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '生成失败',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _generate(force: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _StoryCard(
          story: story,
          highlightWords: {
            ...story.words.map((word) => word.toLowerCase()),
            ...story.used.map((word) => word.toLowerCase()),
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _generate(force: true),
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('换一篇'),
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String label, String mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.seed : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  bool _isOverdue(Word word) {
    final item = appState.progress[word.id];
    return item != null && item.due.isBefore(DateTime.now());
  }

  String _dueText(Word word) {
    final item = appState.progress[word.id];
    if (item == null) return '未学习';
    final now = DateTime.now();
    if (item.due.isBefore(now)) {
      final days = now.difference(item.due).inDays;
      return days >= 1 ? '已过期 $days 天' : '今天到期';
    }
    final days = item.due.difference(now).inHours ~/ 24;
    return days <= 0 ? '今天到期' : '$days 天后';
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.word,
    required this.selected,
    required this.dueText,
    required this.overdue,
    required this.onTap,
  });

  final Word word;
  final bool selected;
  final String dueText;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.seed : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.seed : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.seed : const Color(0xFFC9C9D9),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    word.definitionEn.isEmpty ? word.word : word.definitionEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dueText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: overdue ? AppColors.rose : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '正在把这些单词编进语境，大约需要十几秒…',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.highlightWords});

  final ContextStory story;
  final Set<String> highlightWords;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  story.mode == 'dialogue' ? '对话' : '短文',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lavender,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  story.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: '朗读全文',
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.seed),
                onPressed: () {
                  final text =
                      story.paragraphs.map((item) => item.en).join(' ');
                  if (text.isNotEmpty) appState.speak(text);
                },
              ),
            ],
          ),
          for (var i = 0; i < story.paragraphs.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _ParagraphView(
              paragraph: story.paragraphs[i],
              highlightWords: highlightWords,
            ),
          ],
        ],
      ),
    );
  }
}

class _ParagraphView extends StatelessWidget {
  const _ParagraphView({
    required this.paragraph,
    required this.highlightWords,
  });

  final ContextParagraph paragraph;
  final Set<String> highlightWords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: _spans(paragraph.en)),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: AppColors.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: '朗读这一段',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.play_circle_outline_rounded,
                size: 20,
                color: AppColors.muted,
              ),
              onPressed: () => appState.speak(paragraph.en),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          paragraph.zh,
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  List<TextSpan> _spans(String text) {
    if (text.isEmpty) return const [TextSpan(text: '')];
    final words = highlightWords.where((word) => word.trim().isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (words.isEmpty) return [TextSpan(text: text)];

    final pattern = RegExp(
      r'\b(' + words.map(RegExp.escape).join('|') + r')\b',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: AppColors.seed,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}
