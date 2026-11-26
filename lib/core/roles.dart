// លំដាប់តួនាទី និងការតម្រៀបបុគ្គលិក

/// លំដាប់តួនាទី (ទី១ → ទី៤)។ កែបន្ថែម/ប្តូរលំដាប់បាននៅទីនេះ។
/// តួនាទីដែលមិនមានក្នុងបញ្ជី នឹងនៅខាងក្រោមគេ តាមអក្ខរក្រម។
const roleOrder = [
  'ចៅអធិការ',
  'វិន័យធរ',
  'គ្រូសូត្រស្ដាំ',
  'គ្រូសូត្រឆ្វេង',
  'លេខាធិការ',
  'ភត្តុទ្ទេសកៈ',
  'ភិក្ខុ',
  'សាមណេរ',
  'កូនសិស្ស'
];

const _bhikkhuRoles = {
  'ភិក្ខុ',
  'ចៅអធិការ',
  'វិន័យធរ',
  'គ្រូសូត្រស្ដាំ',
  'គ្រូសូត្រឆ្វេង',
  'លេខាធិការ',
  'ភត្តុទ្ទេសកៈ',
};

const _sanghaRoles = {
  'ចៅអធិការ',
  'វិន័យធរ',
  'គ្រូសូត្រស្ដាំ',
  'គ្រូសូត្រឆ្វេង',
  'លេខាធិការ',
  'ភត្តុទ្ទេសកៈ',
};

bool isBhikkhuRole(Object? role) =>
    _bhikkhuRoles.contains((role ?? '').toString().trim());

bool isSanghaRole(Object? role) =>
    _sanghaRoles.contains((role ?? '').toString().trim());

bool matchesRoleFilter(Object? role, String? filter) {
  if (filter == null) return true;
  return filter == 'ភិក្ខុ'
      ? isBhikkhuRole(role)
      : (role ?? '').toString().trim() == filter;
}

int roleRank(Object? role) {
  final i = roleOrder.indexOf((role ?? '').toString().trim());
  return i == -1 ? roleOrder.length : i;
}

String formatStaffName(Map<String, dynamic> staff, {bool includeRole = true}) {
  final name = (staff['name'] ?? '').toString();
  final role = (staff['role'] ?? '').toString().trim();
  const prefixes = {
    'ភិក្ខុ': 'ភិ. ',
    'សាមណេរ': 'សា. ',
    'កូនសិស្ស': 'ក. ',
  };
  const suffixRoles = {
    'ចៅអធិការ',
    'វិន័យធរ',
    'គ្រូសូត្រស្ដាំ',
    'គ្រូសូត្រឆ្វេង',
    'លេខាធិការ',
    'ភត្តុទ្ទេសកៈ',
  };
  final prefix = prefixes[role] ?? (suffixRoles.contains(role) ? 'គ្រូ. ' : '');

  final suffix = includeRole && suffixRoles.contains(role) ? ' ($role)' : '';
  return '$prefix$name$suffix';
}

int compareStaff(Map<String, dynamic> a, Map<String, dynamic> b) {
  var c = roleRank(a['role']).compareTo(roleRank(b['role']));
  if (c != 0) return c;
  c = (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString());
  if (c != 0) return c;
  return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
}

int compareStaffByVassa(Map<String, dynamic> a, Map<String, dynamic> b) {
  int group(Object? role) {
    if (isBhikkhuRole(role)) return 0;
    return switch ((role ?? '').toString().trim()) {
      'សាមណេរ' => 1,
      'កូនសិស្ស' => 2,
      _ => 3,
    };
  }

  int vassa(Object? value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? -1;
  }

  var c = group(a['role']).compareTo(group(b['role']));
  if (c != 0) return c;
  c = vassa(b['age']).compareTo(vassa(a['age']));
  if (c != 0) return c;
  c = roleRank(a['role']).compareTo(roleRank(b['role']));
  if (c != 0) return c;
  return compareStaff(a, b);
}
