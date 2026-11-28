class ReminderPreset {
  const ReminderPreset({
    required this.id,
    required this.name,
    this.minutesBefore,
    this.daysBefore = 1,
    this.hour = 19,
    this.minute = 0,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final int? minutesBefore;
  final int daysBefore;
  final int hour;
  final int minute;
  final bool isBuiltIn;

  bool get isMinuteOffset => minutesBefore != null;

  DateTime scheduledAt(DateTime eventAt) {
    final minutes = minutesBefore;
    if (minutes != null) {
      return eventAt.subtract(Duration(minutes: minutes));
    }
    return DateTime(eventAt.year, eventAt.month, eventAt.day)
        .subtract(Duration(days: daysBefore))
        .add(Duration(hours: hour, minutes: minute));
  }

  DateTime? scheduledAtForTemporaryTemplate(
    DateTime eventAt,
    DateTime now,
  ) {
    final scheduledAt = this.scheduledAt(eventAt);
    if (scheduledAt.isAfter(now) && scheduledAt.isBefore(eventAt)) {
      return scheduledAt;
    }

    if (id != 'evening' || isMinuteOffset || daysBefore != 1) return null;

    final fallback = eventAt.hour >= 17
        ? DateTime(eventAt.year, eventAt.month, eventAt.day, 6)
        : eventAt.subtract(const Duration(hours: 1));
    if (fallback.isAfter(now) && fallback.isBefore(eventAt)) return fallback;

    final oneHourBefore = eventAt.subtract(const Duration(hours: 1));
    return oneHourBefore.isAfter(now) && oneHourBefore.isBefore(eventAt)
        ? oneHourBefore
        : null;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'minutesBefore': minutesBefore,
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
        'isBuiltIn': isBuiltIn,
      };

  factory ReminderPreset.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid reminder preset');
    }
    final id = value['id'];
    final name = value['name'];
    final daysBefore = value['daysBefore'];
    final hour = value['hour'];
    final minute = value['minute'];
    final minutesBefore = value['minutesBefore'];
    if (id is! String ||
        name is! String ||
        (daysBefore != null && daysBefore is! int) ||
        (hour != null && hour is! int) ||
        (minute != null && minute is! int) ||
        (minutesBefore != null && minutesBefore is! int)) {
      throw const FormatException('Invalid reminder preset fields');
    }
    return ReminderPreset(
      id: id,
      name: name,
      minutesBefore: minutesBefore as int?,
      daysBefore: daysBefore as int? ?? 1,
      hour: hour as int? ?? 19,
      minute: minute as int? ?? 0,
      isBuiltIn: value['isBuiltIn'] == true,
    );
  }

  static const defaults = <ReminderPreset>[
    ReminderPreset(
      id: 'one_hour',
      name: 'មុន ១ ម៉ោង',
      minutesBefore: 60,
      isBuiltIn: true,
    ),
    ReminderPreset(
      id: 'evening',
      name: 'ប្រាប់ពីល្ងាច',
      daysBefore: 1,
      hour: 19,
      isBuiltIn: true,
    ),
    ReminderPreset(
      id: 'morning',
      name: 'ប្រាប់ពីព្រឹក',
      daysBefore: 0,
      hour: 6,
      isBuiltIn: true,
    ),
  ];
}
