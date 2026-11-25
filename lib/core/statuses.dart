const monkStatuses = <String>[
  'នៅវត្ត',
  'មិននៅវត្ត',
  'ទៅស្រុក',
  'លាចាកសិក្ខាបទ',
  'បានចេញពីវត្តហើយ',
];

const leaderStatuses = <String>[
  'អាចធ្វើបាន',
  'មិនអាចធ្វើបាន',
  'ឈប់ធ្វើអាចារ្យ',
  'ធ្វើអាចារ្យធម្មតា',
];

bool canAttendWithMonks(Object? status) =>
    (status ?? monkStatuses.first) == monkStatuses.first;

bool canAttendAsLeader(Object? status) {
  final value = (status ?? leaderStatuses.first).toString();
  return value == leaderStatuses.first || value == leaderStatuses.last;
}
