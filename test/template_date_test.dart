import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/state/app_state.dart';

void main() {
  test('starting from a template uses its saved date', () {
    final state = AppState();

    state.startFromTemplate({
      'title': 'សង្ឃទាន',
      'task_date': '2026-12-25',
      'is_temporary': 1,
      'reminder_preset_id': 'morning',
    });

    expect(state.date, DateTime(2026, 12, 25));
    expect(state.reminderPresetId, 'morning');
  });
}
