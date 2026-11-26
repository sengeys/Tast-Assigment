import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/core/roles.dart';

void main() {
  test('Bhikkhu role filter includes all monk positions', () {
    for (final role in [
      'ភិក្ខុ',
      'ចៅអធិការ',
      'វិន័យធរ',
      'គ្រូសូត្រស្ដាំ',
      'គ្រូសូត្រឆ្វេង',
      'លេខាធិការ',
      'ភត្តុទ្ទេសកៈ',
    ]) {
      expect(isBhikkhuRole(role), isTrue, reason: role);
    }

    expect(isBhikkhuRole('សាមណេរ'), isFalse);
  });

  test('selecting the bhikkhu role matches monk positions', () {
    for (final role in [
      'ភិក្ខុ',
      'ចៅអធិការ',
      'វិន័យធរ',
      'គ្រូសូត្រស្ដាំ',
      'គ្រូសូត្រឆ្វេង',
      'លេខាធិការ',
      'ភត្តុទ្ទេសកៈ',
    ]) {
      expect(matchesRoleFilter(role, 'ភិក្ខុ'), isTrue, reason: role);
    }

    expect(matchesRoleFilter('សាមណេរ', 'ភិក្ខុ'), isFalse);
    expect(matchesRoleFilter('សាមណេរ', 'សាមណេរ'), isTrue);
  });

  test('sangha group contains only the six named positions', () {
    for (final role in [
      'ចៅអធិការ',
      'វិន័យធរ',
      'គ្រូសូត្រស្ដាំ',
      'គ្រូសូត្រឆ្វេង',
      'លេខាធិការ',
      'ភត្តុទ្ទេសកៈ',
    ]) {
      expect(isSanghaRole(role), isTrue, reason: role);
    }

    expect(isSanghaRole('ភិក្ខុ'), isFalse);
  });

  test('vassa ordering groups monks before samaneras and disciples', () {
    final staff = [
      {'name': 'សាមណេរ', 'role': 'សាមណេរ', 'age': 50},
      {'name': 'ចៅអធិការ', 'role': 'ចៅអធិការ', 'age': 20},
      {'name': 'វិន័យធរ', 'role': 'វិន័យធរ', 'age': 30},
      {'name': 'កូនសិស្ស', 'role': 'កូនសិស្ស', 'age': 60},
      {'name': 'ភិក្ខុ', 'role': 'ភិក្ខុ', 'age': 10},
    ]..sort(compareStaffByVassa);

    expect(
      staff.map((person) => person['name']),
      ['វិន័យធរ', 'ចៅអធិការ', 'ភិក្ខុ', 'សាមណេរ', 'កូនសិស្ស'],
    );
  });
}
