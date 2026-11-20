import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_assignment/widgets/dialogs.dart';

void main() {
  test('formats phone numbers into 3-3-remaining groups', () {
    expect(formatPhoneNumber('0878747977'), '087-874-7977');
    expect(formatPhoneNumber('087-874-7977'), '087-874-7977');
  });

  test('formats typed digits and keeps the cursor after the inserted dash', () {
    const formatter = PhoneNumberInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
          text: '087', selection: TextSelection.collapsed(offset: 3)),
      const TextEditingValue(
          text: '0874', selection: TextSelection.collapsed(offset: 4)),
    );

    expect(result.text, '087-4');
    expect(result.selection.baseOffset, 5);
  });
}
