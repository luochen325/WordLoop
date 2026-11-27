import 'dart:math' as math;

const double targetHalflife = 365;
const int maintenanceIntervalDays = 365;
const int maxIntervalDays = 730;
const double hMin = 0.05;
const double hMax = 3650;
const double dMin = 1;
const double dMax = 18;
const double dFailStep = 2;

/// 四档掌握度评分。
///
/// 论文中的 DHP 模型只有“记住/忘记”二元反馈，这里把用户评分映射到
/// 二元状态转移之上，并额外调整稳定性与间隔，形成可解释的细分标准。
enum ReviewGrade { again, hard, good, easy }

extension ReviewGradeInfo on ReviewGrade {
  /// 用户看到的按钮文字
  String get label {
    switch (this) {
      case ReviewGrade.again:
        return '忘记';
      case ReviewGrade.hard:
        return '模糊';
      case ReviewGrade.good:
        return '想起';
      case ReviewGrade.easy:
        return '熟练';
    }
  }

  /// 判定标准
  String get description {
    switch (this) {
      case ReviewGrade.again:
        return '完全想不起来，或认错意思';
      case ReviewGrade.hard:
        return '有印象，但需要看答案才能确定';
      case ReviewGrade.good:
        return '能正确说出主要中文意思';
      case ReviewGrade.easy:
        return '1 秒内反应，还能说出搭配或例句';
    }
  }

  /// 对记忆状态的影响说明
  String get effect {
    switch (this) {
      case ReviewGrade.again:
        return '官方失败反馈：难度 +2，半衰期额外下降，间隔重算';
      case ReviewGrade.hard:
        return '官方失败反馈：难度 +2，按失败状态重新查表';
      case ReviewGrade.good:
        return '官方成功反馈：按 SSP-MMC 策略表安排';
      case ReviewGrade.easy:
        return '成功反馈 + 稳定性额外 +6%，间隔按新状态查表';
    }
  }

  bool get recalled => this == ReviewGrade.good || this == ReviewGrade.easy;

  int get value => index + 1;
}

class MemoryState {
  const MemoryState({required this.h, required this.d});

  final double h;
  final double d;
}

class PlanResult {
  const PlanResult({
    required this.probability,
    required this.intervalDays,
    required this.nextH,
    required this.nextD,
  });

  final double probability;
  final int intervalDays;
  final double nextH;
  final double nextD;
}

class PolicyTable {
  PolicyTable({
    required this.hValues,
    required this.dValues,
    required this.policy,
    this.hBase = 1.05,
    this.hMinIndex = -30,
  });

  final List<double> hValues;
  final List<double> dValues;
  final List<List<int>> policy;
  final double hBase;
  final int hMinIndex;

  factory PolicyTable.fromJson(Map<String, dynamic> json) {
    final hValues =
        (json['h_values'] as List).map((v) => (v as num).toDouble()).toList();
    final dValues =
        (json['d_values'] as List).map((v) => (v as num).toDouble()).toList();
    final policy = (json['policy'] as List)
        .map((row) => (row as List).map((v) => (v as num).toInt()).toList())
        .toList();
    return PolicyTable(
      hValues: hValues,
      dValues: dValues,
      policy: policy,
      hBase: (json['h_base'] as num?)?.toDouble() ?? 1.05,
      hMinIndex: (json['h_min_index'] as num?)?.toInt() ?? -30,
    );
  }

  int intervalFor(double h, double d) {
    final hi = _hIndex(h);
    final di = _dIndex(d);
    return policy[di][hi];
  }

  int _hIndex(double h) {
    if (h <= hValues.first) return 0;
    if (h >= targetHalflife) return hValues.length - 1;
    final idx =
        (math.log(h) / math.log(hBase)).round() - hMinIndex;
    return idx.clamp(0, hValues.length - 2);
  }

  int _dIndex(double d) {
    final idx = (d.round() - dValues.first.round());
    return idx.clamp(0, dValues.length - 1);
  }
}

class MemoryScheduler {
  MemoryScheduler(this.policy);

  final PolicyTable policy;
  double recallProbability(double h, double days) {
    if (h <= 0) return 0;
    return math.pow(2, -math.max(days, 0) / h).toDouble();
  }

