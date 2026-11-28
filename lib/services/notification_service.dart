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
import '../models/reminder_preset.dart';

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
  static const _reminderPresetsKey = 'reminderPresets';
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

  ReminderPreset? _findPreset(
    List<ReminderPreset> presets,
    String? id,
  ) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

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
    final payload = response.payload ?? '';
    final isTemplateReminder = payload.startsWith('template:');
    final recordId = int.tryParse(
      isTemplateReminder ? payload.substring('template:'.length) : payload,
    );
    Map<String, dynamic>? record;
    if (recordId != null) {
      final rows = await (await Db.instance).query(
        isTemplateReminder ? 'templates' : 'task_history',
        where: 'id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) record = rows.first;
    }

    final eventDate = DateTime.tryParse(
      (record?['task_date'] ?? '').toString(),
    );
    final startTime = (record?['start_time'] ?? '').toString().split(':');
    final startMinute = record?['start_min'];
    final timeText = isTemplateReminder
        ? startTime.length == 2 &&
                int.tryParse(startTime[0]) != null &&
                int.tryParse(startTime[1]) != null
            ? khTime(TimeOfDay(
                hour: int.parse(startTime[0]), minute: int.parse(startTime[1])))
            : null
        : startMinute is int
            ? khTime(
                TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60))
            : null;
    final place = (record?['place'] ?? '').toString().trim();
    final isEarlyReminder = response.id != null && response.id!.isEven;
    final details = <String>[
      if (eventDate != null) khDate(eventDate),
      if (timeText != null) timeText,
      if (place.isNotEmpty) place,
    ];
    final entry = <String, dynamic>{
      'id': (response.id ?? DateTime.now().microsecondsSinceEpoch).toString(),
      'title': record == null
          ? 'Notification'
          : isTemplateReminder
              ? 'រំលឹក! សូមចាត់ចែងព្រះស្ឃ: ${record['title']}'
              : '${isEarlyReminder ? 'ជិតដល់ម៉ោង' : 'ដល់ម៉ោង'}: ${record['title']}',
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

  Future<List<ReminderPreset>> loadReminderPresets() async {
    final stored = await _preferences.getStringList(_reminderPresetsKey);
    if (stored == null) return ReminderPreset.defaults;
    final presets = stored
        .map((item) => ReminderPreset.fromJson(jsonDecode(item)))
        .toList();
    return presets.isEmpty ? ReminderPreset.defaults : presets;
  }

  Future<void> saveReminderPresets(List<ReminderPreset> presets) async {
    final ids = presets.map((preset) => preset.id).toSet();
    if (ids.length != presets.length) {
      throw ArgumentError('Reminder preset ids must be unique');
    }
    if (!ReminderPreset.defaults
        .every((defaultPreset) => ids.contains(defaultPreset.id))) {
      throw ArgumentError('All built-in reminder presets must be retained');
    }
    await _preferences.setStringList(
      _reminderPresetsKey,
      presets.map((preset) => jsonEncode(preset.toJson())).toList(),
    );
    await rescheduleAll();
  }

  Future<void> deleteReminderPreset(String id) async {
    if (ReminderPreset.defaults.any((preset) => preset.id == id)) {
      throw ArgumentError('Built-in reminder presets cannot be deleted');
    }
    final database = await Db.instance;
    await database.transaction((transaction) async {
      await transaction.update(
        'templates',
        {'reminder_preset_id': 'evening'},
        where: 'reminder_preset_id = ? AND is_temporary = 1',
        whereArgs: [id],
      );
      await transaction.update(
        'templates',
        {'reminder_preset_id': null},
        where: 'reminder_preset_id = ? AND is_temporary = 0',
        whereArgs: [id],
      );
      await transaction.update(
        'task_history',
        {'reminder_preset_id': null},
        where: 'reminder_preset_id = ?',
        whereArgs: [id],
      );
    });
    final presets = await loadReminderPresets();
    await saveReminderPresets(
      presets.where((preset) => preset.id != id).toList(),
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
    final presets = await loadReminderPresets();
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

      final selectedPresetId = item['reminder_preset_id']?.toString();
      final selectedPreset = _findPreset(presets, selectedPresetId);
      final reminderAt = selectedPreset?.scheduledAt(eventAt) ??
          (settings.leadMinutes > 0
              ? eventAt.subtract(Duration(minutes: settings.leadMinutes))
              : null);
      if (reminderAt != null &&
          reminderAt.isAfter(now) &&
          reminderAt.isBefore(eventAt)) {
        await _scheduleNotification(
          notificationId: id * 2,
          scheduledAt: reminderAt,
          title: 'ជិតដល់ម៉ោង: ${_displayTitle(item)}',
          body: _reminderBody(
            item,
            eventAt,
            selectedPreset,
            selectedPreset == null ? settings.leadMinutes : null,
          ),
          payload: id.toString(),
          scheduleMode: scheduleMode,
        );
      }

      await _scheduleNotification(
        notificationId: id * 2 + 1,
        scheduledAt: eventAt,
        title: 'ដល់ម៉ោង: ${_displayTitle(item)}',
        body: _dueBody(item, eventAt),
        payload: id.toString(),
        scheduleMode: scheduleMode,
      );
    }

    final templates = await Db.all('templates');
    for (final item in templates) {
      final id = item['id'];
      final date = DateTime.tryParse((item['task_date'] ?? '').toString());
      final startTime = (item['start_time'] ?? '').toString();
      final startParts = startTime.split(':');
      if (item['is_temporary'] != 1 ||
          item['archived'] == 1 ||
          id is! int ||
          date == null ||
          startParts.length != 2) {
        continue;
      }
      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour >= 24 ||
          minute < 0 ||
          minute >= 60) {
        continue;
      }

      final eventAt = DateTime(date.year, date.month, date.day, hour, minute);
      final presetId = (item['reminder_preset_id'] ?? 'evening').toString();
      final preset = _findPreset(presets, presetId);
      if (preset == null) continue;
      final reminderAt = preset.scheduledAtForTemporaryTemplate(eventAt, now);
      if (reminderAt == null) continue;

      await _scheduleNotification(
        notificationId: 1000000000 + id,
        scheduledAt: reminderAt,
        title: 'រំលឹក! សូមចាត់ចែងព្រះស្ឃ: ${_displayTitle(item)}',
        body: _eventBody(item, eventAt),
        payload: 'template:$id',
        scheduleMode: scheduleMode,
      );
    }
  }

  String _displayTitle(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    return title.isEmpty ? 'កម្មវិធី' : title;
  }

  String _eventBody(Map<String, dynamic> item, DateTime eventAt) {
    final place = (item['place'] ?? '').toString().trim();
    final placeText = place.isEmpty ? '' : ' • ទីតាំង: $place';
    final time = khTime(TimeOfDay(hour: eventAt.hour, minute: eventAt.minute));
    return '${khDate(eventAt)} ម៉ោង $time$placeText';
  }

  String _dueBody(Map<String, dynamic> item, DateTime eventAt) {
    final place = (item['place'] ?? '').toString().trim();
    final placeText = place.isEmpty ? '' : ' • ទីតាំង: $place';
    final time = khTime(TimeOfDay(hour: eventAt.hour, minute: eventAt.minute));
    return 'ដល់ពេលចាប់ផ្ដើមហើយ ($time)$placeText';
  }

  String _reminderBody(
    Map<String, dynamic> item,
    DateTime eventAt,
    ReminderPreset? preset,
    int? leadMinutes,
  ) {
    final time = khTime(TimeOfDay(hour: eventAt.hour, minute: eventAt.minute));
    final place = (item['place'] ?? '').toString().trim();
    final placeText = place.isEmpty ? '' : ' • ទីតាំង: $place';
    final minutes = preset?.minutesBefore;
    if (minutes != null) {
      return 'នឹងចាប់ផ្ដើមនៅម៉ោង $time ក្នុង ${kh(minutes)} នាទីទៀត$placeText';
    }
    if (preset == null && leadMinutes != null) {
      return 'នឹងចាប់ផ្ដើមនៅម៉ោង $time ក្នុង ${kh(leadMinutes)} នាទីទៀត$placeText';
    }
    return 'សូមត្រៀមសម្រាប់ ${_eventBody(item, eventAt)}';
  }

  Future<void> _scheduleNotification({
    required int notificationId,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
    required AndroidScheduleMode scheduleMode,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'ការរំលឹកទៅបុណ្យ',
        channelDescription: 'ការរំលឹកមុនម៉ោង និងពេលដល់ម៉ោងទៅបុណ្យ',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
      payload: payload,
    );
    await _addPendingInboxEntry({
      'id': notificationId.toString(),
      'title': title,
      'body': body,
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
