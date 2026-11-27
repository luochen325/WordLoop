import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_word_card.dart';
import '../models/graph_data.dart';
import '../models/word.dart';
import '../models/word_progress.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'scheduler.dart';
import 'tts_service.dart';

final appState = AppState();

class AppState extends ChangeNotifier {
  static const _kProgress = 'progress_v1';
  static const _kHistory = 'history_v1';
  static const _kServer = 'server_url';
  static const _kDailyNew = 'daily_new';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kTtsEnabled = 'tts_enabled';
  static const _kAutoImage = 'auto_image_on_study';
  static const _kStaggerFirst = 'stagger_first_interval';
  static const _kCustomWords = 'custom_words_v1';
  static const _kKnownWords = 'known_words_v1';
  static const _kAlgorithmVersion = 'algorithm_version';
  static const _algorithmVersion = 2;

  /// 新词学习时跳过的纯语法功能词：这些词很难用一张图表达，
  /// 仍然可以在词库里搜索和学习，只是不进入自动新词队列。
  static const Set<String> _functionWords = {
    'a', 'an', 'the', 'be', 'am', 'is', 'are', 'was', 'were', 'been', 'being',
    'do', 'does', 'did', 'done', 'have', 'has', 'had', 'having',
    'and', 'or', 'but', 'if', 'because', 'so', 'than', 'then',
    'that', 'this', 'these', 'those',
    'i', 'me', 'my', 'mine', 'you', 'your', 'yours',
    'he', 'him', 'his', 'she', 'her', 'hers', 'it', 'its',
    'we', 'us', 'our', 'ours', 'they', 'them', 'their', 'theirs',
    'in', 'on', 'at', 'to', 'of', 'for', 'with', 'by', 'from', 'about',
    'into', 'over', 'under', 'after', 'before', 'between', 'through',
    'during', 'without', 'within', 'up', 'down', 'out', 'off',
    'again', 'here', 'there', 'when', 'where', 'why', 'how',
    'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some',
    'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'too', 'very',
    'can', 'could', 'will', 'would', 'shall', 'should', 'may', 'might',
    'must', 'who', 'whom', 'whose', 'which', 'what', 'as', 'just', 'also',
    'one', 'two', 'first', 'second', 'next', 'last', 'many', 'much', 'every',
  };

  bool ready = false;
  bool hasLegacyProgress = false;
  List<Word> words = const [];
  final Map<int, Word> _wordIndex = {};
  final Map<int, Word> _customWords = {};
  int _nextCustomId = 100000;
  final Map<int, WordProgress> progress = {};
  final Set<int> _knownWords = {};
  List<ReviewLog> history = [];

  late MemoryScheduler scheduler;
  late ApiClient api;
  late SharedPreferences _prefs;

  final NotificationService notifications = NotificationService();
  final TtsService tts = TtsService();

  String serverUrl = ApiClient.defaultBaseUrl;
  int dailyNewGoal = 20;
  int reminderHour = 20;
  int reminderMinute = 0;
  bool reminderEnabled = true;
  bool ttsEnabled = true;
  bool autoImageOnStudy = true;
  bool staggerFirstInterval = true;

  final Map<int, AiWordCard> _cardCache = {};
  final Map<int, String> _imageCache = {};
  final Map<String, String> _textImageCache = {};
  final Map<String, GraphData> _graphCache = {};
  final Map<String, AiWordCard> _lookupCache = {};
  final Map<int, Future<AiWordCard>> _cardFutures = {};
  final Map<int, Future<String?>> _imageFutures = {};
  final Map<String, Future<String?>> _textImageFutures = {};

  DateTime get now => DateTime.now();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    final results = await Future.wait([
      rootBundle.loadString('assets/data/words.json'),
      rootBundle.loadString('assets/data/policy.json'),
    ]);

