import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/state/app_state.dart';

void main() {
  test('divider grows with template title length', () {
    final state = AppState();
    state.title = 'ក';
    final shortDivider = state.lengthOfTitle();

    state.title = 'សង្ឃទាន';
    final longDivider = state.lengthOfTitle();

    expect(longDivider.length, greaterThan(shortDivider.length));
  });

  test('short title does not produce a negative divider length', () {
    final state = AppState()..title = '';

    expect(state.lengthOfTitle(), ' ⋆⋅𖤓⋅⋆ ');
  });
}
