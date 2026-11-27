import 'dart:math' as math;

class WordProgress {
  WordProgress({
    required this.wordId,
    required this.h,
    required this.d,
    required this.due,
    required this.startedAt,
    this.lastReview,
    this.lastInterval = 1,
    this.reps = 0,
    this.lapses = 0,
    this.totalReviews = 0,
  });

  final int wordId;
  double h;
  double d;
  DateTime due;
  final DateTime startedAt;
  DateTime? lastReview;
  double lastInterval;
  int reps;
  int lapses;
  int totalReviews;

  bool isDue(DateTime now) => !due.isAfter(now);

  /// 掌握度标签（由记忆稳定性推导）
  String get masteryLabel {
    if (h < 1) return '初识';
    if (h < 7) return '熟悉中';
    if (h < 30) return '较熟';
    if (h < 180) return '掌握';
    return '长期记忆';
  }

  int get masteryLevel {
    if (h < 1) return 0;
    if (h < 7) return 1;
    if (h < 30) return 2;
    if (h < 180) return 3;
    return 4;
  }

  /// 当前时刻的回忆概率 R = 2^(-t/h)
  double recallProbability(DateTime now) {
    final days = math.max(
      0.0,
      now.difference(lastReview ?? startedAt).inMinutes / (60 * 24),
    );
    return math.pow(2, -days / h).toDouble();
  }

  int get daysUntilDue {
    final diff = due.difference(DateTime.now()).inHours;
    return math.max(1, (diff / 24).ceil());
  }

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'h': h,
        'd': d,
        'due': due.toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'lastReview': lastReview?.toIso8601String(),
        'lastInterval': lastInterval,
        'reps': reps,
        'lapses': lapses,
        'totalReviews': totalReviews,
      };

  factory WordProgress.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['startedAt'] as String);
    return WordProgress(
      wordId: (json['wordId'] as num).toInt(),
      h: (json['h'] as num).toDouble(),
      d: (json['d'] as num).toDouble(),
      due: DateTime.parse(json['due'] as String),
      startedAt: startedAt,
      lastReview: json['lastReview'] == null
          ? null
          : DateTime.parse(json['lastReview'] as String),
      lastInterval: (json['lastInterval'] as num?)?.toDouble() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReviewLog {
  ReviewLog({
    required this.wordId,
    required this.at,
    required this.recalled,
    required this.probability,
    required this.intervalDays,
    this.grade = 3,
  });

  final int wordId;
  final DateTime at;
  final bool recalled;
  final double probability;
  final int intervalDays;

  /// 1=忘记 2=模糊 3=想起 4=熟练
  final int grade;

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'at': at.toIso8601String(),
        'recalled': recalled,
        'probability': probability,
        'intervalDays': intervalDays,
        'grade': grade,
      };

  factory ReviewLog.fromJson(Map<String, dynamic> json) {
    final recalled = (json['recalled'] as bool?) ?? true;
    return ReviewLog(
      wordId: (json['wordId'] as num).toInt(),
      at: DateTime.parse(json['at'] as String),
      recalled: recalled,
      probability: (json['probability'] as num).toDouble(),
      intervalDays: (json['intervalDays'] as num).toInt(),
      grade: (json['grade'] as num?)?.toInt() ?? (recalled ? 3 : 1),
    );
  }
}
