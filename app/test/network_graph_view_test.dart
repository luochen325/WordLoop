import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordloop/models/graph_data.dart';
import 'package:wordloop/screens/network_graph_view.dart';

void main() {
  testWidgets('点击节点触发选择，拖动后仍可点击', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selected;
    const data = GraphData(
      center: 'ability',
      nodes: [
        GraphNode(word: 'skill', relation: 'synonym', zh: '技能', strength: 0.9),
      ],
      edges: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkGraphView(
            data: data,
            onSelectNode: (word) => selected = word,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    // 第一个普通节点的初始世界坐标：angle = 2.399963，radius = 108 + 20。
    const angle = 2.399963;
    const radius = 128.0;
    final nodePosition = Offset(
      200 + math.cos(angle) * radius,
      400 + math.sin(angle) * radius,
    );

    await tester.tapAt(nodePosition);
    await tester.pump();
    expect(selected, 'skill');

    // 先拖动空白处平移画布，再点击同一个节点，验证不会因为拖动而失效。
    selected = null;
    await tester.dragFrom(const Offset(370, 120), const Offset(-40, 40));
    await tester.pump();

    await tester.tapAt(nodePosition + const Offset(-40, 40));
    await tester.pump();
    expect(selected, 'skill');
  });
}
