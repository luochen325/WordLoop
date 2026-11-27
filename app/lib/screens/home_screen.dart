import 'package:material_ui/material_ui.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';
import 'context_screen.dart';
import 'due_words_screen.dart';
import 'study_screen.dart';
import 'word_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final retention = appState.averageRetention;
        final due = appState.dueCount;
        final newRemaining = appState.dailyNewGoal - appState.learnedToday;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _Header(),
              const SizedBox(height: 18),
              if (appState.hasLegacyProgress) ...[
                _LegacyBanner(
                  onReset: () => _confirmLegacyReset(context),
                ),
                const SizedBox(height: 12),
              ],
              _MainAction(
                due: due,
                newRemaining: newRemaining,
                onTap: () => _startStudy(context),
              ),
              const SizedBox(height: 16),
              _HeroCard(
                due: due,
                learned: appState.learnedCount,
                retention: retention,
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${appState.streakDays}',
                        label: '连续学习（天）',
                        color: AppColors.mint,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: StatTile(
                        value: '${appState.learnedCount}',
                        label: '已学单词',
                        color: AppColors.seed,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: StatTile(
                        value: '${appState.masteredCount}',
                        label: '已掌握',
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: '今日计划',
                action: GestureDetector(
                  onTap: () => _openDueList(context),
                  child: const Text(
                    '待复习列表 →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.seed,
                    ),
                  ),
                ),
              ),
              AppCard(
                child: Column(
                  children: [
                    _PlanRow(
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.seed,
                      title: '学习新词',
                      value: '${appState.learnedToday} / ${appState.dailyNewGoal}',
                      progress: appState.dailyNewGoal == 0
                          ? 0
                          : appState.learnedToday / appState.dailyNewGoal,
                    ),
                    const SizedBox(height: 16),
                    _PlanRow(
                      icon: Icons.replay_rounded,
                      color: AppColors.amber,
                      title: '今日已复习',
                      value: '${appState.todayReviews} 次',
                      progress: null,
                    ),
                    const SizedBox(height: 16),
                    _PlanRow(
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.rose,
                      title: '待复习',
                      value: '$due 个',
                      progress: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '语境阅读'),
              AppCard(
                onTap: () => _openContext(context),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: AppColors.lavender,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '把今天的单词编成短文',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '自选最多 10 个词，生成语境',
                            style: TextStyle(
                              fontSize: 11,
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
              const SizedBox(height: 24),
              SectionHeader(
                title: '学习节奏',
                action: Text(
                  '近 7 天',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              AppCard(
                child: WeekBars(counts: appState.reviewsLast7Days),
              ),
              const SizedBox(height: 24),
              if (appState.recentWords.isNotEmpty) ...[
                const SectionHeader(title: '最近学习'),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: appState.recentWords.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final word = appState.recentWords[index];
                      final item = appState.progress[word.id];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WordDetailScreen(word: word),
                            ),
                          );
                        },
                        child: Container(
                          width: 148,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.word,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item == null
                                    ? '未开始'
                                    : '保持 ${item.h.toStringAsFixed(1)} 天',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              AppCard(
                color: const Color(0xFFF0F0FF),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.seed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.psychology_alt_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SSP-MMC 记忆引擎',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '基于 KDD\'22 论文：为每个单词追踪半衰期与难度，用最优控制安排复习，在快忘记时提醒你。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: const Color(0xFFEDEDF5),
      );

  Future<void> _confirmLegacyReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置旧版记忆数据？'),
        content: const Text(
          '旧记录使用的是旧版算法，h/d 与现在官方策略表不匹配。重置后会清空学习进度和复习记录，但保留已生成的单词卡和配图缓存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('重置并重新开始'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.resetProgress();
    }
  }

  void _openContext(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContextScreen()),
    );
  }

  void _openDueList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DueWordsScreen()),
    );
  }

  /// 一个入口同时承接新词学习和到期复习：先学新词，学完再引导复习。
  void _startStudy(BuildContext context) {
    final newIds = appState.newWords.map((word) => word.id).toList();
    if (newIds.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyScreen(wordIds: newIds, isNew: true),
        ),
      );
      return;
    }

    final dueIds = appState.dueWords.map((word) => word.id).toList();
    if (dueIds.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyScreen(wordIds: dueIds, isNew: false),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('今天的新词和复习都完成啦，休息一下吧'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _LegacyBanner extends StatelessWidget {
  const _LegacyBanner({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF7E6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '检测到旧版记忆数据',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '旧记录使用的是旧算法，复习间隔可能异常。建议重置后重新学习，已生成的单词卡和配图缓存不会丢。',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReset,
            child: const Text(
              '重置',
              style: TextStyle(fontSize: 11, color: AppColors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? '夜深了'
        : hour < 12
            ? '早上好'
            : hour < 18
                ? '下午好'
                : '晚上好';

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WordLoop',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '让记忆在最合适的时刻发生',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateTime.now().month} 月 ${DateTime.now().day} 日',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.due,
    required this.newRemaining,
    required this.onTap,
  });

  final int due;
  final int newRemaining;
  final VoidCallback onTap;

  String get _subtitle {
    if (newRemaining > 0 && due > 0) {
      return '今日新词剩 $newRemaining 个 · 待复习 $due 个';
    }
    if (newRemaining > 0) return '今日新词剩 $newRemaining 个';
    if (due > 0) return '今日新词已完成 · $due 个单词待复习';
    return '今日任务已完成，点此巩固';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A5FF0), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A5FF0).withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '学习 / 复习单词',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.due,
    required this.learned,
    required this.retention,
  });

  final int due;
  final int learned;
  final double retention;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A5FF0), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A5FF0).withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日复习概览',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$due',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '个单词等你复习',
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                ),
                const SizedBox(height: 18),
                Text(
                  '已学 $learned / 2809 词',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ProgressRing(
            value: retention,
            centerValue: '${(retention * 100).round()}%',
            centerLabel: '平均保持率',
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFEDEDF5),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
