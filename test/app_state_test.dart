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

  test('message marks direct invitations without showing role suffixes', () {
    final state = AppState()
      ..title = 'សង្ឃទាន'
      ..staff = [
        {'id': 1, 'name': 'នៅ យូឡុង', 'role': 'ចៅអធិការ'},
        {'id': 2, 'name': 'វឿន ចាន់ធឿន', 'role': 'វិន័យធរ'},
      ]
      ..selected.addAll([1, 2])
      ..directInvites.add(1);

    final message = state.buildMessage();

    expect(message, contains('១. គ្រូ. នៅ យូឡុង (ផ្ទាល់)'));
    expect(message, contains('២. គ្រូ. វឿន ចាន់ធឿន'));
    expect(message, isNot(contains('(ចៅអធិការ)')));
    expect(message, isNot(contains('(វិន័យធរ)')));
  });
}
