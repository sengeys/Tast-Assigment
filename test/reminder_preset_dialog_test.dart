import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:task_assignment/models/reminder_preset.dart';
import 'package:task_assignment/widgets/reminder_preset_dialog.dart';

void main() {
  testWidgets('creates a named reminder preset before the event',
      (tester) async {
    ReminderPreset? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showReminderPresetEditor(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ពីរថ្ងៃមុន');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.tap(find.text('រក្សាទុក'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'ពីរថ្ងៃមុន');
    expect(result!.daysBefore, 2);
    expect(result!.hour, 19);
    expect(result!.minute, 0);
    expect(result!.minutesBefore, isNull);
  });
}
