import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:task_assignment/widgets/dialogs.dart';

void main() {
  testWidgets('staff add dialog uses hidden default date and status',
      (tester) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    Map<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await recordDialog(
                  context,
                  'បន្ថែមព្រះសង្ឃថ្មី',
                  role: 'ភិក្ខុ',
                  ordinationDate: today,
                  status: 'នៅវត្ត',
                  roleOptions: const ['ភិក្ខុ'],
                  statusOptions: const ['នៅវត្ត', 'មិននៅវត្ត'],
                  isStaff: true,
                  showOrdinationDate: false,
                  showStatus: false,
                  includePhone: false,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final roleDropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(roleDropdown.borderRadius, BorderRadius.circular(10));
    expect(roleDropdown.elevation, 8);
    expect(find.text('ស្ថានភាព'), findsNothing);
    expect(find.text('ជ្រើសរើសថ្ងៃខែឆ្នាំបួស'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('ភិក្ខុ').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Test Monk');
    await tester.tap(find.text('រក្សាទុក'));
    await tester.pumpAndSettle();

    expect(result, {
      'name': 'Test Monk',
      'role': 'ភិក្ខុ',
      'phone': '',
      'ordination_date': today,
      'status': 'នៅវត្ត',
    });
  });
}