    final rawWords = jsonDecode(results[0]) as List;
    words = rawWords.map((item) => Word.fromJson(item as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    for (final word in words) {
      _wordIndex[word.id] = word;
    }

    final policy = PolicyTable.fromJson(jsonDecode(results[1]) as Map<String, dynamic>);
    scheduler = MemoryScheduler(policy);
    api = ApiClient(baseUrl: serverUrl);

    _loadCustomWords();
    _loadKnownWords();
    _loadProgress();
    _loadHistory();

    final version = _prefs.getInt(_kAlgorithmVersion) ?? 0;
    if (progress.isEmpty) {
      await _prefs.setInt(_kAlgorithmVersion, _algorithmVersion);
    } else {
      hasLegacyProgress = version != _algorithmVersion;
    }

    await notifications.init();
    await tts.init();

    ready = true;
    notifyListeners();
    _refreshReminder();
  }

  // ---------------- 设置 ----------------

  void _loadSettings() {
    serverUrl = _prefs.getString(_kServer) ?? ApiClient.defaultBaseUrl;
    dailyNewGoal = _prefs.getInt(_kDailyNew) ?? 20;
    reminderHour = _prefs.getInt(_kReminderHour) ?? 20;
    reminderMinute = _prefs.getInt(_kReminderMinute) ?? 0;
    reminderEnabled = _prefs.getBool(_kReminderEnabled) ?? true;
    ttsEnabled = _prefs.getBool(_kTtsEnabled) ?? true;
    autoImageOnStudy = _prefs.getBool(_kAutoImage) ?? true;
    staggerFirstInterval = _prefs.getBool(_kStaggerFirst) ?? true;
  }

  Future<void> setServerUrl(String value) async {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return;
    serverUrl = url;
    api.baseUrl = url;
    await _prefs.setString(_kServer, url);
    notifyListeners();
  }

  Future<void> setDailyNewGoal(int value) async {
    dailyNewGoal = value.clamp(5, 60);
    await _prefs.setInt(_kDailyNew, dailyNewGoal);
    notifyListeners();
  }

  Future<void> setReminder(int hour, int minute, bool enabled) async {
    reminderHour = hour;
    reminderMinute = minute;
    reminderEnabled = enabled;
    await _prefs.setInt(_kReminderHour, hour);
    await _prefs.setInt(_kReminderMinute, minute);
    await _prefs.setBool(_kReminderEnabled, enabled);
    await _refreshReminder();
    notifyListeners();
  }

  Future<void> setTtsEnabled(bool value) async {
    ttsEnabled = value;
    await _prefs.setBool(_kTtsEnabled, value);
    notifyListeners();
  }

  Future<void> setAutoImageOnStudy(bool value) async {
    autoImageOnStudy = value;
    await _prefs.setBool(_kAutoImage, value);
    notifyListeners();
  }

  Future<void> setStaggerFirstInterval(bool value) async {
    staggerFirstInterval = value;
    await _prefs.setBool(_kStaggerFirst, value);
    notifyListeners();
  }

  Future<Map<String, dynamic>> testConnection() => api.health();

  // ---------------- 词库与进度 ----------------

  Word? wordById(int id) => _wordIndex[id] ?? _customWords[id];

  /// 词库列表：自定义词排在前面，方便找到从知识网络加入的词
  List<Word> get allWords => [..._customWords.values, ...words];

  Word? wordByText(String text) {
    final lower = text.trim().toLowerCase();
    for (final word in words) {
      if (word.word.toLowerCase() == lower) return word;
    }
    for (final word in _customWords.values) {
      if (word.word.toLowerCase() == lower) return word;
    }
    return null;
  }

  List<Word> get dueWords {
    final entries = progress.values
        .where((item) => item.isDue(now) && !_knownWords.contains(item.wordId))
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return entries.map((item) => wordById(item.wordId)).whereType<Word>().toList();
  }

  int get dueCount => progress.values
      .where((item) => item.isDue(now) && !_knownWords.contains(item.wordId))
      .length;

  /// 用户手动标记为“已掌握”的单词
  bool isKnown(int wordId) => _knownWords.contains(wordId);

  int get knownCount => _knownWords.length;

  int get learnedCount => progress.length;

  int get learnedToday => progress.values
      .where((item) => _isSameDay(item.startedAt, now))
      .length;

  int get newRemaining {
    final remaining = dailyNewGoal - learnedToday;
    return remaining < 0 ? 0 : remaining;
  }

  List<Word> get newWords {
    final result = <Word>[];
    for (final word in words) {
      if (progress.containsKey(word.id) || _knownWords.contains(word.id)) {
        continue;
      }
      final lower = word.word.toLowerCase();
      if (lower.length < 3 || _functionWords.contains(lower)) continue;
      result.add(word);
      if (result.length >= newRemaining) break;
    }
    return result;
  }

  int get totalReviews => history.length;

  int get todayReviews =>
      history.where((item) => _isSameDay(item.at, now)).length;

  int get masteredCount =>
      _knownWords.length +
      progress.values.where((item) => item.h >= 30).length;

  double get averageRetention {
    if (progress.isEmpty) return 0;
    final total = progress.values
        .map((item) => item.recallProbability(now))
        .fold<double>(0, (sum, value) => sum + value);
    return total / progress.length;
  }

  double get recentAccuracy {
    if (history.isEmpty) return 0;
    final recent = history.length > 200
        ? history.sublist(history.length - 200)
        : history;
    final correct = recent.where((item) => item.recalled).length;
    return correct / recent.length;
  }

  int get streakDays {
    if (history.isEmpty) return 0;
    final dates = history
        .map((item) => DateTime(item.at.year, item.at.month, item.at.day))
        .toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<int> get reviewsLast7Days {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return history.where((item) => _isSameDay(item.at, day)).length;
    });
  }

