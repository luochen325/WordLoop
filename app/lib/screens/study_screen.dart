import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/ai_word_card.dart';
import '../models/word.dart';
import '../services/app_state.dart';
import '../services/local_images.dart';
import '../services/scheduler.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'word_detail_screen.dart';

enum _PrefetchStatus { idle, loading, ready, error }

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.wordIds,
    required this.isNew,
  });

  final List<int> wordIds;
  final bool isNew;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _index = 0;
  bool _revealed = false;
  bool _busy = false;
  int _correct = 0;

  AiWordCard? _card;
  bool _cardLoading = false;
  String? _cardError;

  String? _imageUrl;
  bool _imageLoading = false;
  String? _imageError;

  final TextEditingController _quizController = TextEditingController();
  bool _cardLookupDone = false;
  bool _quizChecked = false;
  bool _quizCorrect = false;

  Timer? _progressTimer;
  int _generationSeconds = 0;
  _PrefetchStatus _nextStatus = _PrefetchStatus.idle;
  int? _prefetchWordId;
  String? _nextError;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _quizController.dispose();
    super.dispose();
  }

  List<Word> get _queue => widget.wordIds
      .map((id) => appState.wordById(id))
      .whereType<Word>()
      .toList();

  Word? get _current {
    final queue = _queue;
    if (_index >= queue.length) return null;
    return queue[_index];
  }

  @override
  void initState() {
    super.initState();
    _loadCachedOnly();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchNext());
  }

  /// 生成过程中显示已等待时间，避免用户以为卡死了。
  void _ensureProgressTimer() {
    if (_progressTimer != null) return;
    _generationSeconds = 0;
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_cardLoading && !_imageLoading) {
        _progressTimer?.cancel();
        _progressTimer = null;
        return;
      }
      setState(() => _generationSeconds += 1);
    });
  }

  /// 提前为下一个单词生成单词卡，当前词学完后可以直接秒开。
  Future<void> _prefetchNext({bool retry = false}) async {
    if (!mounted) return;
    final queue = _queue;
    final next = (_index + 1 < queue.length) ? queue[_index + 1] : null;
    if (next == null) {
      if (mounted) {
        setState(() {
          _nextStatus = _PrefetchStatus.idle;
          _prefetchWordId = null;
          _nextError = null;
        });
      }
      return;
    }
    if (!retry &&
        _prefetchWordId == next.id &&
        (_nextStatus == _PrefetchStatus.loading ||
            _nextStatus == _PrefetchStatus.ready)) {
      return;
    }
    final cached = next.isCustom
        ? appState.cachedLookup(next.word)
        : appState.cachedCard(next.id);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _prefetchWordId = next.id;
          _nextStatus = _PrefetchStatus.ready;
          _nextError = null;
        });
      }
      _prefetchImageFor(next);
      return;
    }
    setState(() {
      _prefetchWordId = next.id;
      _nextStatus = _PrefetchStatus.loading;
      _nextError = null;
    });
    try {
      await appState.ensureCardForWord(next);
      if (!mounted || _prefetchWordId != next.id) return;
      setState(() => _nextStatus = _PrefetchStatus.ready);
      _prefetchImageFor(next);
    } catch (error) {
      if (!mounted || _prefetchWordId != next.id) return;
      setState(() {
        _nextStatus = _PrefetchStatus.error;
        _nextError = error.toString();
      });
    }
  }

  /// 后台预生成下一个词的配图，翻到该词时图片已经就绪。
  void _prefetchImageFor(Word word) {
    if (!appState.autoImageOnStudy) return;
    unawaited(
      appState.ensureImageForWord(word).catchError((Object _) => null),
    );
  }

  /// 只读缓存，不在用户还没点击“显示释义”时消耗图片额度
  Future<void> _loadCachedOnly() async {
    final word = _current;
    if (word == null) return;
    final wordId = word.id;
    setState(() => _cardLookupDone = false);
    final cached = word.isCustom
        ? appState.cachedLookup(word.word)
        : appState.cachedCard(word.id);
    if (cached != null) {
      if (mounted && _current?.id == wordId) {
        setState(() {
          _card = cached;
          _cardLookupDone = true;
        });
      }
      return;
    }
    try {
      final card = await appState.fetchCachedCardForWord(word);
      if (mounted && _current?.id == wordId && card != null) {
        setState(() => _card = card);
      }
    } catch (_) {
      // 离线时使用本地词表释义
    } finally {
      if (mounted && _current?.id == wordId) {
        setState(() => _cardLookupDone = true);
      }
    }
  }

  /// 生成当前单词卡（失败后可以重试）。
  Future<void> _loadCard() async {
    final word = _current;
    if (word == null || _cardLoading) return;
    final wordId = word.id;
    setState(() {
      _cardLoading = true;
      _cardError = null;
    });
    _ensureProgressTimer();
    try {
      final card = await appState.ensureCardForWord(word);
      if (mounted && _current?.id == wordId) {
        setState(() => _card = card);
      }
    } catch (error) {
      if (mounted && _current?.id == wordId) {
        setState(() => _cardError = error.toString());
      }
    } finally {
      if (mounted && _current?.id == wordId) {
        setState(() => _cardLoading = false);
      }
    }
  }

  /// 复习时先做一次拼写回忆，再揭晓完整单词卡。
  void _checkQuiz() {
    final word = _current;
    final input = _quizController.text.trim();
    if (word == null || input.isEmpty || _quizChecked) return;
    setState(() {
      _quizChecked = true;
      _quizCorrect = input.toLowerCase() == word.word.toLowerCase();
    });
    appState.speak(word.word);
  }

  Future<void> _reveal() async {
    final word = _current;
    if (word == null || _busy) return;
    setState(() => _revealed = true);
    appState.speak(word.word);

    if (_card == null) {
      await _loadCard();
    }

    if (appState.autoImageOnStudy && _imageUrl == null) {
      _loadImage();
    }
  }

  Future<void> _loadImage({bool force = false}) async {
    final word = _current;
    if (word == null || _imageLoading) return;
    final wordId = word.id;
    setState(() {
      _imageLoading = true;
      _imageError = null;
    });
    _ensureProgressTimer();
    try {
      final url = await appState.ensureImageForWord(word, force: force);
      if (mounted && _current?.id == wordId) {
        setState(() => _imageUrl = url);
      }
    } catch (error) {
      if (mounted && _current?.id == wordId) {
        setState(() => _imageError = error.toString());
      }
    } finally {
      if (mounted && _current?.id == wordId) {
        setState(() => _imageLoading = false);
      }
    }
  }

  Future<void> _answer(ReviewGrade grade) async {
    final word = _current;
    if (word == null || _busy) return;
    setState(() => _busy = true);

    try {
      final isStarted = appState.progress.containsKey(word.id);
      final previous = appState.progress[word.id];
      final hBefore = previous?.h ?? word.h0;
      final PlanResult plan = isStarted
          ? await appState.answer(word.id, grade: grade)
          : await appState.startWord(word.id, grade: grade);
      final nextKeep =
          math.pow(2, -plan.intervalDays / plan.nextH).toDouble();

      if (grade.recalled) _correct++;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${grade.label} · p=${plan.probability.toStringAsFixed(2)} · '
            'h ${hBefore.toStringAsFixed(1)}→${plan.nextH.toStringAsFixed(1)} 天\n'
            '策略表给出 ${plan.intervalDays} 天后复习，预测保持 '
            '${(nextKeep * 100).round()}%',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
      setState(() {
        _index++;
        _revealed = false;
        _card = null;
        _cardLoading = false;
        _cardError = null;
        _imageUrl = null;
        _imageLoading = false;
        _imageError = null;
        _busy = false;
        _cardLookupDone = false;
        _quizController.clear();
        _quizChecked = false;
        _quizCorrect = false;
        _nextStatus = _PrefetchStatus.idle;
        _prefetchWordId = null;
        _nextError = null;
      });
      _loadCachedOnly();
      _prefetchNext();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    if (queue.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.inbox_rounded,
          title: '没有需要学习的单词',
          message: '返回首页，稍后再来吧。',
        ),
      );
    }
    if (_index >= queue.length) {
      return _Summary(
        total: queue.length,
        correct: _correct,
        isNew: widget.isNew,
      );
    }

    final word = queue[_index];
    final quizLoading = !widget.isNew && !_revealed && !_cardLookupDone;
    final quizReady = !widget.isNew &&
        !_revealed &&
        _cardLookupDone &&
        _card != null &&
        _card!.meanings.any((item) => item.zh.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '学习新词' : '今日复习'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: '单词详情',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WordDetailScreen(word: word),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${_index + 1} / ${queue.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      TagPill(
                        text: widget.isNew ? '新词' : '复习',
                        color: widget.isNew ? AppColors.seed : AppColors.amber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / queue.length,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEDEDF5),
                      valueColor: const AlwaysStoppedAnimation(AppColors.seed),
                    ),
                  ),
                  if (_nextStatus != _PrefetchStatus.idle) ...[
                    const SizedBox(height: 6),
                    _NextPrefetchBar(
                      status: _nextStatus,
                      error: _nextError,
                      onRetry: () => _prefetchNext(retry: true),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  children: [
                    if (quizLoading) ...[
                      const SizedBox(height: 20),
                      const _QuizLoadingCard(),
                    ] else if (quizReady) ...[
                      const SizedBox(height: 8),
                      _QuizCard(
                        word: word,
                        card: _card!,
                        controller: _quizController,
                        checked: _quizChecked,
                        correct: _quizCorrect,
                        onCheck: _checkQuiz,
                        onSpeak: () => appState.speak(word.word),
                      ),
                    ] else ...[
                      _WordHeader(
                        word: word,
                        card: _card,
                        onSpeak: () => appState.speak(word.word),
                      ),
                      if (!_revealed) ...[
                        const SizedBox(height: 20),
                        AppCard(
                          color: const Color(0xFFF5F3FF),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.lavender,
                                size: 28,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '点击下方按钮，生成释义、例句、语音和场景图',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.ink,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '生成后再判断自己的掌握程度，效果更好',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        _ImagePanel(
                          word: word,
                          imageUrl: _imageUrl,
                          loading: _imageLoading,
                          error: _imageError,
                          autoEnabled: appState.autoImageOnStudy,
                          elapsedSeconds: _generationSeconds,
                          onGenerate: () =>
                              _loadImage(force: _imageUrl != null),
                        ),
                        const SizedBox(height: 14),
                        _StudyContent(
                          word: word,
                          card: _card,
                          loading: _cardLoading,
                          error: _cardError,
                          elapsedSeconds: _generationSeconds,
                          onRetry: _loadCard,
                          onSpeak: appState.speak,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _BottomArea(
              revealed: _revealed,
              busy: _busy,
              quizMode: (quizLoading || quizReady) && !_quizChecked,
              onReveal: _reveal,
              onGrade: _answer,
              onShowRubric: () => _showRubric(context),
              onShowAlgorithm: () => _showAlgorithm(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlgorithm(BuildContext context) {
    final word = _current;
    if (word == null) return;
    final item = appState.progress[word.id];
    final h = item?.h ?? word.h0;
    final d = item?.d ?? word.d0;
    final last = item?.lastReview;
    final elapsed = last == null
        ? 0.0
        : DateTime.now().difference(last).inMinutes / (60 * 24);
    final interval = item?.lastInterval.round() ??
        appState.scheduler.policy.intervalFor(h, d);
    final p = appState.scheduler.recallProbability(h, elapsed);
    final nextP =
        appState.scheduler.recallProbability(h, interval.toDouble());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AlgorithmSheet(
        word: word,
        h: h,
        d: d,
        elapsed: elapsed,
        interval: interval,
        probability: p,
        nextProbability: nextP,
        isNew: item == null,
      ),
    );
  }

  void _showRubric(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '掌握度评分标准',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '评分会直接影响这个单词的记忆稳定性和下次复习间隔。',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                _RubricRow(
                  grade: ReviewGrade.again,
                  color: AppColors.rose,
                ),
                _RubricRow(
                  grade: ReviewGrade.hard,
                  color: AppColors.amber,
                ),
                _RubricRow(
                  grade: ReviewGrade.good,
                  color: AppColors.seed,
                ),
                _RubricRow(
                  grade: ReviewGrade.easy,
                  color: AppColors.mint,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '掌握度标签由记忆稳定性推导：初识（<1天）→ 熟悉中（1-7天）→ 较熟（7-30天）→ 掌握（30-180天）→ 长期记忆（180天+）。',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WordHeader extends StatelessWidget {
  const _WordHeader({
    required this.word,
    required this.card,
    required this.onSpeak,
  });

  final Word word;
  final AiWordCard? card;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (card != null && card!.phoneticUs.isNotEmpty) ...[
                Text(
                  card!.phoneticUs,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.seed),
              ),
            ],
          ),
          Text(
            word.word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.word,
    required this.imageUrl,
    required this.loading,
    required this.error,
    required this.autoEnabled,
    required this.elapsedSeconds,
    required this.onGenerate,
  });

  final Word word;
  final String? imageUrl;
  final bool loading;
  final String? error;
  final bool autoEnabled;
  final int elapsedSeconds;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.15,
              child: CachedImage(
                source: imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF2F2FA),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (_, _, _) => _placeholder('图片加载失败，点击重试'),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '场景图：把单词和具体画面绑定',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: onGenerate,
                child: const Text('换一张', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lavender.withValues(alpha: 0.18),
            AppColors.seed.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              '正在为这个单词绘制场景图…已等待 $elapsedSeconds 秒',
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              '首次约 10–90 秒，之后直接读缓存',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ] else ...[
            const Icon(Icons.image_outlined, size: 34, color: AppColors.lavender),
            const SizedBox(height: 10),
            Text(
              error ?? (autoEnabled ? '配图暂未生成' : '学习时自动配图已关闭'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.brush_rounded, size: 18),
              label: const Text('生成配图（约 0.25 元）'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(String text) {
    return Container(
      color: const Color(0xFFF2F2FA),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _StudyContent extends StatelessWidget {
  const _StudyContent({
    required this.word,
    required this.card,
    required this.loading,
    required this.error,
    required this.elapsedSeconds,
    required this.onRetry,
    required this.onSpeak,
  });

  final Word word;
  final AiWordCard? card;
  final bool loading;
  final String? error;
  final int elapsedSeconds;
  final VoidCallback onRetry;
  final Future<void> Function(String text) onSpeak;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppCard(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '正在生成释义、例句和搭配…已等待 $elapsedSeconds 秒',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.translate_rounded, size: 15, color: AppColors.seed),
                  SizedBox(width: 6),
                  Text(
                    '释义',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.seed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (card != null && card!.meanings.isNotEmpty)
                ...card!.meanings.map(
                  (meaning) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            meaning.pos,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.seed,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            meaning.zh,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  word.definitionEn.isEmpty ? '暂无释义' : word.definitionEn,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.ink,
                    height: 1.5,
                  ),
                ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: const TextStyle(fontSize: 10, color: AppColors.rose),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      '重试生成',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (card != null && card!.examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 15,
                      color: AppColors.amber,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '例句',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final example in card!.examples.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                example.en,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                example.zh,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onSpeak(example.en),
                          icon: const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 20,
                            color: AppColors.seed,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (card != null && card!.collocations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: card!.collocations
                .take(4)
                .map(
                  (item) => TagPill(
                    text: '${item.phrase}  ${item.zh}',
                    color: AppColors.mint,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _NextPrefetchBar extends StatelessWidget {
  const _NextPrefetchBar({
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final _PrefetchStatus status;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    Color color = AppColors.muted;
    String text = '';
    switch (status) {
      case _PrefetchStatus.loading:
        text = '正在为下一个词预生成单词卡…';
      case _PrefetchStatus.ready:
        icon = Icons.check_circle_rounded;
        color = AppColors.mint;
        text = '下一个词已准备好';
      case _PrefetchStatus.error:
        icon = Icons.error_outline_rounded;
        color = AppColors.rose;
        text = '下一个词预生成失败';
      case _PrefetchStatus.idle:
        return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Spacer(),
        if (icon != null)
          Icon(icon, size: 12, color: color)
        else
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        const SizedBox(width: 4),
        Tooltip(
          message: status == _PrefetchStatus.error ? (error ?? '') : '',
          child: Text(text, style: TextStyle(fontSize: 10, color: color)),
        ),
        if (status == _PrefetchStatus.error)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('重试', style: TextStyle(fontSize: 10)),
          ),
      ],
    );
  }
}

class _QuizLoadingCard extends StatelessWidget {
  const _QuizLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      color: Color(0xFFF5F3FF),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '正在准备回忆题…',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 复习前的主动回忆：只给中文释义，让用户拼出英文单词。
class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.word,
    required this.card,
    required this.controller,
    required this.checked,
    required this.correct,
    required this.onCheck,
    required this.onSpeak,
  });

  final Word word;
  final AiWordCard card;
  final TextEditingController controller;
  final bool checked;
  final bool correct;
  final VoidCallback onCheck;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final meanings = card.meanings
        .where((item) => item.zh.trim().isNotEmpty)
        .take(2)
        .toList();
    final resultColor = correct ? AppColors.mint : AppColors.rose;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 20,
                color: AppColors.seed,
              ),
              SizedBox(width: 8),
              Text(
                '先回忆一下',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '根据中文释义，拼出对应的英文单词',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final meaning in meanings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meaning.pos.isNotEmpty) ...[
                    Text(
                      meaning.pos,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.seed,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      meaning.zh,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !checked,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCheck(),
            decoration: InputDecoration(
              hintText: '输入英文单词',
              hintStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: const Color(0xFFF7F7FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!checked)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCheck,
                child: const Text('检查拼写'),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: resultColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      correct
                          ? '拼写正确，可以参考选择“想起”或“熟练”'
                          : '正确拼写是 ${word.word}，可以参考选择“忘记”或“模糊”',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: resultColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('听发音'),
              ),
            ),
            const Text(
              '点击下方按钮查看完整单词卡，再选择掌握度',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.revealed,
    required this.busy,
    required this.quizMode,
    required this.onReveal,
    required this.onGrade,
    required this.onShowRubric,
    required this.onShowAlgorithm,
  });

  final bool revealed;
  final bool busy;
  final bool quizMode;
  final VoidCallback onReveal;
  final ValueChanged<ReviewGrade> onGrade;
  final VoidCallback onShowRubric;
  final VoidCallback onShowAlgorithm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF5))),
      ),
      child: revealed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '你掌握到什么程度？',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onShowAlgorithm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '算法详情',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                    TextButton(
                      onPressed: onShowRubric,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '评分标准',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _GradeButton(
                        grade: ReviewGrade.again,
                        color: AppColors.rose,
                        busy: busy,
                        onTap: onGrade,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradeButton(
                        grade: ReviewGrade.hard,
                        color: AppColors.amber,
                        busy: busy,
                        onTap: onGrade,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GradeButton(
                        grade: ReviewGrade.good,
                        color: AppColors.seed,
                        busy: busy,
                        onTap: onGrade,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradeButton(
                        grade: ReviewGrade.easy,
                        color: AppColors.mint,
                        busy: busy,
                        onTap: onGrade,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(quizMode ? '跳过自测，查看释义与场景图' : '显示释义与场景图'),
              ),
            ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.grade,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final ReviewGrade grade;
  final Color color;
  final bool busy;
  final ValueChanged<ReviewGrade> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : () => onTap(grade),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              grade.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              grade.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({required this.grade, required this.color});

  final ReviewGrade grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              grade.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  grade.effect,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlgorithmSheet extends StatelessWidget {
  const _AlgorithmSheet({
    required this.word,
    required this.h,
    required this.d,
    required this.elapsed,
    required this.interval,
    required this.probability,
    required this.nextProbability,
    required this.isNew,
  });

  final Word word;
  final double h;
  final double d;
  final double elapsed;
  final int interval;
  final double probability;
  final double nextProbability;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这个词的遗忘曲线',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${word.word} · 半衰期 h=${h.toStringAsFixed(2)} 天 · '
                '难度 d=${d.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ForgettingCurve(
                h: h,
                elapsedDays: elapsed,
                intervalDays: interval,
                height: 200,
              ),
              const SizedBox(height: 12),
              _row('距上次复习', '${elapsed.toStringAsFixed(1)} 天'),
              _row(
                '当前回忆概率 p',
                '${(probability * 100).toStringAsFixed(1)}%',
                color: AppColors.seed,
              ),
              _row('策略表下次间隔', '$interval 天', color: AppColors.amber),
              _row(
                '下次复习预测保持率',
                '${(nextProbability * 100).toStringAsFixed(1)}%',
                color: AppColors.mint,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '计算链路',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. p = 2^(-Δt/h) = 2^(-${elapsed.toStringAsFixed(1)} / '
                      '${h.toStringAsFixed(2)}) = '
                      '${(probability * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '2. 本次评分按官方 DHP 公式更新 h 和 d（失败难度 +2）',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '3. 用新的 h、d 查 SSP-MMC 策略表，得到 $interval 天',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '策略表按官方 algo/main.cpp：半衰期步长 1.05、152 个状态、'
                '难度 1~18、目标约 365 天。间隔不是固定的 1/3/7 天，'
                '而是随 h、d、当前 p 和评分结果变化。',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              if (isNew) ...[
                const SizedBox(height: 8),
                const Text(
                  '这是首次学习，评分后会生成第一条真实复习记录。',
                  style: TextStyle(fontSize: 10, color: AppColors.amber),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color color = AppColors.ink}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.correct,
    required this.isNew,
  });

  final int total;
  final int correct;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.seed.withValues(alpha: 0.18),
                      AppColors.lavender.withValues(alpha: 0.12),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 46,
                  color: AppColors.seed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isNew ? '新词学习完成' : '复习完成',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '完成了 $total 个单词，想起/熟练 $correct 个',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '$total',
                        label: '本次单词',
                        color: AppColors.seed,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '$accuracy%',
                        label: '掌握率',
                        color: AppColors.mint,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${appState.dueCount}',
                        label: '待复习',
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回首页'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
