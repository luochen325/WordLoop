import 'package:material_ui/material_ui.dart';

import '../models/word.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _Bucket {
  const _Bucket(this.label, this.minRank, this.maxRank);

  final String label;
  final int minRank;
  final int maxRank;

  bool contains(Word word) => word.rank >= minRank && word.rank <= maxRank;
}

const _buckets = [
  _Bucket('高频核心', 1, 500),
  _Bucket('常用词', 501, 1200),
  _Bucket('进阶词', 1201, 2000),
  _Bucket('低频拓展', 2001, 99999),
];

/// 按使用频率分组，批量把单词标记为“已掌握”。
/// 标记后这些词不会再进入学习列表和复习列表。
class KnownWordsScreen extends StatefulWidget {
  const KnownWordsScreen({super.key});

  @override
  State<KnownWordsScreen> createState() => _KnownWordsScreenState();
}

class _KnownWordsScreenState extends State<KnownWordsScreen> {
  final TextEditingController _controller = TextEditingController();
  int _bucketIndex = 0;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Word> _bucketWords(int index) {
    final bucket = _buckets[index];
    return appState.words
        .where((word) => !word.isCustom && bucket.contains(word))
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  List<Word> _visibleWords() {
    final query = _query.trim().toLowerCase();
    final words = _bucketWords(_bucketIndex);
    if (query.isEmpty) return words;
    return words
        .where((word) => word.word.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _toggleBucket() async {
    final words = _bucketWords(_bucketIndex);
    if (words.isEmpty) return;
    final allKnown = words.every((word) => appState.isKnown(word.id));
    final label = _buckets[_bucketIndex].label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(allKnown ? '取消本组标记？' : '全部标记为已掌握？'),
        content: Text(
          allKnown
              ? '将取消「$label」中 ${words.length} 个单词的已掌握标记，它们会重新回到学习列表。'
              : '将把「$label」中的 ${words.length} 个单词标记为已掌握，之后不会再进入学习或复习列表。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(allKnown ? '取消标记' : '全部标记'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await appState.setKnownBatch(
      words.map((word) => word.id),
      known: !allKnown,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final bucketWords = _bucketWords(_bucketIndex);
        final knownInBucket = bucketWords.where(
          (word) => appState.isKnown(word.id),
        ).length;
        final words = _visibleWords();

        return Scaffold(
          appBar: AppBar(title: const Text('批量标记已掌握')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '按 NGSL 使用频率分成 4 组。勾选后这些单词不会再进入学习列表和复习列表。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _buckets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final words = _bucketWords(index);
                    final known =
                        words.where((word) => appState.isKnown(word.id)).length;
                    return _BucketCard(
                      label: _buckets[index].label,
                      known: known,
                      total: words.length,
                      selected: index == _bucketIndex,
                      onTap: () => setState(() {
                        _bucketIndex = index;
                        _query = '';
                        _controller.clear();
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '在本组中搜索单词',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
                child: Row(
                  children: [
                    Text(
                      '本组 ${bucketWords.length} 个 · 已掌握 $knownInBucket',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: bucketWords.isEmpty ? null : _toggleBucket,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        knownInBucket == bucketWords.length
                            ? '取消本组标记'
                            : '全部标记本组',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: words.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: '没有找到单词',
                        message: '换个关键词试试',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: words.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final word = words[index];
                          return _KnownTile(
                            word: word,
                            known: appState.isKnown(word.id),
                            onTap: () => appState.setKnownBatch(
                              [word.id],
                              known: !appState.isKnown(word.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.label,
    required this.known,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int known;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.seed : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '已掌握 $known / $total',
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnownTile extends StatelessWidget {
  const _KnownTile({
    required this.word,
    required this.known,
    required this.onTap,
  });

  final Word word;
  final bool known;
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
            color: known ? AppColors.mint : Colors.transparent,
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
                color: known ? AppColors.mint : Colors.transparent,
                border: Border.all(
                  color: known ? AppColors.mint : const Color(0xFFC9C9D9),
                  width: 1.5,
                ),
              ),
              child: known
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
              known ? '已掌握' : '#${word.rank}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: known ? AppColors.mint : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
