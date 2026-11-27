import 'package:flutter_test/flutter_test.dart';
import 'package:wordloop/services/scheduler.dart';

void main() {
  final table = PolicyTable(
    hValues: const [0.2, 1.0, 10.0, 100.0, 360.0],
    dValues: const [1.0, 5.0, 10.0],
    policy: const [
      [1, 1, 8, 30, 0],
      [1, 1, 5, 21, 0],
      [1, 1, 3, 12, 0],
    ],
  );
  final scheduler = MemoryScheduler(table);

  test('回忆概率随时间衰减', () {
    expect(scheduler.recallProbability(10, 0), 1);
    expect(scheduler.recallProbability(10, 10), closeTo(0.5, 1e-9));
    expect(
      scheduler.recallProbability(10, 20),
      lessThan(scheduler.recallProbability(10, 10)),
    );
  });

  test('回忆成功提升半衰期，失败提升难度', () {
    const state = MemoryState(h: 5, d: 4);
    final success = scheduler.nextState(state, 5, true);
    expect(success.h, greaterThan(5));
    expect(success.d, 4);

    final failure = scheduler.nextState(const MemoryState(h: 30, d: 4), 30, false);
    expect(failure.h, lessThan(30));
    expect(failure.d, greaterThan(4));
  });

  test('查表间隔在合理范围内', () {
    final plan = scheduler.plan(
      h: 10,
      d: 5,
      daysSince: 3,
      grade: ReviewGrade.good,
    );
    expect(plan.intervalDays, inInclusiveRange(1, 180));
    expect(plan.nextH, greaterThan(10));
  });

  test('达到目标半衰期后进入维护间隔', () {
    final plan = scheduler.plan(
      h: 400,
      d: 5,
      daysSince: 180,
      grade: ReviewGrade.good,
      lastInterval: 30,
    );
    expect(plan.intervalDays, 365);
  });

  test('首轮间隔按难度打散', () {
    expect(
      firstIntervalForDifficulty(
        difficulty: 3,
        wordId: 1,
        grade: ReviewGrade.good,
      ),
      3,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 3,
        wordId: 2,
        grade: ReviewGrade.good,
      ),
      2,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 9,
        wordId: 1,
        grade: ReviewGrade.good,
      ),
      2,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 9,
        wordId: 2,
        grade: ReviewGrade.good,
      ),
      1,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 15,
        wordId: 1,
        grade: ReviewGrade.good,
      ),
      1,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 3,
        wordId: 1,
        grade: ReviewGrade.again,
      ),
      1,
    );
    expect(
      firstIntervalForDifficulty(
        difficulty: 3,
        wordId: 1,
        grade: ReviewGrade.hard,
      ),
      1,
    );
  });

  test('四档评分产生不同结果', () {
    final again = scheduler.plan(
      h: 10,
      d: 5,
      daysSince: 5,
      grade: ReviewGrade.again,
      lastInterval: 10,
    );
    final good = scheduler.plan(
      h: 10,
      d: 5,
      daysSince: 5,
      grade: ReviewGrade.good,
      lastInterval: 10,
    );
    final easy = scheduler.plan(
      h: 10,
      d: 5,
      daysSince: 5,
      grade: ReviewGrade.easy,
      lastInterval: 10,
    );

    expect(again.nextH, lessThan(10));
    expect(good.nextH, greaterThan(10));
    expect(easy.nextH, greaterThan(good.nextH));
    expect(again.intervalDays, inInclusiveRange(1, 730));
  });

  test('过早复习时失败不会比成功更晚复习', () {
    final again = scheduler.plan(
      h: 5,
      d: 1,
      daysSince: 0,
      grade: ReviewGrade.again,
    );
    final hard = scheduler.plan(
      h: 5,
      d: 1,
      daysSince: 0,
      grade: ReviewGrade.hard,
    );
    final good = scheduler.plan(
      h: 5,
      d: 1,
      daysSince: 0,
      grade: ReviewGrade.good,
    );

    expect(again.nextH, lessThanOrEqualTo(5));
    expect(hard.nextH, lessThanOrEqualTo(5));
    expect(again.intervalDays, lessThanOrEqualTo(good.intervalDays));
    expect(hard.intervalDays, lessThanOrEqualTo(good.intervalDays));
  });
}
