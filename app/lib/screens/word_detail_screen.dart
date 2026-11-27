import 'package:material_ui/material_ui.dart';

import '../models/ai_word_card.dart';
import '../models/word.dart';
import '../services/app_state.dart';
import '../services/local_images.dart';
import '../services/scheduler.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/grade_buttons.dart';
import 'graph_screen.dart';

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({super.key, required this.word});

  final Word word;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  AiWordCard? _card;
  bool _loadingCard = false;
  String? _cardError;

  String? _imageUrl;
  bool _loadingImage = false;
  String? _imageError;

  bool _grading = false;
  bool _graded = false;
  String? _gradeResult;

  @override
  void initState() {
    super.initState();
    final existing = appState.progress[widget.word.id];
    if (existing != null) {
      _graded = true;
      _gradeResult = existing.isDue(DateTime.now())
          ? '已学习 · 今天待复习'
          : '已学习 · 下次 ${existing.daysUntilDue} 天后复习';
    }
    _imageUrl = appState.cachedImageForWord(widget.word);
    _loadCachedCard();
    if (appState.autoImageOnStudy && _imageUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generateImage();
      });
    }
  }

  Future<void> _loadCachedCard() async {
    final word = widget.word;
    final cached = word.isCustom
        ? appState.cachedLookup(word.word)
        : appState.cachedCard(word.id);
    if (cached != null) {
      setState(() => _card = cached);
      return;
    }
    try {
      final card = word.isCustom
          ? await appState.lookupWord(word.word)
          : await appState.fetchCachedCard(word.id);
      if (mounted && card != null) setState(() => _card = card);
    } catch (_) {
      // 后端不可用时保持离线模式
    }
  }

  Future<void> _generateCard({bool force = false}) async {
    setState(() {
      _loadingCard = true;
      _cardError = null;
    });
    try {
      final word = widget.word;
      final card = word.isCustom
          ? await appState.lookupWord(word.word)
          : await appState.generateCard(word.id, force: force);
      if (mounted) setState(() => _card = card);
    } catch (error) {
      if (mounted) setState(() => _cardError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCard = false);
    }
  }

  Future<void> _generateImage({bool force = false}) async {
    setState(() {
      _loadingImage = true;
      _imageError = null;
    });
    try {
      final url = await appState.ensureImageForWord(widget.word, force: force);
      if (mounted) setState(() => _imageUrl = url);
    } catch (error) {
      if (mounted) setState(() => _imageError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  /// AI 信息已经生成，直接记录四档掌握度，不再进入学习页重复生成。
  Future<void> _grade(ReviewGrade grade) async {
    setState(() {
      _grading = true;
      _gradeResult = null;
    });
    try {
      final started = appState.progress.containsKey(widget.word.id);
      final plan = started
          ? await appState.answer(widget.word.id, grade: grade)
          : await appState.startWord(widget.word.id, grade: grade);
      if (!mounted) return;
      setState(() {
        _graded = true;
        _gradeResult =
            '${grade.label} · 下次 ${plan.intervalDays} 天后复习 · h=${plan.nextH.toStringAsFixed(1)} 天';
      });
    } catch (error) {
      if (mounted) setState(() => _gradeResult = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _grading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final isCustom = word.isCustom;
    final item = appState.progress[word.id];

    return Scaffold(
      appBar: AppBar(
        title: Text(word.word),
        actions: [
          if (_card != null && !isCustom)
            IconButton(
              tooltip: '重新生成讲解',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadingCard ? null : () => _generateCard(force: true),
            ),
          IconButton(
            tooltip: '单词网络',
            icon: const Icon(Icons.hub_outlined),
            onPressed: _openGraph,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HeaderCard(
            word: word,
            card: _card,
            isCustom: isCustom,
            onSpeak: () => appState.speak(word.word),
            status: item == null
                ? '未开始'
                : item.isDue(DateTime.now())
                    ? '待复习'
                    : '${item.masteryLabel} · 保持 ${item.h.toStringAsFixed(1)} 天',
            dueText: item == null
                ? '加入后由算法安排复习'
                : '下次复习：${item.daysUntilDue} 天后',
          ),
          const SizedBox(height: 16),
          _buildImage(),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 16, color: AppColors.seed),
                    SizedBox(width: 6),
                    Text(
                      'NGSL 英文释义',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.seed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  word.definitionEn.isEmpty ? '暂无释义' : word.definitionEn,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingCard)
            const AppCard(
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
                      '正在生成讲解、例句与场景……',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          else if (_card == null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生成单词卡',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '一次生成中文释义、音标、3 条例句、常见搭配、词族、词源和记忆技巧，并缓存到后端，后续秒开。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  if (_cardError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _cardError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.rose,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generateCard,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('生成讲解'),
                    ),
                  ),
                ],
              ),
            )
          else
            _CardBody(card: _card!, onSpeak: appState.speak),
          const SizedBox(height: 24),
          if (isCustom && word.isPhrase)
            AppCard(
              color: const Color(0xFFF5F3FF),
              child: const Row(
                children: [
                  Icon(Icons.short_text_rounded, color: AppColors.lavender),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '短语/搭配，仅查看详细内容，不进入记忆复习。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_card == null)
            AppCard(
              color: const Color(0xFFF5F3FF),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppColors.lavender),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '先生成讲解。生成后可以直接在下方选择掌握度学习，不需要再进学习页重复生成。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              color: const Color(0xFFF7F7FC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_alt_rounded,
                        size: 18,
                        color: AppColors.seed,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '直接记录掌握度',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (_graded)
                        const TagPill(text: '已学习', color: AppColors.mint),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '讲解内容已经生成，选一个档位即可学习/复习，不会重新生成。',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  if (!_graded)
                    GradeButtons(
                      onGrade: _grade,
                      busy: _grading,
                      compact: false,
                    ),
                  if (_gradeResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _gradeResult!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _gradeResult!.startsWith('保存失败')
                            ? AppColors.rose
                            : AppColors.mint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openGraph,
              icon: const Icon(Icons.hub_outlined),
              label: const Text('单词网络'),
            ),
          ),
        ],
      ),
    );
  }

  void _openGraph() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GraphScreen(centerWord: widget.word.word),
      ),
    );
  }

  Widget _buildImage() {
    if (_imageUrl != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: CachedImage(
                source: _imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF2F2FA),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (_, _, _) => _imagePlaceholder('图片加载失败'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.image_outlined,
                  size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '场景图：把单词和具体画面绑定',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed:
                    _loadingImage ? null : () => _generateImage(force: true),
                child: const Text('换一张', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      );
    }
    return _imagePlaceholder(
      _loadingImage ? '正在绘制场景图……' : '用一张场景图记住这个词',
    );
  }

  Widget _imagePlaceholder(String text) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lavender.withValues(alpha: 0.16),
            AppColors.seed.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_loadingImage)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.image_outlined, size: 34, color: AppColors.lavender),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_imageError != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _imageError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.rose),
              ),
            ),
          ],
          if (!_loadingImage)
            TextButton.icon(
              onPressed: _generateImage,
              icon: const Icon(Icons.brush_rounded, size: 18),
              label: const Text('生成配图'),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.word,
    required this.card,
    required this.isCustom,
    required this.onSpeak,
    required this.status,
    required this.dueText,
  });

  final Word word;
  final AiWordCard? card;
  final bool isCustom;
  final VoidCallback onSpeak;
  final String status;
  final String dueText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (card != null && card!.phoneticUs.isNotEmpty)
                          Text(
                            card!.phoneticUs,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        if (card != null && card!.phoneticUk.isNotEmpty)
                          Text(
                            '  ·  ${card!.phoneticUk}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TagPill(
                text: word.isPhrase
                    ? '短语/搭配'
                    : isCustom
                        ? '自定义词'
                        : 'NGSL #${word.rank}',
                color: isCustom ? AppColors.lavender : AppColors.seed,
              ),
              const SizedBox(width: 8),
              TagPill(text: status, color: AppColors.mint),
              const Spacer(),
              Text(
                dueText,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.card, required this.onSpeak});

  final AiWordCard card;
  final Future<void> Function(String text) onSpeak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.meanings.isNotEmpty) ...[
          const SectionHeader(title: '释义'),
          AppCard(
            child: Column(
              children: card.meanings.map((meaning) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          meaning.pos,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.seed,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meaning.zh,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            if (meaning.en.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                meaning.en,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (card.examples.isNotEmpty) ...[
          const SectionHeader(title: '例句'),
          AppCard(
            child: Column(
              children: card.examples.map((example) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
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
                                fontSize: 12,
                                color: AppColors.muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onSpeak(example.en),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          color: AppColors.seed,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (card.collocations.isNotEmpty) ...[
          const SectionHeader(title: '常见搭配'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: card.collocations
                .map(
                  (item) => TagPill(
                    text: '${item.phrase}  ${item.zh}',
                    color: AppColors.amber,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (card.wordFamily.isNotEmpty) ...[
          const SectionHeader(title: '词族'),
          AppCard(
            child: Column(
              children: card.wordFamily.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        item.word,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.pos,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.seed,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.zh,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (card.synonyms.isNotEmpty || card.antonyms.isNotEmpty) ...[
          const SectionHeader(title: '近义 / 反义'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in card.synonyms)
                TagPill(text: item, color: AppColors.mint),
              for (final item in card.antonyms)
                TagPill(text: item, color: AppColors.rose),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (card.etymology.isNotEmpty) ...[
          const SectionHeader(title: '词源'),
          AppCard(
            child: Text(
              card.etymology,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (card.memoryTip.isNotEmpty || card.scenario.isNotEmpty) ...[
          const SectionHeader(title: '记忆与场景'),
          AppCard(
            color: const Color(0xFFF5F3FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.memoryTip.isNotEmpty)
                  Text(
                    '记忆技巧：${card.memoryTip}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink,
                      height: 1.6,
                    ),
                  ),
                if (card.memoryTip.isNotEmpty && card.scenario.isNotEmpty)
                  const SizedBox(height: 8),
                if (card.scenario.isNotEmpty)
                  Text(
                    '使用场景：${card.scenario}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
