import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:task_assignment/core/input_styles.dart';

void main() {
  testWidgets('dropdown menu is centered and matches field width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: AppDropdownButtonFormField<int>(
                initialValue: 1,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('One')),
                  DropdownMenuItem(value: 2, child: Text('Two')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final fieldFinder = find.byType(InputDecorator).first;
    final fieldTopLeft = tester.getTopLeft(fieldFinder);
    final fieldSize = tester.getSize(fieldFinder);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    final popupFinder = find.byType(Material).last;
    final popupTopLeft = tester.getTopLeft(popupFinder);
    final popupSize = tester.getSize(popupFinder);
    expect(
      popupTopLeft.dx + popupSize.width / 2,
      closeTo(fieldTopLeft.dx + fieldSize.width / 2, 1),
    );
    expect(popupSize.width, closeTo(fieldSize.width, 0.1));

    final menuItemFinder = find.byType(DropdownMenuItem<int>).last;
    final menuRowFinder = find.descendant(
      of: menuItemFinder,
      matching: find.byType(Row),
    );
    expect(
      tester.getTopLeft(menuRowFinder).dx +
          tester.getSize(menuRowFinder).width / 2,
      closeTo(popupTopLeft.dx + popupSize.width / 2, 1),
    );
  });
}
