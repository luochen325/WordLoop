import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../data/demo_graphs.dart';
import '../models/graph_data.dart';
import '../theme.dart';

class NetworkGraphView extends StatefulWidget {
  const NetworkGraphView({
    super.key,
    required this.data,
    required this.onSelectNode,
  });

  final GraphData data;
  final ValueChanged<String> onSelectNode;

  @override
  State<NetworkGraphView> createState() => _NetworkGraphViewState();
}

class _GraphNode {
  _GraphNode({
    required this.word,
    required this.zh,
    required this.relation,
    required this.strength,
    required this.isCenter,
    required this.index,
  }) {
    final angle = index * 2.399963;
    final radius = 108 + 20 * math.sqrt(index.toDouble());
    x = math.cos(angle) * radius;
    y = math.sin(angle) * radius;
  }

  final String word;
  final String zh;
  final String relation;
  final double strength;
  final bool isCenter;
  final int index;

  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;

  double get radius => isCenter ? 36 : 24 + strength * 8;
}

class _NetworkGraphViewState extends State<NetworkGraphView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_GraphNode> _nodes = [];
  Offset _pan = Offset.zero;
  _GraphNode? _dragging;
  _GraphNode? _tapCandidate;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _rebuildNodes();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant NetworkGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.center != widget.data.center ||
        oldWidget.data.nodes.length != widget.data.nodes.length) {
      _rebuildNodes();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _rebuildNodes() {
    final existing = {for (final node in _nodes) node.word: node};
    _nodes
      ..clear()
      ..add(
        _GraphNode(
          word: widget.data.center,
          zh: '',
          relation: 'center',
          strength: 1,
          isCenter: true,
          index: 0,
        ),
      );

    for (var i = 0; i < widget.data.nodes.length; i++) {
      final item = widget.data.nodes[i];
      final node = _GraphNode(
        word: item.word,
        zh: item.zh,
        relation: item.relation,
        strength: item.strength,
        isCenter: false,
        index: i + 1,
      );
      final old = existing[item.word];
      if (old != null) {
        node
          ..x = old.x
          ..y = old.y;
      }
      _nodes.add(node);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    var energy = 0.0;

    final center = _nodes.first;
    center
      ..x = 0
      ..y = 0
      ..vx = 0
      ..vy = 0;

    for (var i = 1; i < _nodes.length; i++) {
      final a = _nodes[i];
      // 与其它节点排斥
      for (var j = 1; j < _nodes.length; j++) {
        if (i == j) continue;
        final b = _nodes[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final distSq = math.max(dx * dx + dy * dy, 36.0);
        final dist = math.sqrt(distSq);
        final force = math.min(6500 / distSq, 8.0);
        a.vx += dx / dist * force;
        a.vy += dy / dist * force;
      }

      // 与中心节点保持弹性距离
      final dx = a.x - center.x;
      final dy = a.y - center.y;
      final dist = math.max(math.sqrt(dx * dx + dy * dy), 0.01);
      final rest = 126 + a.strength * 30;
      final spring = (dist - rest) * 0.012 * (0.5 + a.strength);
      a.vx -= dx / dist * spring;
      a.vy -= dy / dist * spring;

      a.vx *= 0.86;
      a.vy *= 0.86;
      a.x += a.vx;
      a.y += a.vy;

      final limit = 520.0;
      final radius = math.sqrt(a.x * a.x + a.y * a.y);
      if (radius > limit) {
        a.x = a.x / radius * limit;
        a.y = a.y / radius * limit;
      }
      energy += a.vx.abs() + a.vy.abs();
    }

    if (energy > 0.05 || _dragging != null) {
      setState(() {});
    }
  }

  Offset _toWorld(Offset local) =>
      local - _size.center(Offset.zero) - _pan;

  _GraphNode? _hitTest(Offset local) {
    final world = _toWorld(local);
    for (final node in _nodes.reversed) {
      final dx = world.dx - node.x;
      final dy = world.dy - node.y;
      final hitRadius = node.radius + 26;
      if (dx * dx + dy * dy <= hitRadius * hitRadius) {
        return node;
      }
      // 单词和中文标签也算点击区域
      final labelRect = Rect.fromCenter(
        center: Offset(node.x, node.y + node.radius + 16),
        width: math.max(80, node.word.length * 9.0),
        height: 30,
      );
      if (labelRect.contains(world)) {
        return node;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _dragging = _hitTest(details.localPosition);
          },
          onPanUpdate: (details) {
            setState(() {
              if (_dragging != null) {
                _dragging!.x += details.delta.dx;
                _dragging!.y += details.delta.dy;
                _dragging!.vx = 0;
                _dragging!.vy = 0;
              } else {
                _pan += details.delta;
              }
            });
          },
          onPanEnd: (_) {
            _dragging = null;
          },
          // 按下时就确定命中的节点：网络里的节点一直在轻微移动，
          // 用抬起时的坐标去命中容易错过，导致“点了没反应”。
          onTapDown: (details) {
            _tapCandidate = _hitTest(details.localPosition);
          },
          onTapCancel: () {
            _tapCandidate = null;
          },
          onTapUp: (details) {
            final node = _tapCandidate ?? _hitTest(details.localPosition);
            _tapCandidate = null;
            if (node != null) {
              widget.onSelectNode(node.word);
            }
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _GraphPainter(nodes: _nodes, pan: _pan),
          ),
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.nodes, required this.pan});

  final List<_GraphNode> nodes;
  final Offset pan;

  static const Map<String, Color> colors = {
    'synonym': AppColors.mint,
    'antonym': AppColors.rose,
    'word_family': AppColors.seed,
    'collocation': AppColors.amber,
    'scene': Color(0xFF3B82F6),
    'root': AppColors.lavender,
  };

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(canvas, size);
    canvas.save();
    canvas.translate(size.width / 2 + pan.dx, size.height / 2 + pan.dy);

    if (nodes.isEmpty) {
      canvas.restore();
      return;
    }

    final center = nodes.first;

    // 边
    for (var i = 1; i < nodes.length; i++) {
      final node = nodes[i];
      final color = colors[node.relation] ?? AppColors.seed;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.28 + node.strength * 0.35)
        ..strokeWidth = 1.2 + node.strength * 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.x, center.y),
        Offset(node.x, node.y),
        paint,
      );

      final mid = Offset(
        center.x + (node.x - center.x) * 0.56,
        center.y + (node.y - center.y) * 0.56,
      );
      _text(
        canvas,
        relationLabels[node.relation] ?? node.relation,
        mid,
        TextStyle(
          fontSize: 9,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
        center: true,
      );
    }

    // 非中心节点
    for (var i = 1; i < nodes.length; i++) {
      final node = nodes[i];
      final color = colors[node.relation] ?? AppColors.seed;
      final offset = Offset(node.x, node.y);

      canvas.drawCircle(
        offset + const Offset(0, 3),
        node.radius,
        Paint()
          ..color = const Color(0x18000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(offset, node.radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        offset,
        node.radius - 2,
        Paint()..color = color.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        offset,
        node.radius - 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      _text(
        canvas,
        node.word,
        offset,
        TextStyle(
          fontSize: node.word.length > 10 ? 9 : 11,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        center: true,
        maxWidth: node.radius * 1.9,
      );

      _text(
        canvas,
        node.zh,
        offset + Offset(0, node.radius + 11),
        const TextStyle(fontSize: 9, color: AppColors.muted),
        center: true,
        maxWidth: 90,
      );
    }

    // 中心节点
    canvas.drawCircle(
      const Offset(0, 0),
      50,
      Paint()..color = AppColors.seed.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      const Offset(0, 0),
      center.radius + 6,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A5FF0), Color(0xFF8B5CF6)],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: center.radius + 6),
        ),
    );
    _text(
      canvas,
      center.word,
      Offset.zero,
      const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      center: true,
      maxWidth: 70,
    );

    canvas.restore();
  }

  void _paintDots(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x14000000);
    for (var x = 16.0; x < size.width; x += 26) {
      for (var y = 16.0; y < size.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool center = false,
    double maxWidth = 120,
  }) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = center ? offset.dx - painter.width / 2 : offset.dx;
    final dy = center ? offset.dy - painter.height / 2 : offset.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
