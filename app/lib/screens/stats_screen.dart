import 'package:material_ui/material_ui.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final buckets = appState.stabilityBuckets;
        final maxBucket = buckets.values.fold<int>(1, (a, b) => a > b ? a : b);

        final progressItems = appState.progress.values.toList()
          ..sort((a, b) => b.h.compareTo(a.h));
        final sample = progressItems.isNotEmpty ? progressItems.first : null;
        final sampleWord =
            sample == null ? null : appState.wordById(sample.wordId);
        final h = sample?.h ?? (appState.words.isNotEmpty ? appState.words.first.h0 : 1);
        final elapsed = sample?.lastReview == null
            ? 0.0
            : DateTime.now().difference(sample!.lastReview!).inMinutes / (60 * 24);
        final interval = sample?.lastInterval.round() ?? 1;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                '学习统计',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '你的记忆状态，一眼看清',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${appState.learnedCount}',
                        label: '已学单词',
                        color: AppColors.seed,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${appState.masteredCount}',
                        label: '已掌握',
                        color: AppColors.mint,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${(appState.averageRetention * 100).round()}%',
                        label: '平均保持率',
                        color: AppColors.amber,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${appState.streakDays}',
                        label: '连续天数',
                        color: AppColors.rose,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '近 7 天复习量'),
              AppCard(child: WeekBars(counts: appState.reviewsLast7Days)),
              const SizedBox(height: 24),
              const SectionHeader(title: '记忆稳定性分布'),
              AppCard(
                child: Column(
                  children: buckets.entries.map((entry) {
                    final ratio = entry.value / maxBucket;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFF2F2FA),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.lavender,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${entry.value}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: '遗忘曲线',
                action: sampleWord == null
                    ? null
                    : TagPill(text: sampleWord.word),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '每个单词都有一条独立的遗忘曲线。复习得越及时，曲线越平缓，记忆保持越久。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ForgettingCurve(
                      h: h,
                      elapsedDays: elapsed,
                      intervalDays: interval,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前半衰期 ${h.toStringAsFixed(1)} 天 · 下次间隔 $interval 天',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '复习记录'),
              if (appState.history.isEmpty)
                const AppCard(
                  child: Text(
                    '还没有复习记录，先去学几个单词吧。',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: appState.history.reversed
                        .take(8)
                        .map((log) {
                      final word = appState.wordById(log.wordId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              log.recalled
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 18,
                              color: log.recalled
                                  ? AppColors.mint
                                  : AppColors.rose,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                word?.word ?? '#${log.wordId}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${log.intervalDays} 天后 · ${_time(log.at)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _time(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
