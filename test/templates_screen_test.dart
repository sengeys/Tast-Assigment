import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:task_assignment/screens/templates_screen.dart';
import 'package:task_assignment/state/app_state.dart';

void main() {
  testWidgets('lists newest templates first by creation id', (tester) async {
    final state = AppState()
      ..templates = [
        {
          'id': 2,
          'title': 'Older template',
          'is_temporary': 1,
          'archived': 0,
        },
        {
          'id': 9,
          'title': 'Newer template',
          'is_temporary': 1,
          'archived': 0,
        },
      ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TemplatesScreen()),
      ),
    );

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).textSpan!.toPlainText())
        .map((title) => title.split(' • ').first)
        .toList();

    expect(titles, ['Newer template', 'Older template']);
  });
}
