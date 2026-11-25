import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../core/khmer.dart';
import '../data/db.dart';

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.leadMinutes,
  });

  final bool enabled;
  final int leadMinutes;
}

class NotificationPermissionResult {
  const NotificationPermissionResult({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _enabledKey = 'taskNotificationsEnabled';
  static const _leadMinutesKey = 'taskNotificationLeadMinutes';
  static const _inboxKey = 'notificationInbox';
  static const _pendingInboxKey = 'pendingNotificationInbox';
  static const _leadMinuteOptions = {0, 5, 10, 15, 30, 60};

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final ValueNotifier<int> inboxCount = ValueNotifier<int>(0);
  bool _initialized = false;

  bool get _supportsScheduledNotifications =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize({void Function()? onNotificationTap}) async {
    if (_initialized) return;
    await reconcileDueNotifications();
    if (!_supportsScheduledNotifications) {
      _initialized = true;
      return;
    }

    timezone_data.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(timeZoneInfo.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleNotificationResponse(response, onNotificationTap));
      },
    );
    _initialized = true;
  }

  Future<List<Map<String, dynamic>>> loadInbox() async {
    final stored = await _preferences.getStringList(_inboxKey) ?? const [];
    return stored
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> clearInbox() async {
    await _preferences.setStringList(_inboxKey, const []);
    inboxCount.value = 0;
  }

  Future<void> markInboxEntryRead(String id) async {
    final inbox = await loadInbox();
    final index = inbox.indexWhere((entry) => entry['id']?.toString() == id);
    if (index == -1 || inbox[index]['isRead'] == true) return;
    inbox[index]['isRead'] = true;
    await _saveInbox(inbox);
  }

  Future<void> reconcileDueNotifications() async {
    final pending =
        await _preferences.getStringList(_pendingInboxKey) ?? const [];
    final future = <String>[];
    final inbox = await loadInbox();
    final knownIds = inbox.map((entry) => entry['id']?.toString()).toSet();
    final now = DateTime.now();
    var pendingChanged = false;
    var inboxChanged = false;

    for (final item in pending) {
      final notification = jsonDecode(item);
      if (notification is! Map<String, dynamic>) {
        pendingChanged = true;
        continue;
      }
      final scheduledAt =
          DateTime.tryParse((notification['scheduledAt'] ?? '').toString());
      if (scheduledAt == null) {
        pendingChanged = true;
        continue;
      }
      if (scheduledAt.isAfter(now)) {
        future.add(item);
        continue;
      }

      pendingChanged = true;
      final id = (notification['id'] ?? '').toString();
      if (id.isNotEmpty && knownIds.add(id)) {
        inbox.insert(0, {
          'id': id,
          'title': (notification['title'] ?? '').toString(),
          'body': (notification['body'] ?? '').toString(),
          'receivedAt': scheduledAt.toIso8601String(),
          'isRead': false,
        });
        inboxChanged = true;
      }
    }

    if (pendingChanged) {
      await _preferences.setStringList(_pendingInboxKey, future);
    }
    if (inbox.length > 100) {
      inbox.removeRange(100, inbox.length);
      inboxChanged = true;
    }
    if (inboxChanged) {
      await _saveInbox(inbox);
    } else {
      _updateInboxCount(inbox);
    }
  }

  Future<void> _saveInbox(List<Map<String, dynamic>> inbox) async {
    await _preferences.setStringList(
      _inboxKey,
      inbox.map(jsonEncode).toList(),
    );
    _updateInboxCount(inbox);
  }

  void _updateInboxCount(List<Map<String, dynamic>> inbox) {
    inboxCount.value = inbox.where((entry) => entry['isRead'] != true).length;
  }

  Future<void> _recordInboxEntry(Map<String, dynamic> entry) async {
    final inbox = await loadInbox();
    final id = entry['id']?.toString();
    if (!inbox.any((item) => item['id']?.toString() == id)) {
      inbox.insert(0, entry);
      if (inbox.length > 100) inbox.removeRange(100, inbox.length);
      await _saveInbox(inbox);
    } else {
      _updateInboxCount(inbox);
    }
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
    void Function()? onNotificationTap,
  ) async {
    final historyId = int.tryParse(response.payload ?? '');
    Map<String, dynamic>? historyItem;
    if (historyId != null) {
      final rows = await (await Db.instance).query(
        'task_history',
        where: 'id = ?',
        whereArgs: [historyId],
        limit: 1,
      );
      if (rows.isNotEmpty) historyItem = rows.first;
    }

    final eventDate = DateTime.tryParse(
      (historyItem?['task_date'] ?? '').toString(),
    );
    final startMinute = historyItem?['start_min'];
    final place = (historyItem?['place'] ?? '').toString().trim();
    final isEarlyReminder = response.id != null && response.id!.isEven;
    final details = <String>[
      if (eventDate != null) khDate(eventDate),
      if (startMinute is int)
        khTime(TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60)),
      if (place.isNotEmpty) place,
    ];
    final entry = <String, dynamic>{
      'id': (response.id ?? DateTime.now().microsecondsSinceEpoch).toString(),
      'title': historyItem == null
          ? 'Notification'
          : '${isEarlyReminder ? 'ជិតដល់ម៉ោង' : 'ដល់ម៉ោង'}: ${historyItem['title']}',
      'body': details.join(' • '),
      'receivedAt': DateTime.now().toIso8601String(),
      'isRead': false,
    };
    await _recordInboxEntry(entry);
    onNotificationTap?.call();
  }

