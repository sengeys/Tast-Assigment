import 'khmer_lunar_data.dart';

final DateTime _lunarBase = DateTime.utc(2019, 1, 1);

int? _lunarMonthPosition(DateTime date) {
  final dayNumber = DateTime.utc(date.year, date.month, date.day)
      .difference(_lunarBase)
      .inDays;
  if (dayNumber < kLunarMonthStarts.first ||
      dayNumber > kLunarMonthStarts.last + 29) {
    return null;
  }

  var low = 0;
  var high = kLunarMonthStarts.length - 1;
  while (low < high) {
    final middle = (low + high + 1) >> 1;
    if (kLunarMonthStarts[middle] <= dayNumber) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}

DateTime? _findLunarDay(
  int year, {
  required int monthIndex,
  required int day,
  required bool waning,
}) {
  for (var date = DateTime(year, 1, 1);
      date.year == year;
      date = date.add(const Duration(days: 1))) {
    final position = _lunarMonthPosition(date);
    if (position == null) continue;

    final lunarDayNumber = DateTime.utc(date.year, date.month, date.day)
            .difference(_lunarBase)
            .inDays -
        kLunarMonthStarts[position];
    if (lunarDayNumber < 0 || lunarDayNumber > 29) continue;
    final lunarDay =
        lunarDayNumber < 15 ? lunarDayNumber + 1 : lunarDayNumber - 14;
    if (kLunarMonthIndex[position] == monthIndex &&
        lunarDay == day &&
        (lunarDayNumber >= 15) == waning) {
      return date;
    }
  }
  return null;
}

DateTime? vassaStartDateForYear(int year) {
  final firstWaningDay = _findLunarDay(
    year,
    monthIndex: kLunarMonthNames.indexOf('ទុតិយាសាឍ'),
    day: 1,
    waning: true,
  );
  return firstWaningDay ??
      _findLunarDay(
        year,
        monthIndex: kLunarMonthNames.indexOf('អាសាឍ'),
        day: 1,
        waning: true,
      );
}

DateTime? vassaIncrementDateForYear(int year) => _findLunarDay(
      year,
      monthIndex: kLunarMonthNames.indexOf('អស្សុជ'),
      day: 1,
      waning: true,
    );

int? completedVassaCount({
  required Object? ordinationDate,
  required DateTime throughDate,
}) {
  final parsedDate = DateTime.tryParse((ordinationDate ?? '').toString());
  if (parsedDate == null) return null;

  final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  final throughOnly =
      DateTime(throughDate.year, throughDate.month, throughDate.day);
  final startDate = vassaStartDateForYear(dateOnly.year);
  late final int firstEligibleYear;
  // Before the lunar table, dates inside June-July cannot be classified safely.
  if (startDate != null) {
    firstEligibleYear =
        dateOnly.isAfter(startDate) ? dateOnly.year + 1 : dateOnly.year;
  } else if (dateOnly.year < kLunarFirstYear && dateOnly.month <= 5) {
    firstEligibleYear = dateOnly.year;
  } else if (dateOnly.year < kLunarFirstYear && dateOnly.month >= 8) {
    firstEligibleYear = dateOnly.year + 1;
  } else {
    return null;
  }

  var count = 0;
  for (var year = firstEligibleYear; year <= throughOnly.year; year++) {
    final incrementDate = vassaIncrementDateForYear(year);
    if (incrementDate == null) {
      if (year < kLunarFirstYear && year < throughOnly.year) {
        count++;
        continue;
      }
      return null;
    }
    if (!throughOnly.isBefore(incrementDate)) count++;
  }
  return count;
}

bool shouldIncrementVassa({
  required Object? status,
  required Object? ordinationDate,
  required DateTime vassaStartDate,
}) {
  if (isVassaExcludedStatus(status)) return false;

  final parsedDate = DateTime.tryParse((ordinationDate ?? '').toString());
  if (parsedDate == null) return true;
  final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  final startOnly =
      DateTime(vassaStartDate.year, vassaStartDate.month, vassaStartDate.day);
  return !dateOnly.isAfter(startOnly);
}

bool isVassaExcludedStatus(Object? status) {
  final normalizedStatus = (status ?? '').toString().trim();
  return normalizedStatus == 'លាចាកសិក្ខាបទ' ||
      normalizedStatus == 'បានចេញពីវត្តហើយ';
}
