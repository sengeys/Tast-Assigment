import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/core/statuses.dart';

void main() {
  test('only monks staying at the monastery can attend', () {
    expect(canAttendWithMonks('នៅវត្ត'), isTrue);
    for (final status in monkStatuses.skip(1)) {
      expect(canAttendWithMonks(status), isFalse, reason: status);
    }
  });

  test('only eligible acharya statuses allow event assignment', () {
    expect(canAttendAsLeader('អាចធ្វើបាន'), isTrue);
    expect(canAttendAsLeader('ធ្វើអាចារ្យធម្មតា'), isTrue);
    expect(canAttendAsLeader('មិនអាចធ្វើបាន'), isFalse);
    expect(canAttendAsLeader('ឈប់ធ្វើអាចារ្យ'), isFalse);
  });

  test('missing statuses retain eligibility for legacy data', () {
    expect(canAttendWithMonks(null), isTrue);
    expect(canAttendAsLeader(null), isTrue);
  });
}
