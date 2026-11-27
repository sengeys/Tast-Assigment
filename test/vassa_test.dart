import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/core/khmer_lunar.dart';
import 'package:task_assignment/core/khmer_lunar_data.dart';
import 'package:task_assignment/core/vassa.dart';

void main() {
  group('Vassa date lookup', () {
    test('uses second Asadha when available and otherwise regular Asadha', () {
      final asadha = kLunarMonthNames.indexOf('អាសាឍ');
      final secondAsadha = kLunarMonthNames.indexOf('ទុតិយាសាឍ');
      var foundSecondAsadhaYear = false;
      var foundRegularAsadhaYear = false;

      for (var year = kLunarFirstYear; year <= kLunarLastYear; year++) {
        final hasSecondAsadha = List.generate(
          DateTime(year + 1).difference(DateTime(year)).inDays,
          (day) => khmerLunarOf(DateTime(year, 1, 1 + day)),
        ).any((date) => date?.monthIndex == secondAsadha);
        final start = vassaStartDateForYear(year);
        expect(start, isNotNull);
        final lunar = khmerLunarOf(start!);
        expect(lunar?.day, 1);
        expect(lunar?.waning, isTrue);
        expect(lunar?.monthIndex, hasSecondAsadha ? secondAsadha : asadha);
        foundSecondAsadhaYear |= hasSecondAsadha;
        foundRegularAsadhaYear |= !hasSecondAsadha;
      }

      expect(foundSecondAsadhaYear, isTrue);
      expect(foundRegularAsadhaYear, isTrue);
    });

    test('increments on the first waning day of Asuja', () {
      final incrementDate = vassaIncrementDateForYear(2026);
      expect(incrementDate, isNotNull);
      final lunar = khmerLunarOf(incrementDate!);
      expect(lunar?.monthIndex, kLunarMonthNames.indexOf('អស្សុជ'));
      expect(lunar?.day, 1);
      expect(lunar?.waning, isTrue);
    });
  });

  group('Vassa eligibility', () {
    final startDate = DateTime(2026, 7, 1);

    test('counts people ordained by Vassa start', () {
      expect(
        shouldIncrementVassa(
          status: 'នៅវត្ត',
          ordinationDate: '2026-06-30',
          vassaStartDate: startDate,
        ),
        isTrue,
      );
      expect(
        shouldIncrementVassa(
          status: 'ទៅស្រុក',
          ordinationDate: '2026-07-01',
          vassaStartDate: startDate,
        ),
        isTrue,
      );
    });

    test(
        'does not count people ordained after Vassa starts or excluded statuses',
        () {
      for (final status in ['នៅវត្ត', 'មិននៅវត្ត', 'ទៅស្រុក']) {
        expect(
          shouldIncrementVassa(
            status: status,
            ordinationDate: '2026-07-02',
            vassaStartDate: startDate,
          ),
          isFalse,
        );
      }
      for (final status in ['លាចាកសិក្ខាបទ', 'បានចេញពីវត្តហើយ']) {
        expect(
          shouldIncrementVassa(
            status: status,
            ordinationDate: '2025-01-01',
            vassaStartDate: startDate,
          ),
          isFalse,
        );
      }
    });
  });

  test('recalculates completed Vassa count from the ordination date', () {
    final today = DateTime(2026, 11, 28);
    final startOf2019 = vassaStartDateForYear(2019);

    expect(startOf2019, isNotNull);
    expect(startOf2019!.isAfter(DateTime(2019, 5, 17)), isTrue);
    expect(
      completedVassaCount(
        ordinationDate: '2019-05-17',
        throughDate: today,
      ),
      8,
    );
    expect(
      completedVassaCount(
        ordinationDate: '2015-05-17',
        throughDate: today,
      ),
      12,
    );
  });

  test('ordination after the Vassa start skips that year', () {
    final startDate = vassaStartDateForYear(2025)!;

    expect(
      completedVassaCount(
        ordinationDate:
            startDate.add(const Duration(days: 1)).toIso8601String(),
        throughDate: DateTime(2026, 11, 28),
      ),
      1,
    );
  });
}