  Future<ReminderSettings> loadSettings() async {
    final enabled = await _preferences.getBool(_enabledKey) ?? false;
    final savedLead = await _preferences.getInt(_leadMinutesKey) ?? 15;
    return ReminderSettings(
      enabled: enabled,
      leadMinutes: _leadMinuteOptions.contains(savedLead) ? savedLead : 15,
    );
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    await _preferences.setBool(_enabledKey, settings.enabled);
    await _preferences.setInt(_leadMinutesKey, settings.leadMinutes);
    await rescheduleAll();
  }

  Future<NotificationPermissionResult> requestPermissions() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) {
        return const NotificationPermissionResult(
          notificationsGranted: false,
          exactAlarmsGranted: false,
        );
      }

      final notificationsGranted =
          await android.requestNotificationsPermission() ?? true;
      if (!notificationsGranted) {
        return const NotificationPermissionResult(
          notificationsGranted: false,
          exactAlarmsGranted: false,
        );
      }

      var exactAlarmsGranted =
          await android.canScheduleExactNotifications() ?? true;
      if (!exactAlarmsGranted) {
        await android.requestExactAlarmsPermission();
        exactAlarmsGranted =
            await android.canScheduleExactNotifications() ?? false;
      }
      return NotificationPermissionResult(
        notificationsGranted: notificationsGranted,
        exactAlarmsGranted: exactAlarmsGranted,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return NotificationPermissionResult(
        notificationsGranted: granted,
        exactAlarmsGranted: true,
      );
    }

    return const NotificationPermissionResult(
      notificationsGranted: false,
      exactAlarmsGranted: false,
    );
  }

  Future<void> rescheduleAll() async {
    if (!_supportsScheduledNotifications) return;
    await initialize();
    await reconcileDueNotifications();
    await _plugin.cancelAllPendingNotifications();
    await _preferences.setStringList(_pendingInboxKey, const []);

    final settings = await loadSettings();
    if (!settings.enabled) return;

    var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canScheduleExact = await android?.canScheduleExactNotifications();
      if (canScheduleExact == false) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    final now = DateTime.now();
    final history = await Db.all('task_history');
    for (final item in history) {
      final date = DateTime.tryParse((item['task_date'] ?? '').toString());
      final startMin = item['start_min'];
      final id = item['id'];
      if (date == null ||
          startMin is! int ||
          startMin < 0 ||
          startMin >= 24 * 60 ||
          id is! int) {
        continue;
      }

      final eventAt = DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: startMin));
      if (!eventAt.isAfter(now)) continue;

      if (settings.leadMinutes > 0) {
        final reminderAt =
            eventAt.subtract(Duration(minutes: settings.leadMinutes));
        if (reminderAt.isAfter(now)) {
          await _schedule(
            historyId: id,
            isEarlyReminder: true,
            eventAt: eventAt,
            scheduledAt: reminderAt,
            leadMinutes: settings.leadMinutes,
            scheduleMode: scheduleMode,
            item: item,
          );
        }
      }

      await _schedule(
        historyId: id,
        isEarlyReminder: false,
        eventAt: eventAt,
        scheduledAt: eventAt,
        leadMinutes: settings.leadMinutes,
        scheduleMode: scheduleMode,
        item: item,
      );
    }
  }

  Future<void> _schedule({
    required int historyId,
    required bool isEarlyReminder,
    required DateTime eventAt,
    required DateTime scheduledAt,
    required int leadMinutes,
    required AndroidScheduleMode scheduleMode,
    required Map<String, dynamic> item,
  }) async {
    final title = (item['title'] ?? '').toString().trim();
    final displayTitle = title.isEmpty ? 'កម្មវិធី' : title;
    final place = (item['place'] ?? '').toString().trim();
    final placeText = place.isEmpty ? '' : ' • ទីតាំង: $place';
    final time = khTime(TimeOfDay(hour: eventAt.hour, minute: eventAt.minute));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'ការរំលឹកកម្មវិធី',
        channelDescription: 'ការរំលឹកមុនម៉ោង និងពេលដល់ម៉ោងកម្មវិធី',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final notificationId = historyId * 2 + (isEarlyReminder ? 0 : 1);
    final notificationTitle = isEarlyReminder
        ? 'ជិតដល់ម៉ោង: $displayTitle'
        : 'ដល់ម៉ោង: $displayTitle';
    final notificationBody = isEarlyReminder
        ? 'នឹងចាប់ផ្ដើមនៅម៉ោង $time ក្នុង ${kh(leadMinutes)} នាទីទៀត$placeText'
        : 'ដល់ពេលចាប់ផ្ដើមហើយ ($time)$placeText';
    await _plugin.zonedSchedule(
      id: notificationId,
      title: notificationTitle,
      body: notificationBody,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
      payload: historyId.toString(),
    );
    await _addPendingInboxEntry({
      'id': notificationId.toString(),
      'title': notificationTitle,
      'body': notificationBody,
      'scheduledAt': scheduledAt.toIso8601String(),
    });
  }

  Future<void> _addPendingInboxEntry(Map<String, dynamic> entry) async {
    final pending =
        await _preferences.getStringList(_pendingInboxKey) ?? const [];
    final entries = pending
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .where((item) => item['id']?.toString() != entry['id']?.toString())
        .toList()
      ..add(entry);
    await _preferences.setStringList(
      _pendingInboxKey,
      entries.map(jsonEncode).toList(),
    );
  }
}
