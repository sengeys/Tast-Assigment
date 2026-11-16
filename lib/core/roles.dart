// លំដាប់តួនាទី និងការតម្រៀបបុគ្គលិក

/// លំដាប់តួនាទី (ទី១ → ទី៤)។ កែបន្ថែម/ប្តូរលំដាប់បាននៅទីនេះ។
/// តួនាទីដែលមិនមានក្នុងបញ្ជី នឹងនៅខាងក្រោមគេ តាមអក្ខរក្រម។
const roleOrder = ['អ្នកបើកបរ', 'កម្មករជីកដី', 'អ្នកកាន់បញ្ជី', 'សន្តិសុខ'];

int roleRank(Object? role) {
  final i = roleOrder.indexOf((role ?? '').toString().trim());
  return i == -1 ? roleOrder.length : i;
}

int compareStaff(Map<String, dynamic> a, Map<String, dynamic> b) {
  var c = roleRank(a['role']).compareTo(roleRank(b['role']));
  if (c != 0) return c;
  c = (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString());
  if (c != 0) return c;
  return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
}