  List<Word> get recentWords {
    final sorted = progress.values.toList()
      ..sort((a, b) => (b.lastReview ?? b.startedAt)
          .compareTo(a.lastReview ?? a.startedAt));
    return sorted
        .take(8)
        .map((item) => wordById(item.wordId))
        .whereType<Word>()
        .toList();
  }

  Map<String, int> get stabilityBuckets {
    final buckets = <String, int>{
      '0-1 天': 0,
      '1-7 天': 0,
      '7-30 天': 0,
      '30-180 天': 0,
      '180 天+': 0,
    };
    for (final item in progress.values) {
      if (item.h < 1) {
        buckets['0-1 天'] = buckets['0-1 天']! + 1;
      } else if (item.h < 7) {
        buckets['1-7 天'] = buckets['1-7 天']! + 1;
      } else if (item.h < 30) {
        buckets['7-30 天'] = buckets['7-30 天']! + 1;
      } else if (item.h < 180) {
        buckets['30-180 天'] = buckets['30-180 天']! + 1;
      } else {
        buckets['180 天+'] = buckets['180 天+']! + 1;
      }
    }
    return buckets;
  }

  // ---------------- 学习流程 ----------------

  Future<PlanResult> startWord(
    int wordId, {
    required ReviewGrade grade,
  }) async {
    final word = wordById(wordId);
    if (word == null) {
      throw StateError('word $wordId not found');
    }
    final nowTime = now;
    final base = scheduler.plan(
      h: word.h0,
      d: word.d0,
      daysSince: 0,
      grade: ReviewGrade.good,
    );

    double h;
    double d;
    int interval;
    switch (grade) {
      case ReviewGrade.again:
        h = word.h0 * 0.5;
        d = math.min(18.0, word.d0 + 2);
        interval = 1;
        break;
      case ReviewGrade.hard:
        h = word.h0 * 0.75;
        d = math.min(18.0, word.d0 + 2);
        interval = 1;
        break;
      case ReviewGrade.good:
        h = word.h0;
        d = word.d0;
        interval = base.intervalDays;
        break;
      case ReviewGrade.easy:
        h = word.h0 * 1.06;
        d = word.d0;
        interval = base.intervalDays;
        break;
    }

    if (staggerFirstInterval) {
      interval = firstIntervalForDifficulty(
        difficulty: word.d0,
        wordId: word.id,
        grade: grade,
      );
    }

    progress[wordId] = WordProgress(
      wordId: wordId,
      h: h,
      d: d,
      due: nowTime.add(Duration(days: interval)),
      startedAt: nowTime,
      lastReview: nowTime,
      lastInterval: interval.toDouble(),
      reps: grade.recalled ? 1 : 0,
      lapses: grade.recalled ? 0 : 1,
      totalReviews: 1,
    );

    _addLog(wordId, grade, 1.0, interval);
    await _saveProgress();
    await _saveHistory();
    await _refreshReminder();
    notifyListeners();

    return PlanResult(
      probability: 1,
      intervalDays: interval,
      nextH: h,
      nextD: d,
    );
  }

