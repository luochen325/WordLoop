class GraphNode {
  const GraphNode({
    required this.word,
    required this.relation,
    required this.zh,
    required this.strength,
  });

  final String word;
  final String relation;
  final String zh;
  final double strength;
}

class GraphEdge {
  const GraphEdge({
    required this.source,
    required this.target,
    required this.relation,
    required this.strength,
  });

  final String source;
  final String target;
  final String relation;
  final double strength;
}

class GraphData {
  const GraphData({
    required this.center,
    required this.nodes,
    required this.edges,
  });

  final String center;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  factory GraphData.fromJson(Map<String, dynamic> json) {
    final nodes = (json['nodes'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => GraphNode(
            word: (item['word'] as String?) ?? '',
            relation: (item['relation'] as String?) ?? 'scene',
            zh: (item['zh'] as String?) ?? '',
            strength: (item['strength'] as num?)?.toDouble() ?? 0.5,
          ),
        )
        .where((node) => node.word.isNotEmpty)
        .toList();

    final edges = (json['edges'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => GraphEdge(
            source: (item['source'] as String?) ?? '',
            target: (item['target'] as String?) ?? '',
            relation: (item['relation'] as String?) ?? 'scene',
            strength: (item['strength'] as num?)?.toDouble() ?? 0.5,
          ),
        )
        .where((edge) => edge.source.isNotEmpty && edge.target.isNotEmpty)
        .toList();

    return GraphData(
      center: (json['center'] as String?) ?? '',
      nodes: nodes,
      edges: edges,
    );
  }

  static const empty = GraphData(center: '', nodes: [], edges: []);
}
