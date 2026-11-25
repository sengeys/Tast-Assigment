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

  test('message excludes monks and acharyas that are no longer eligible', () {
    final state = AppState()
      ..title = 'សង្ឃទាន'
      ..staff = [
        {'id': 1, 'name': 'ព្រះសង្ឃនៅវត្ត', 'status': 'នៅវត្ត'},
        {'id': 2, 'name': 'ព្រះសង្ឃទៅស្រុក', 'status': 'ទៅស្រុក'},
      ]
      ..leaders = [
        {'id': 1, 'name': 'អាចារ្យឈប់', 'status': 'ឈប់ធ្វើអាចារ្យ'},
      ]
      ..selected.addAll([1, 2])
      ..leaderId = 1;

    final message = state.buildMessage();

    expect(message, contains('១ អង្គ'));
    expect(message, contains('ព្រះសង្ឃនៅវត្ត'));
    expect(message, isNot(contains('ព្រះសង្ឃទៅស្រុក')));
    expect(message, isNot(contains('អាចារ្យឈប់')));
  });

  test('message lists selected preachers below assigned monks', () {
    final state = AppState()
      ..title = 'សង្ឃទាន'
      ..staff = [
        {
          'id': 1,
          'name': 'នៅ យូឡុង',
          'role': 'ចៅអធិការ',
          'status': 'នៅវត្ត',
        },
        {
          'id': 2,
          'name': 'វឿន ចាន់ធឿន',
          'role': 'វិន័យធរ',
          'status': 'នៅវត្ត',
        },
        {
          'id': 3,
          'name': 'ស៊ន សេងអ៊ី',
          'role': 'គ្រូសូត្រស្ដាំ',
          'status': 'នៅវត្ត',
        },
        {
          'id': 4,
          'name': 'ព្រះសង្ឃទៅស្រុក',
          'role': 'គ្រូសូត្រឆ្វេង',
          'status': 'ទៅស្រុក',
        },
      ]
      ..selected.add(1)
      ..preacherIds.addAll([2, 3, 4])
      ..preachDharma = true;

    final message = state.buildMessage();

    expect(message, contains('សង្ឃទាន ៣ អង្គ'));
    expect(
        message, contains('ទេសនាដោយ ៖ គ្រូ. វឿន ចាន់ធឿន និង គ្រូ. ស៊ន សេងអ៊ី'));
    expect(message, isNot(contains('ព្រះសង្ឃទៅស្រុក')));
  });

  test('message supports any number of preachers and selected service roles',
      () {
    final state = AppState()
      ..title = 'បុណ្យ'
      ..staff = [
        for (var id = 1; id <= 4; id++)
          {
            'id': id,
            'name': 'ព្រះសង្ឃ$id',
            'role': 'ចៅអធិការ',
            'status': 'នៅវត្ត',
          },
      ]
      ..preacherIds.addAll([1, 2, 3, 4])
      ..selected.addAll([1, 2, 3, 4])
      ..preceptGiverIds.addAll([3, 4])
      ..preachDharma = true
      ..preceptsType = 'និច្ចសីល និងឧបោសថសីល';

    final message = state.buildMessage();

    expect(message, contains('បុណ្យ ៤ អង្គ'));
    expect(
      message,
      contains(
        'សម្ដែងធម្មទេសនាដោយ ៖ គ្រូ. ព្រះសង្ឃ1 និង គ្រូ. ព្រះសង្ឃ2 និង '
        'គ្រូ. ព្រះសង្ឃ3 និង គ្រូ. ព្រះសង្ឃ4',
      ),
    );
    expect(
      message,
      contains(
        'ប្រទាននិច្ចសីល និងឧបោសថសីលដោយ ៖ '
        'គ្រូ. ព្រះសង្ឃ3 និង គ្រូ. ព្រះសង្ឃ4',
      ),
    );
    expect(message, contains('គ្រូ. ព្រះសង្ឃ4'));
  });

  test('message uses the correct label for each precepts choice', () {
    final cases = {
      'និច្ចសីល': 'ប្រទាននិច្ចសីលដោយ ៖',
      'ឧបោសថសីល': 'ប្រទានឧបោសថសីលដោយ ៖',
      'និច្ចសីល និងឧបោសថសីល': 'ប្រទាននិច្ចសីល និងឧបោសថសីលដោយ ៖',
    };

    for (final entry in cases.entries) {
      final state = AppState()
        ..staff = [
          {
            'id': 1,
            'name': 'នៅ យូឡុង',
            'role': 'ចៅអធិការ',
            'status': 'នៅវត្ត',
          },
        ]
        ..selected.add(1)
        ..preceptGiverIds.add(1)
        ..preceptsType = entry.key;

      expect(state.buildMessage(), contains(entry.value), reason: entry.key);
    }
  });

  test('precept givers are limited to assigned monks', () {
    final state = AppState()
      ..staff = [
        for (var id = 1; id <= 2; id++)
          {
            'id': id,
            'name': 'ព្រះសង្ឃ$id',
            'status': 'នៅវត្ត',
          },
      ]
      ..selected.add(1)
      ..preceptGiverIds.addAll([1, 2])
      ..preceptsType = 'និច្ចសីល';

    expect(state.selectedPreceptGivers.map((person) => person['id']), [1]);
  });
}