  Future<PlanResult> answer(int wordId, {required ReviewGrade grade}) async {
    final item = progress[wordId];
    if (item == null) {
      return startWord(wordId, grade: grade);
    }

    final nowTime = now;
    final last = item.lastReview ?? item.startedAt;
    final days = scheduler.daysBetween(last, nowTime);
    var plan = scheduler.plan(
      h: item.h,
      d: item.d,
      daysSince: days,
      grade: grade,
      lastInterval: item.lastInterval,
    );

    // 刚学完当天再次评分：沿用首轮间隔打散，
    // 避免“熟练”只安排 1 天、反而比“忘记”更早复习。
    if (staggerFirstInterval &&
        grade.recalled &&
        item.totalReviews <= 1 &&
        days < 0.5) {
      plan = PlanResult(
        probability: plan.probability,
        intervalDays: firstIntervalForDifficulty(
          difficulty: item.d,
          wordId: wordId,
          grade: grade,
        ),
        nextH: plan.nextH,
        nextD: plan.nextD,
      );
    }

    item.h = plan.nextH;
    item.d = plan.nextD;
    item.lastReview = nowTime;
    item.lastInterval = plan.intervalDays.toDouble();
    item.totalReviews += 1;
    if (grade.recalled) {
      item.reps += 1;
    } else {
      item.lapses += 1;
    }
    item.due = nowTime.add(Duration(days: plan.intervalDays));

    _addLog(wordId, grade, plan.probability, plan.intervalDays);
    await _saveProgress();
    await _saveHistory();
    await _refreshReminder();
    notifyListeners();
    return plan;
  }

  void _addLog(
    int wordId,
    ReviewGrade grade,
    double probability,
    int interval,
  ) {
    history.add(
      ReviewLog(
        wordId: wordId,
        at: now,
        recalled: grade.recalled,
        probability: probability,
        intervalDays: interval,
        grade: grade.value,
      ),
    );
    if (history.length > 3000) {
      history = history.sublist(history.length - 3000);
    }
  }

  // ---------------- AI 内容 ----------------

  AiWordCard? cachedCard(int wordId) => _cardCache[wordId];

  String? cachedImage(int wordId) => _imageCache[wordId];

  String? cachedImageForWord(Word word) => word.isCustom
      ? _textImageCache[word.word.trim().toLowerCase()]
      : _imageCache[word.id];

  Future<AiWordCard?> fetchCachedCard(int wordId) async {
    final cached = _cardCache[wordId];
    if (cached != null) return cached;
    final card = await api.fetchCard(wordId);
    if (card != null) {
      _cardCache[wordId] = card;
      notifyListeners();
    }
    return card;
  }

  Future<AiWordCard> generateCard(int wordId, {bool force = false}) async {
    final card = await api.generateCard(wordId, force: force);
    _cardCache[wordId] = card;
    notifyListeners();
    return card;
  }

  /// 确保单词卡存在：有缓存直接返回，没有就调用 AI 生成。
  /// 同一单词的并发请求会复用同一个 Future，避免重复扣费。
  Future<AiWordCard> ensureCard(int wordId, {bool force = false}) async {
    if (!force) {
      final cached = _cardCache[wordId];
      if (cached != null) return cached;
      final inFlight = _cardFutures[wordId];
      if (inFlight != null) return inFlight;
    }
    final future = generateCard(wordId, force: force);
    _cardFutures[wordId] = future;
    try {
      return await future;
    } finally {
      _cardFutures.remove(wordId);
    }
  }

