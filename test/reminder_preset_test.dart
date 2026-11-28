import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/models/reminder_preset.dart';

void main() {
  test('built-in presets resolve to their expected event-relative times', () {
    final eventAt = DateTime(2026, 12, 10, 8);

    expect(
      ReminderPreset.defaults[0].scheduledAt(eventAt),
      DateTime(2026, 12, 10, 7),
    );
    expect(
      ReminderPreset.defaults[1].scheduledAt(eventAt),
      DateTime(2026, 12, 9, 19),
    );
    expect(
      ReminderPreset.defaults[2].scheduledAt(eventAt),
      DateTime(2026, 12, 10, 6),
    );
  });

  test('temporary template falls back when the previous evening has passed',
      () {
    final preset = ReminderPreset.defaults[1];
    final morningEvent = DateTime(2026, 12, 10, 8);
    final eveningEvent = DateTime(2026, 12, 10, 19);
    final now = DateTime(2026, 12, 9, 20);

    expect(
      preset.scheduledAtForTemporaryTemplate(morningEvent, now),
      DateTime(2026, 12, 10, 7),
    );
    expect(
      preset.scheduledAtForTemporaryTemplate(eveningEvent, now),
      DateTime(2026, 12, 10, 6),
    );
  });

  test('temporary template never schedules a reminder after event time', () {
    final preset = ReminderPreset(
      id: 'custom',
      name: 'Custom',
      daysBefore: 0,
      hour: 21,
    );
    final eventAt = DateTime(2026, 12, 10, 20);

    expect(
      preset.scheduledAtForTemporaryTemplate(
        eventAt,
        DateTime(2026, 12, 10, 10),
      ),
      isNull,
    );
  });
}
