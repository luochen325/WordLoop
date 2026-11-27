import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 待复习提醒使用的通知 id 区间（按天偏移，最多排 60 天）
  static const int _firstDueId = 2000;
  static const int _maxScheduleDays = 60;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      if (DateTime.now().timeZoneOffset.inMinutes == 480) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// 只在“当天确实有待复习单词”的日期安排提醒。
  ///
  /// [dueDates] 是所有单词的下次复习时间；会为未来 60 天里存在到期单词的
  /// 日期各安排一条一次性通知，取消掉旧的排期后再重新安排。
  Future<void> scheduleDueReminders({
    required int hour,
    required int minute,
    required List<DateTime> dueDates,
    required bool enabled,
  }) async {
    if (kIsWeb || !_ready) return;
    try {
      // 清掉旧版本的每日重复提醒，以及上一次排的所有待复习提醒
      await _plugin.cancel(id: 1001);
      for (var offset = 0; offset < _maxScheduleDays; offset++) {
        await _plugin.cancel(id: _firstDueId + offset);
      }
      if (!enabled || dueDates.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);
      final firstDay = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'review_reminder',
          '复习提醒',
          channelDescription: '当天有待复习单词时提醒你复习',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      for (var offset = 0; offset < _maxScheduleDays; offset++) {
        final when = firstDay.add(Duration(days: offset));
        if (!when.isAfter(now)) continue;
        final reminderLocal = when.toLocal();
        final hasDue = dueDates.any(
          (due) => !due.isAfter(reminderLocal),
        );
        if (!hasDue) continue;

        await _plugin.zonedSchedule(
          id: _firstDueId + offset,
          title: '该复习单词啦',
          body: '打开 WordLoop 看看今天有哪些单词该复习，花几分钟就能捡回来。',
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // 通知在部分设备/系统上不可用，不影响核心学习流程
    }
  }

  Future<void> showTest() async {
    if (kIsWeb || !_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'review_reminder',
        '复习提醒',
        channelDescription: '提醒你复习即将遗忘的单词',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: 1002,
      title: 'WordLoop 通知测试',
      body: '如果你看到这条消息，说明复习提醒已经正常工作。',
      notificationDetails: details,
    );
  }
}