  Future<String?> imageUrl(int wordId, {bool force = false}) async {
    if (!force) {
      final cached = _imageCache[wordId];
      if (cached != null) return cached;
    }
    final url = await api.generateImage(wordId, force: force);
    if (url != null) _imageCache[wordId] = url;
    return url;
  }

  /// 确保配图存在：有缓存直接返回，没有就调用 AI 生成；并发去重。
  Future<String?> ensureImage(int wordId, {bool force = false}) async {
    if (!force) {
      final cached = _imageCache[wordId];
      if (cached != null) return cached;
      final inFlight = _imageFutures[wordId];
      if (inFlight != null) return inFlight;
    }
    final future = imageUrl(wordId, force: force);
    _imageFutures[wordId] = future;
    try {
      return await future;
    } finally {
      _imageFutures.remove(wordId);
    }
  }

  /// 查询词库里没有的关联词（思维链节点），走 AI 详解。
  Future<AiWordCard> lookupWord(String word) async {
    final key = word.trim().toLowerCase();
    final cached = _lookupCache[key];
    if (cached != null) return cached;

    final ngslWord = wordByText(word);
    if (ngslWord != null) {
      final card = _cardCache[ngslWord.id];
      if (card != null) return card;
    }

    final card = await api.lookupWord(word);
    _lookupCache[key] = card;
    if (ngslWord != null) {
      _cardCache[ngslWord.id] = card;
    }
    notifyListeners();
    return card;
  }

  AiWordCard? cachedLookup(String word) =>
      _lookupCache[word.trim().toLowerCase()];

  /// 把知识网络/AI 查询里的非 NGSL 单词加入本地自定义词库。
  /// 之后它和普通单词一样拥有 Word 对象、可以评分并进入复习列表。
  Future<Word> addCustomWord(String text, {String definitionEn = ''}) async {
    final existing = wordByText(text);
    if (existing != null) return existing;

    final wordText = text.trim();
    final difficulty = _estimateDifficulty(wordText);
    final word = Word(
      id: _nextCustomId++,
      word: wordText,
      rank: -1,
      sfi: 0,
      freq: 0,
      definitionEn: definitionEn,
      h0: _startHalflifeFor(difficulty),
      d0: difficulty.toDouble(),
    );
    _customWords[word.id] = word;
    await _saveCustomWords();
    notifyListeners();
    return word;
  }

  int _estimateDifficulty(String text) {
    var difficulty = 9;
    if (text.contains(' ')) difficulty += 1;
    if (text.length >= 10) difficulty += 1;
    if (text.length <= 4) difficulty -= 1;
    return difficulty.clamp(1, 18).toInt();
  }

  double _startHalflifeFor(int difficulty) {
    final p = math.max(0.925 - 0.05 * difficulty, 0.025);
    return -1 / (math.log(p) / math.ln2);
  }

  /// 临时 Word，用于打开不在词库里的短语详情，不写入本地词库/复习列表。
  Word ephemeralWord(String text, {String definitionEn = ''}) {
    final wordText = text.trim();
    final difficulty = _estimateDifficulty(wordText);
    return Word(
      id: -DateTime.now().microsecondsSinceEpoch,
      word: wordText,
      rank: -1,
      sfi: 0,
      freq: 0,
      definitionEn: definitionEn,
      h0: _startHalflifeFor(difficulty),
      d0: difficulty.toDouble(),
    );
  }

  Future<AiWordCard?> fetchCachedCardForWord(Word word) async {
    if (word.isCustom) return cachedLookup(word.word);
    return fetchCachedCard(word.id);
  }

  Future<AiWordCard> ensureCardForWord(Word word) {
    if (word.isCustom) return lookupWord(word.word);
    return ensureCard(word.id);
  }

