import '../models/graph_data.dart';

const Map<String, String> relationLabels = {
  'synonym': '同义',
  'antonym': '反义',
  'word_family': '派生',
  'collocation': '搭配',
  'scene': '场景',
  'root': '词根',
};

GraphData _build(String center, List<List<Object>> items) {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  for (final item in items) {
    final word = item[0] as String;
    final relation = item[1] as String;
    final zh = item[2] as String;
    final strength = (item[3] as num).toDouble();
    nodes.add(
      GraphNode(word: word, relation: relation, zh: zh, strength: strength),
    );
    edges.add(
      GraphEdge(
        source: center,
        target: word,
        relation: relation,
        strength: strength,
      ),
    );
  }
  return GraphData(center: center, nodes: nodes, edges: edges);
}

final Map<String, GraphData> demoGraphs = {
  'ability': _build('ability', [
    ['able', 'word_family', '能够的', 0.95],
    ['capability', 'synonym', '能力', 0.9],
    ['skill', 'synonym', '技能', 0.85],
    ['talent', 'synonym', '天赋', 0.8],
    ['inability', 'antonym', '无能力', 0.75],
    ['enable', 'word_family', '使能够', 0.85],
    ['potential', 'scene', '潜力', 0.7],
  ]),
  'abandon': _build('abandon', [
    ['give up', 'synonym', '放弃', 0.95],
    ['quit', 'synonym', '退出', 0.85],
    ['desert', 'synonym', '抛弃', 0.8],
    ['keep', 'antonym', '保留', 0.8],
    ['continue', 'antonym', '继续', 0.75],
    ['abandoned', 'word_family', '被遗弃的', 0.85],
    ['abandonment', 'word_family', '遗弃', 0.8],
  ]),
  'accept': _build('accept', [
    ['receive', 'synonym', '收到', 0.9],
    ['agree', 'synonym', '同意', 0.85],
    ['refuse', 'antonym', '拒绝', 0.9],
    ['reject', 'antonym', '驳回', 0.85],
    ['acceptable', 'word_family', '可接受的', 0.8],
    ['acceptance', 'word_family', '接受', 0.8],
    ['accept an offer', 'collocation', '接受邀请', 0.75],
  ]),
  'achieve': _build('achieve', [
    ['accomplish', 'synonym', '完成', 0.9],
    ['reach', 'synonym', '达到', 0.85],
    ['fail', 'antonym', '失败', 0.85],
    ['achievement', 'word_family', '成就', 0.9],
    ['achievable', 'word_family', '可实现的', 0.8],
    ['achieve a goal', 'collocation', '实现目标', 0.9],
    ['success', 'scene', '成功', 0.75],
  ]),
  'learn': _build('learn', [
    ['study', 'synonym', '学习', 0.9],
    ['acquire', 'synonym', '习得', 0.8],
    ['teach', 'antonym', '教授', 0.75],
    ['learner', 'word_family', '学习者', 0.85],
    ['learning', 'word_family', '学习过程', 0.85],
    ['memorize', 'scene', '记忆', 0.75],
    ['practice', 'scene', '练习', 0.8],
  ]),
  'travel': _build('travel', [
    ['journey', 'synonym', '旅程', 0.9],
    ['trip', 'synonym', '旅行', 0.9],
    ['tour', 'synonym', '游览', 0.8],
    ['stay', 'antonym', '停留', 0.7],
    ['traveler', 'word_family', '旅行者', 0.85],
    ['travel abroad', 'collocation', '出国旅行', 0.85],
    ['airport', 'scene', '机场', 0.8],
    ['hotel', 'scene', '酒店', 0.75],
  ]),
  'money': _build('money', [
    ['cash', 'synonym', '现金', 0.9],
    ['currency', 'synonym', '货币', 0.8],
    ['pay', 'collocation', '支付', 0.85],
    ['save money', 'collocation', '存钱', 0.85],
    ['bank', 'scene', '银行', 0.85],
    ['price', 'scene', '价格', 0.8],
    ['expensive', 'scene', '昂贵的', 0.7],
  ]),
  'work': _build('work', [
    ['job', 'synonym', '工作', 0.9],
    ['labor', 'synonym', '劳动', 0.8],
    ['rest', 'antonym', '休息', 0.75],
    ['worker', 'word_family', '工作者', 0.85],
    ['workplace', 'word_family', '工作场所', 0.8],
    ['office', 'scene', '办公室', 0.8],
    ['meeting', 'scene', '会议', 0.75],
    ['deadline', 'scene', '截止日期', 0.7],
  ]),
  'friend': _build('friend', [
    ['companion', 'synonym', '同伴', 0.85],
    ['buddy', 'synonym', '伙伴', 0.8],
    ['enemy', 'antonym', '敌人', 0.8],
    ['friendly', 'word_family', '友好的', 0.9],
    ['friendship', 'word_family', '友谊', 0.9],
    ['trust', 'scene', '信任', 0.75],
    ['together', 'scene', '一起', 0.7],
  ]),
};

GraphData? demoGraphFor(String word) {
  final key = word.toLowerCase();
  final direct = demoGraphs[key];
  if (direct != null) return direct;

  // 没有独立示例时，从所有示例中找出包含该词的语义簇，拼一个可继续点击的网络
  final centers = <String>{};
  final siblings = <String, GraphNode>{};
  for (final graph in demoGraphs.values) {
    final hit = graph.nodes.where((node) => node.word.toLowerCase() == key);
    if (hit.isEmpty) continue;
    centers.add(graph.center);
    for (final node in graph.nodes) {
      if (node.word.toLowerCase() != key) {
        siblings[node.word] = node;
      }
    }
  }
  if (centers.isEmpty) return null;

  final nodes = <GraphNode>[];
  for (final center in centers) {
    nodes.add(
      GraphNode(word: center, relation: 'scene', zh: '相关中心词', strength: 0.8),
    );
  }
  for (final node in siblings.values) {
    if (nodes.length >= 9) break;
    if (node.word.toLowerCase() == key) continue;
    nodes.add(node);
  }

  return GraphData(
    center: word,
    nodes: nodes,
    edges: [
      for (final node in nodes)
        GraphEdge(
          source: word,
          target: node.word,
          relation: node.relation,
          strength: node.strength,
        ),
    ],
  );
}