  /// 二元状态转移（官方 cal_next_recall_halflife）
  MemoryState nextState(MemoryState state, double days, bool recalled) {
    final h = state.h.clamp(hMin, hMax);
    final d = state.d.clamp(dMin, dMax);
    final p = recallProbability(h, days);
    final forgetting = math.max(1 - p, 1e-4);

    double nextH;
    double nextD;
    if (recalled) {
      final growth = math.exp(3.81) *
          math.pow(d, -0.534) *
          math.pow(h, -0.127) *
          math.pow(forgetting, 0.970);
      nextH = h * (growth + 1);
      nextD = d;
    } else {
      nextH = math.exp(-0.041) *
          math.pow(d, -0.041) *
          math.pow(h, 0.377) *
          math.pow(forgetting, -0.227);
      // 官方 algo/main.cpp: 失败后难度 +2
      nextD = math.min(dMax, d + dFailStep);
    }

    return MemoryState(
      h: nextH.clamp(hMin, hMax),
      d: nextD.clamp(dMin, dMax),
    );
  }

  /// 四档评分下的状态与间隔计算。
  /// 间隔直接取官方 SSP-MMC 策略表，不做固定阶梯或额外平滑。
  PlanResult plan({
    required double h,
    required double d,
    required double daysSince,
    required ReviewGrade grade,
    double? lastInterval,
  }) {
    final probability = recallProbability(h, daysSince);
    final base = MemoryState(h: h, d: d);
    final success = nextState(base, daysSince, true);
    final fail = nextState(base, daysSince, false);

    // 复习过早（刚学完就再评一次）时官方失败公式会推高半衰期，
    // 失败不应该让稳定性上升，这里限制不超过当前半衰期。
    final hardH = math.min(fail.h, h);
    final easyState = MemoryState(
      h: (success.h * 1.06).clamp(hMin, hMax),
      d: success.d,
    );
    final hardState = MemoryState(h: hardH.clamp(hMin, hMax), d: fail.d);
    final againState = MemoryState(
      h: (hardH * 0.8).clamp(hMin, hMax),
      d: fail.d,
    );

    // 策略表在个别边界上并非严格单调，这里强制四档间隔满足
    // 忘记 ≤ 模糊 ≤ 想起 ≤ 熟练，避免出现“点熟练反而更早复习”。
    final goodInterval = policy.intervalFor(success.h, success.d);
    final easyInterval = math.max(
      policy.intervalFor(easyState.h, easyState.d),
      goodInterval,
    );
    final hardIntervalRaw = policy.intervalFor(hardState.h, hardState.d);
    final hardInterval = goodInterval > 0
        ? math.min(hardIntervalRaw, goodInterval)
        : hardIntervalRaw;
    final againInterval = math.min(
      policy.intervalFor(againState.h, againState.d),
      hardInterval,
    );

    MemoryState state;
    int interval;
    switch (grade) {
      case ReviewGrade.good:
        state = success;
        interval = goodInterval;
      case ReviewGrade.easy:
        state = easyState;
        interval = easyInterval;
      case ReviewGrade.hard:
        state = hardState;
        interval = hardInterval;
      case ReviewGrade.again:
        state = againState;
        interval = againInterval;
    }

    // 策略表的终止状态：已掌握，进入维护复习
    if (state.h >= targetHalflife || interval <= 0) {
      return PlanResult(
        probability: probability,
        intervalDays: maintenanceIntervalDays,
        nextH: state.h,
        nextD: state.d,
      );
    }

    return PlanResult(
      probability: probability,
      intervalDays: interval.clamp(1, maxIntervalDays),
      nextH: state.h,
      nextD: state.d,
    );
  }

  double daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inMinutes / (60 * 24);
  }
}

/// 首轮间隔打散：新词第一次复习按难度分散到 1~3 天后，
/// 避免所有新词都堆在第二天。只在首次学习时使用，不影响后续策略表。
int firstIntervalForDifficulty({
  required double difficulty,
  required int wordId,
  required ReviewGrade grade,
}) {
  if (grade == ReviewGrade.again || grade == ReviewGrade.hard) return 1;
  final parity = wordId.abs() % 2;
  if (difficulty <= 5) return 2 + parity; // 2 或 3 天
  if (difficulty <= 12) return 1 + parity; // 1 或 2 天
  return 1; // 13~18 难词仍然先 1 天
}