  Future<String?> ensureImageForWord(Word word, {bool force = false}) async {
    if (!word.isCustom) return ensureImage(word.id, force: force);

    final key = word.word.trim().toLowerCase();
    if (!force) {
      final cached = _textImageCache[key];
      if (cached != null) return cached;
      final inFlight = _textImageFutures[key];
      if (inFlight != null) return inFlight;
    }
    final future = api
        .generateImageByText(word.word, force: force)
        .then((url) {
          if (url != null) _textImageCache[key] = url;
          notifyListeners();
          return url;
        });
    _textImageFutures[key] = future;
    try {
      return await future;
    } finally {
      _textImageFutures.remove(key);
    }
  }

  Future<GraphData> loadGraph(String word, {bool force = false}) async {
    final key = word.toLowerCase();
    if (!force) {
      final cached = _graphCache[key];
      if (cached != null) return cached;
    }
    final data = await api.fetchGraph(word, force: force);
    _graphCache[key] = data;
    return data;
  }

  // ---------------- 演示工具 ----------------

  Future<void> makeAllDue() async {
    final nowTime = now;
    for (final item in progress.values) {
      item.due = nowTime;
    }
    await _saveProgress();
    await _refreshReminder();
    notifyListeners();
  }

  Future<void> resetProgress() async {
    progress.clear();
    history.clear();
    hasLegacyProgress = false;
    await _prefs.remove(_kProgress);
    await _prefs.remove(_kHistory);
    await _prefs.setInt(_kAlgorithmVersion, _algorithmVersion);
    await _refreshReminder();
    notifyListeners();
  }

  // ---------------- 发音 ----------------

  Future<void> speak(String text) async {
    if (!ttsEnabled) return;
    await tts.speak(text);
  }

  // ---------------- 持久化 ----------------

  void _loadCustomWords() {
    final raw = _prefs.getString(_kCustomWords);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List;
      for (final item in data) {
        final word = Word.fromJson(item as Map<String, dynamic>);
        _customWords[word.id] = word;
        if (word.id >= _nextCustomId) _nextCustomId = word.id + 1;
      }
    } catch (_) {
      _customWords.clear();
    }
  }

  Future<void> _saveCustomWords() async {
    await _prefs.setString(
      _kCustomWords,
      jsonEncode(_customWords.values.map((word) => word.toJson()).toList()),
    );
  }

  void _loadProgress() {
    final raw = _prefs.getString(_kProgress);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((key, value) {
        final item = WordProgress.fromJson(value as Map<String, dynamic>);
        progress[item.wordId] = item;
      });
    } catch (_) {
      progress.clear();
    }
  }

  void _loadHistory() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List;
      history = data
          .map((item) => ReviewLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      history = [];
    }
  }

  void _loadKnownWords() {
    final stored = _prefs.getStringList(_kKnownWords) ?? const [];
    _knownWords
      ..clear()
      ..addAll(stored.map(int.tryParse).whereType<int>());
  }

  Future<void> _saveKnownWords() async {
    await _prefs.setStringList(
      _kKnownWords,
      _knownWords.map((id) => id.toString()).toList(),
    );
  }

  /// 批量标记/取消“已掌握”。
  ///
  /// 标记为已掌握时会同时移除记忆进度，使其不再进入学习列表和复习列表。
  Future<void> setKnownBatch(
    Iterable<int> wordIds, {
    required bool known,
  }) async {
    var changed = false;
    for (final wordId in wordIds) {
      if (known) {
        if (_knownWords.add(wordId)) {
          progress.remove(wordId);
          changed = true;
        }
      } else if (_knownWords.remove(wordId)) {
        changed = true;
      }
    }
    if (!changed) return;
    await _saveKnownWords();
    await _saveProgress();
    await _refreshReminder();
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final data = progress.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    );
    await _prefs.setString(_kProgress, jsonEncode(data));
  }

  Future<void> _saveHistory() async {
    await _prefs.setString(
      _kHistory,
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _refreshReminder() async {
    final dueDates = progress.values
        .where((item) => !_knownWords.contains(item.wordId))
        .map((item) => item.due)
        .toList();
    await notifications.scheduleDueReminders(
      hour: reminderHour,
      minute: reminderMinute,
      dueDates: dueDates,
      enabled: reminderEnabled,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
