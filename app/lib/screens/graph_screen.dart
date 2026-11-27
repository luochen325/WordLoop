import 'package:material_ui/material_ui.dart';

import '../data/demo_graphs.dart';
import '../models/ai_word_card.dart';
import '../models/graph_data.dart';
import '../services/app_state.dart';
import '../services/scheduler.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/grade_buttons.dart';
import 'network_graph_view.dart';
import 'word_detail_screen.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key, required this.centerWord});

  final String centerWord;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late String _center;
  final List<String> _history = [];
  GraphData? _data;
  bool _loading = true;
  bool _usedDemo = false;
  String? _error;

  String? _infoWord;
  String _infoZh = '';
  String _infoRelation = 'scene';
  Color _infoColor = AppColors.seed;

  @override
  void initState() {
    super.initState();
    _center = widget.centerWord;
    _load(_center);
  }

  Future<void> _load(String word, {bool force = false}) async {
    setState(() {
      _center = word;
      _loading = true;
      _error = null;
      _usedDemo = false;
    });

    try {
      var data = await appState.loadGraph(word, force: force);
      var usedDemo = false;
      if (data.nodes.isEmpty) {
        final demo = demoGraphFor(word);
        if (demo != null) {
          data = demo;
          usedDemo = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _usedDemo = usedDemo;
        _error = data.nodes.isEmpty ? '这个单词暂时没有生成关联网络' : null;
        _loading = false;
      });
    } catch (error) {
      final demo = demoGraphFor(word);
      if (!mounted) return;
      setState(() {
        _data = demo;
        _usedDemo = demo != null;
        _error = demo == null ? '无法连接内容服务，请检查设置中的后端地址' : null;
        _loading = false;
      });
      if (demo == null) {
        debugPrint('graph error: $error');
      }
    }
  }

  /// 点击节点：立刻把该词设为新中心并重新生成关系网络，同时生成它的 AI 信息。
  void _selectNode(String word) {
    GraphNode? node;
    for (final item in _data?.nodes ?? const <GraphNode>[]) {
      if (item.word.toLowerCase() == word.toLowerCase()) {
        node = item;
        break;
      }
    }

    final relation = node?.relation ?? 'scene';
    setState(() {
      _infoWord = word;
      _infoZh = node?.zh ?? '';
      _infoRelation = relation;
      _infoColor = _relationColor(relation);
    });

    if (word.toLowerCase() != _center.toLowerCase()) {
      // 每次点击都重新生成一组新的关联词，形成“不断生长”的网络
      _switchCenter(word, force: true);
    }
  }

  void _switchCenter(String word, {bool force = false}) {
    _history.add(_center);
    _load(word, force: force);
  }

  void _goBack() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    setState(() => _infoWord = null);
    _load(previous);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final infoWord = _infoWord;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('单词网络'),
            Text(
              _center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: '返回上一个中心',
              icon: const Icon(Icons.undo_rounded),
              onPressed: _goBack,
            ),
          IconButton(
            tooltip: '重新生成当前中心的关系网络',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => _load(_center, force: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (data != null && data.nodes.isNotEmpty)
            Positioned.fill(
              child: NetworkGraphView(
                data: data,
                onSelectNode: _selectNode,
              ),
            ),
          if (data != null && data.nodes.isNotEmpty)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '点击节点：立即切换中心并生成详解 · 拖动整理布局',
                      style: TextStyle(
                        fontSize: 11,
                        color: _usedDemo ? AppColors.amber : AppColors.muted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_usedDemo)
                    const TagPill(
                      text: '本地示例',
                      color: AppColors.amber,
                      filled: true,
                    ),
                ],
              ),
            ),
          if (data != null && data.nodes.isNotEmpty && infoWord == null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: relationLabels.entries.map((entry) {
                    final color = _relationColor(entry.key);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.72),
                child: Center(
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '正在构建「$_center」的单词网络…',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_loading && (data == null || data.nodes.isEmpty))
            Positioned.fill(
              child: EmptyState(
                icon: Icons.hub_outlined,
                title: '还没有关系网络',
                message: _error ?? '点击右上角刷新，生成这个单词的关联词。',
                action: demoGraphFor('ability') == null
                    ? null
                    : FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const GraphScreen(centerWord: 'ability'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('查看 ability 示例网络'),
                      ),
              ),
            ),
          if (infoWord != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _InfoPanel(
                key: ValueKey(infoWord),
                word: infoWord,
                zh: _infoZh,
                relation: _infoRelation,
                color: _infoColor,
                onClose: () => setState(() => _infoWord = null),
              ),
            ),
        ],
      ),
    );
  }

  Color _relationColor(String relation) {
    switch (relation) {
      case 'synonym':
        return AppColors.mint;
      case 'antonym':
        return AppColors.rose;
      case 'word_family':
        return AppColors.seed;
      case 'collocation':
        return AppColors.amber;
      case 'root':
        return AppColors.lavender;
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

class _InfoPanel extends StatefulWidget {
  const _InfoPanel({
    super.key,
    required this.word,
    required this.zh,
    required this.relation,
    required this.color,
    required this.onClose,
  });

  final String word;
  final String zh;
  final String relation;
  final Color color;
  final VoidCallback onClose;

  @override
  State<_InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<_InfoPanel> {
  AiWordCard? _card;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _graded = false;
  bool _isPhrase = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _isPhrase = widget.word.trim().contains(' ');
    final existing = appState.wordByText(widget.word);
    if (existing != null) {
      final item = appState.progress[existing.id];
      if (item != null) {
        _graded = true;
        _result = item.isDue(DateTime.now())
            ? '已学习 · 今天待复习'
            : '已学习 · 下次 ${item.daysUntilDue} 天后复习';
      }
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await appState.lookupWord(widget.word);
      if (mounted) setState(() => _card = card);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 信息卡里已经生成了 AI 内容，直接记录四档掌握度，不再跳到学习页重复生成。
  Future<void> _grade(ReviewGrade grade) async {
    var word = appState.wordByText(widget.word);
    if (word == null) {
      final meaning = _card != null && _card!.meanings.isNotEmpty
          ? (_card!.meanings.first.en.isNotEmpty
              ? _card!.meanings.first.en
              : _card!.meanings.first.zh)
          : '';
      word = await appState.addCustomWord(
        widget.word,
        definitionEn: meaning,
      );
    }
    setState(() {
      _saving = true;
      _result = null;
    });
    try {
      final started = appState.progress.containsKey(word.id);
      final plan = started
          ? await appState.answer(word.id, grade: grade)
          : await appState.startWord(word.id, grade: grade);
      if (!mounted) return;
      setState(() {
        _graded = true;
        _result =
            '${grade.label} · 下次 ${plan.intervalDays} 天后复习 · h=${plan.nextH.toStringAsFixed(1)} 天';
      });
    } catch (error) {
      if (mounted) setState(() => _result = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDetail() async {
    var word = appState.wordByText(widget.word);
    if (word == null) {
      final meaning = _card != null && _card!.meanings.isNotEmpty
          ? (_card!.meanings.first.en.isNotEmpty
              ? _card!.meanings.first.en
              : _card!.meanings.first.zh)
          : '';
      if (widget.word.trim().contains(' ')) {
        word = appState.ephemeralWord(widget.word, definitionEn: meaning);
      } else {
        word = await appState.addCustomWord(
          widget.word,
          definitionEn: meaning,
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WordDetailScreen(word: word!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationLabel = relationLabels[widget.relation] ?? widget.relation;

    return Container(
      constraints: const BoxConstraints(maxHeight: 345),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241B1C3A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.word,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TagPill(text: relationLabel, color: widget.color),
                        ],
                      ),
                      if (widget.zh.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.zh,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '正在生成该词的信息…',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              )
            else if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '信息加载失败：$_error',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.rose,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('重试', style: TextStyle(fontSize: 11)),
                  ),
                ],
              )
            else if (_card != null) ...[
              for (final meaning in _card!.meanings.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          meaning.pos,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.seed,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          meaning.zh,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_card!.examples.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _card!.examples.first.en,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                        color: AppColors.seed,
                      ),
                      onPressed: () => appState.speak(_card!.examples.first.en),
                    ),
                  ],
                ),
            ],
            if (_card != null) ...[
              const SizedBox(height: 8),
              if (_isPhrase)
                const Text(
                  '短语/搭配，仅查看详细内容，不进入复习',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                )
              else if (_graded)
                Row(
                  children: [
                    const TagPill(text: '已学习', color: AppColors.mint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result ?? '已加入复习列表',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                const Text(
                  '直接记录掌握度',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                GradeButtons(onGrade: _grade, busy: _saving),
                if (_result != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _result!,
                    style: TextStyle(
                      fontSize: 10,
                      color: _result!.startsWith('保存失败')
                          ? AppColors.rose
                          : AppColors.mint,
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _openDetail,
                  icon: const Icon(Icons.menu_book_rounded, size: 15),
                  label: const Text(
                    '完整单词卡',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const Spacer(),
                const Text(
                  '已切换为新中心',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
