import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordloop/services/scheduler.dart';

/// 用后端同一张 policy.json 做数值对照，确保 App 端与后端算出的间隔一致。
void main() {
  late MemoryScheduler scheduler;

  setUpAll(() {
    final raw = File('assets/data/policy.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    scheduler = MemoryScheduler(PolicyTable.fromJson(json));
  });

  test('与后端 /api/review/plan 的参考结果一致', () {
    final cases = [
      (
        h: 2.5,
        d: 1.0,
        days: 0.0,
        last: 1.0,
        interval: 1,
        nextH: 2.5132,
      ),
      (
        h: 5.0,
        d: 3.0,
        days: 5.0,
        last: 3.0,
        interval: 8,
        nextH: 57.2494,
      ),
      (
        h: 20.0,
        d: 5.0,
        days: 10.0,
        last: 7.0,
        interval: 12,
        nextH: 99.4180,
      ),
      (
        h: 100.0,
        d: 7.0,
        days: 30.0,
        last: 14.0,
        interval: 15,
        nextH: 275.6899,
      ),
      (
        h: 1.0,
        d: 9.0,
        days: 2.0,
        last: 1.0,
        interval: 3,
        nextH: 11.5659,
      ),
    ];

    for (final item in cases) {
      final plan = scheduler.plan(
        h: item.h,
        d: item.d,
        daysSince: item.days,
        grade: ReviewGrade.good,
        lastInterval: item.last,
      );
      expect(plan.intervalDays, item.interval, reason: 'h=${item.h}');
      expect(plan.nextH, closeTo(item.nextH, 0.002), reason: 'h=${item.h}');
    }
  });
}
