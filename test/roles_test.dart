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
}
