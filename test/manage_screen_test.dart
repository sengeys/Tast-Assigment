import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:task_assignment/screens/manage_screen.dart';
import 'package:task_assignment/state/app_state.dart';

void main() {
  Future<void> pumpManageScreen(
    WidgetTester tester,
    AppState state,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: ManageCategoryScreen(category: ManageCategory.monks),
        ),
      ),
    );
  }

  AppState stateWithOneMonk() => AppState()
    ..staff = [
      {
        'id': 1,
        'name': 'Test Monk',
        'role': 'ភិក្ខុ',
        'age': 1,
        'phone': '',
        'status': 'នៅវត្ត',
      },
    ];

  testWidgets('tapping a name opens status-only editor', (tester) async {
    await pumpManageScreen(tester, stateWithOneMonk());

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('កែប្រែស្ថានភាព'), findsOneWidget);
    expect(find.text('លាចាកសិក្ខាបទ'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('long-press edit action opens the full record editor',
      (tester) async {
    await pumpManageScreen(tester, stateWithOneMonk());

    await tester.longPress(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('កែប្រែ'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('វស្សា'), findsNothing);
    expect(find.text('កែប្រែព្រះសង្ឃ'), findsOneWidget);
  });
}
