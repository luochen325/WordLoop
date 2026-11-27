import 'package:material_ui/material_ui.dart';

import '../models/word.dart';
import '../models/word_progress.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'study_screen.dart';
import 'word_detail_screen.dart';

/// 待复习单词列表：列出当前所有到期的单词，可按到期时间正序/倒序排列。
class DueWordsScreen extends StatefulWidget {
  const DueWordsScreen({super.key});

  @override
  State<DueWordsScreen> createState() => _DueWordsScreenState();
}

class _DueWordsScreenState extends State<DueWordsScreen> {
  bool _earliestFirst = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final now = DateTime.now();
        final entries = appState.progress.values
            .where((item) => item.isDue(now))
            .toList()
          ..sort(
            (a, b) => _earliestFirst
                ? a.due.compareTo(b.due)
                : b.due.compareTo(a.due),
          );

        return Scaffold(
          appBar: AppBar(title: const Text('待复习单词')),
          body: entries.isEmpty
              ? EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: '今天没有待复习单词',
                  message: '所有单词都在记忆曲线上，去学几个新词吧。',
                  action: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('返回'),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                      child: Row(
                        children: [
                          Text(
                            '共 ${entries.length} 个待复习',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _earliestFirst = !_earliestFirst,
                            ),
                            icon: const Icon(
                              Icons.swap_vert_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _earliestFirst ? '最早到期优先' : '最晚到期优先',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = entries[index];
                          final word = appState.wordById(item.wordId);
                          if (word == null) return const SizedBox.shrink();
                          return _DueTile(word: word, item: item, now: now);
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
                            onPressed: () {
                              final ids =
                                  entries.map((item) => item.wordId).toList();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StudyScreen(
                                    wordIds: ids,
                                    isNew: false,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: Text('开始复习（${entries.length}）'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({
    required this.word,
    required this.item,
    required this.now,
  });

  final Word word;
  final WordProgress item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdueDays = now.difference(item.due).inDays;
    final dueLabel = overdueDays >= 1 ? '已过期 $overdueDays 天' : '今天到期';
    final hour = item.due.hour.toString().padLeft(2, '0');
    final minute = item.due.minute.toString().padLeft(2, '0');
    final dateLabel = '${item.due.month}月${item.due.day}日 $hour:$minute';

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
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 19,
                color: AppColors.rose,
              ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dueLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rose,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
