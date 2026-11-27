import 'package:material_ui/material_ui.dart';

import '../models/word.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'known_words_screen.dart';
import 'word_detail_screen.dart';

enum _Filter { all, learning, fresh, mastered }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _controller = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final words = _filteredWords();
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  '词库',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  'NGSL 1.2 · 2809 个高频词 · 覆盖约 92% 日常文本',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索单词',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: AppCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KnownWordsScreen(),
                      ),
                    );
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          size: 19,
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '按使用率批量标记已掌握',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '分成 4 组，勾选后不再进入学习/复习',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _filterChip('全部', _Filter.all, _countFor(_Filter.all)),
                    const SizedBox(width: 8),
                    _filterChip(
                      '学习中',
                      _Filter.learning,
                      _countFor(_Filter.learning),
                    ),
                    const SizedBox(width: 8),
                    _filterChip('未学习', _Filter.fresh, _countFor(_Filter.fresh)),
                    const SizedBox(width: 8),
                    _filterChip(
                      '已掌握',
                      _Filter.mastered,
                      _countFor(_Filter.mastered),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: words.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: '没有找到单词',
                        message: '换个关键词试试',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: words.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final word = words[index];
                          return _WordTile(word: word);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, _Filter filter, int count) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.seed : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  /// 各筛选条件下的单词数量，帮助理解「学习中 / 已掌握」的划分。
  int _countFor(_Filter filter) {
    switch (filter) {
      case _Filter.all:
        return appState.allWords.length;
      case _Filter.learning:
        return appState.progress.values
            .where(
              (item) => item.h < 30 && !appState.isKnown(item.wordId),
            )
            .length;
      case _Filter.fresh:
        return appState.allWords
            .where(
              (word) =>
                  !appState.isKnown(word.id) &&
                  !appState.progress.containsKey(word.id),
            )
            .length;
      case _Filter.mastered:
        return appState.allWords
            .where(
              (word) =>
                  appState.isKnown(word.id) ||
                  (appState.progress[word.id]?.h ?? 0) >= 30,
            )
            .length;
    }
  }

  List<Word> _filteredWords() {
    final query = _query.trim().toLowerCase();
    return appState.allWords.where((word) {
      if (query.isNotEmpty && !word.word.toLowerCase().contains(query)) {
        return false;
      }
      final item = appState.progress[word.id];
      final known = appState.isKnown(word.id);
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.learning:
          return !known && item != null && item.h < 30;
        case _Filter.fresh:
          return !known && item == null;
        case _Filter.mastered:
          return known || (item != null && item.h >= 30);
      }
    }).toList();
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final item = appState.progress[word.id];
    final known = appState.isKnown(word.id);
    final due = !known && item != null && item.isDue(DateTime.now());
    final statusColor = known
        ? AppColors.mint
        : due
            ? AppColors.rose
            : item == null
                ? AppColors.muted
                : item.h >= 30
                    ? AppColors.mint
                    : AppColors.seed;
    final statusText = known
        ? '已掌握'
        : due
            ? '待复习'
            : item == null
                ? '未学'
                : '保持 ${item.h.toStringAsFixed(1)} 天';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WordDetailScreen(word: word),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                word.isCustom ? '扩展' : '${word.rank}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: word.isCustom ? AppColors.lavender : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    word.definitionEn,
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
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
