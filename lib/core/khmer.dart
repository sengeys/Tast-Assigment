// ជំនួយសម្រាប់លេខ កាលបរិច្ឆេទ និងម៉ោង ជាអក្សរខ្មែរ
import 'package:flutter/material.dart';

const _khDigits = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩'];
const _khWeekdays = ['ច័ន្ទ', 'អង្គារ', 'ពុធ', 'ព្រហស្បតិ៍', 'សុក្រ', 'សៅរ៍', 'អាទិត្យ'];

String kh(Object n) =>
    n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : _khDigits[i];
    }).join();

/// ឈ្មោះថ្ងៃក្នុងសប្តាហ៍ (ចន្ទ → អាទិត្យ)
String khWeekdayName(DateTime d) => _khWeekdays[d.weekday - 1];

String khDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '${_khWeekdays[d.weekday - 1]}, ${kh(dd)}/${kh(mm)}/${kh(d.year)}';
}

String khTime(TimeOfDay t) {
  final period = t.hour < 12 ? 'ព្រឹក' : (t.hour < 17 ? 'រសៀល' : 'ល្ងាច');
  var h = t.hour % 12;
  if (h == 0) h = 12;
  final hh = h.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${kh(hh)}:${kh(mm)} $period';
}

String fmtTime(TimeOfDay? t) =>
    t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseTime(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}
