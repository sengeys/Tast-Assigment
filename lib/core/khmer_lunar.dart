// ប្រតិទិនចន្ទគតិខ្មែរ: បម្លែងថ្ងៃសុរិយគតិ (Gregorian) ទៅជា ថ្ងៃ កើត/រោច ខែ ឆ្នាំសត្វ ស័ក និង ព.ស.
// ប្រើតារាងក្នុង khmer_lunar_data.dart (ឆ្នាំ ២០២០ – ២១០០)។ ក្រៅចន្លោះនេះ ត្រឡប់ទៅទម្រង់ខ្លីវិញ។
import 'khmer.dart';
import 'khmer_lunar_data.dart';

class KhmerLunarDate {
  final int day; // ១ – ១៥
  final bool waning; // false = កើត, true = រោច
  final int monthIndex; // លេខក្នុង kLunarMonthNames
  final int beYear; // ព.ស.
  final int animalIndex; // លេខក្នុង kAnimalYearNames
  final int sakIndex; // លេខក្នុង kSakNames

  const KhmerLunarDate({
    required this.day,
    required this.waning,
    required this.monthIndex,
    required this.beYear,
    required this.animalIndex,
    required this.sakIndex,
  });

  String get moonPhaseName => waning ? 'រោច' : 'កើត';
}

final DateTime _lunarBase = DateTime.utc(2019, 1, 1);

/// ត្រឡប់ null បើថ្ងៃនោះនៅក្រៅចន្លោះទិន្នន័យ
KhmerLunarDate? khmerLunarOf(DateTime date) {
  final y = date.year;
  if (y < kLunarFirstYear || y > kLunarLastYear) return null;

  final day = DateTime.utc(y, date.month, date.day);
  final dn = day.difference(_lunarBase).inDays;

  // រកខែចន្ទគតិដែលចាប់ផ្តើមចុងក្រោយ មុន ឬស្មើថ្ងៃនេះ (Binary search)
  if (dn < kLunarMonthStarts[0]) return null;
  var lo = 0;
  var hi = kLunarMonthStarts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (kLunarMonthStarts[mid] <= dn) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final dayNum = dn - kLunarMonthStarts[lo]; // ០ – ២៩
  if (dayNum < 0 || dayNum > 29) return null;

  // ព.ស. ឆ្នាំសត្វ និងស័ក ប្តូរនៅថ្ងៃផ្សេងៗក្នុងឆ្នាំសុរិយគតិ
  final doy = day.difference(DateTime.utc(y, 1, 1)).inDays;
  final e = (y - kLunarFirstYear) * 3;
  final pisakha = kLunarYearEvents[e];
  final newYear = kLunarYearEvents[e + 1];
  final sakChange = kLunarYearEvents[e + 2];

  final be = doy >= pisakha ? y + 544 : y + 543;
  final animal = doy >= newYear ? (y + 548) % 12 : (y + 547) % 12;
  final jsYear = doy >= sakChange ? y - 638 : y - 639;

  return KhmerLunarDate(
    day: dayNum < 15 ? dayNum + 1 : dayNum - 14,
    waning: dayNum >= 15,
    monthIndex: kLunarMonthIndex[lo],
    beYear: be,
    animalIndex: animal,
    sakIndex: jsYear % 10,
  );
}

/// ឧ. ថ្ងៃអាទិត្យ ៧កើត ខែអស្សុជ ឆ្នាំមមី អដ្ឋស័ក ពុទ្ធសករាជ ២៥៧០
String khLunarLong(DateTime d) {
  final l = khmerLunarOf(d);
  if (l == null) return khDate(d);
  return kh('ថ្ងៃ${khWeekdayName(d)} ${l.day}${l.moonPhaseName} '
      'ខែ${kLunarMonthNames[l.monthIndex]} '
      'ឆ្នាំ${kAnimalYearNames[l.animalIndex]} ${kSakNames[l.sakIndex]} '
      'ពុទ្ធសករាជ ${l.beYear}');
}

/// ឧ. ថ្ងៃអាទិត្យ ៧កើត ខែអស្សុជ ឆ្នាំមមី អដ្ឋស័ក ពុទ្ធសករាជ ២៥៧០ ត្រូវនឹងថ្ងៃទី១៨ ខែតុលា ឆ្នាំ២០២៦
String khDateFull(DateTime d) {
  if (khmerLunarOf(d) == null) return khDate(d);
  return '${khLunarLong(d)} ត្រូវនឹងថ្ងៃទី${kh(d.day)} '
      'ខែ${kSolarMonthNames[d.month - 1]} ឆ្នាំ${kh(d.year)}';
}
