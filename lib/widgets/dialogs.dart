// Dialog និង SnackBar ដែលប្រើរួមគ្នា
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/input_styles.dart';
import '../core/khmer_lunar.dart';

String formatPhoneNumber(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final formatted = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) formatted.write('-');
    formatted.write(digits[i]);
  }
  return formatted.toString();
}

class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;

    final formatted = formatPhoneNumber(newValue.text);
    final selection = newValue.selection;
    if (!selection.isValid) {
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    int digitsBefore(int offset) {
      final safeOffset = offset < 0
          ? 0
          : (offset > newValue.text.length ? newValue.text.length : offset);
      return RegExp(r'[0-9]')
          .allMatches(newValue.text.substring(0, safeOffset))
          .length;
    }

    int offsetForDigitCount(int digitCount) {
      if (digitCount == 0) return 0;
      var digitsSeen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != '-') digitsSeen++;
        if (digitsSeen == digitCount) {
          final afterSeparator =
              i + 1 < formatted.length && formatted[i + 1] == '-';
          return i + 1 + (afterSeparator ? 1 : 0);
        }
      }
      return formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: offsetForDigitCount(digitsBefore(selection.baseOffset)),
        extentOffset: offsetForDigitCount(digitsBefore(selection.extentOffset)),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<String?> askText(BuildContext context, String title,
    {String hint = '', String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: AppInputFocusGlow(
        child: TextField(
          controller: c,
          autofocus: true,
          style: appInputTextStyle,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('បោះបង់')),
        FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('រក្សាទុក')),
      ],
    ),
  );
}

/// Dialog សម្រាប់បន្ថែម/កែ record (ឈ្មោះ + តួនាទី + លេខទូរស័ព្ទ បើជាបុគ្គលិក)
Future<Map<String, String>?> recordDialog(BuildContext context, String title,
    {String name = '',
    String role = '',
    String phone = '',
    String ordinationDate = '',
    String status = '',
    List<String> roleOptions = const [],
    List<String> statusOptions = const [],
    bool isStaff = false,
    bool requireOrdinationDate = false,
    bool showOrdinationDate = true,
    bool showStatus = true,
    bool includePhone = true}) {
  final n = TextEditingController(text: name);
  String roleValue = role; // '' = មិនទាន់ជ្រើសរើស
  String statusValue = statusOptions.contains(status)
      ? status
      : statusOptions.isEmpty
          ? ''
          : statusOptions.first;
  final p = TextEditingController(text: formatPhoneNumber(phone));
  DateTime? ordinationDateValue = DateTime.tryParse(ordinationDate);
  var ordinationDateError = false;
  return showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppInputFocusGlow(
              child: TextField(
                  controller: n,
                  autofocus: true,
                  style: appInputTextStyle,
                  decoration: const InputDecoration(
                      labelText: 'ឈ្មោះ', border: OutlineInputBorder())),
            ),
            const SizedBox(height: 12),
            if (isStaff) ...[
              if (showOrdinationDate) ...[
                AppInputFocusGlow(
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final firstDate = DateTime(1800);
                      final currentDate = ordinationDateValue ?? now;
                      final initialDate = currentDate.isAfter(now)
                          ? now
                          : currentDate.isBefore(firstDate)
                              ? firstDate
                              : currentDate;
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: initialDate,
                        firstDate: firstDate,
                        lastDate: now,
                      );
                      if (date != null) {
                        setDialogState(() {
                          ordinationDateValue =
                              DateTime(date.year, date.month, date.day);
                          ordinationDateError = false;
                        });
                      }
                    },
                    child: InputDecorator(
                      isEmpty: ordinationDateValue == null,
                      decoration: InputDecoration(
                        // labelText:
                        //     'ថ្ងៃខែឆ្នាំបួស${requireOrdinationDate ? ' *' : ''}',
                        border: const OutlineInputBorder(),
                        errorText: ordinationDateError
                            ? 'សូមជ្រើសរើសថ្ងៃខែឆ្នាំបួស'
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ordinationDateValue == null
                                  ? 'ជ្រើសរើសថ្ងៃខែឆ្នាំបួស'
                                  : khDateFull(ordinationDateValue!),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              StatefulBuilder(
                builder: (ctx, setSt) {
                  // បញ្ចូលតម្លៃបច្ចុប្បន្នផង ដើម្បីកុំឱ្យតួនាទីចាស់ (ក្រៅបញ្ជី) បាត់
                  final items = <String>{
                    ...roleOptions,
                    if (roleValue.isNotEmpty) roleValue
                  }.toList();
                  return AppInputFocusGlow(
                    child: DropdownButtonFormField<String>(
                      initialValue: roleValue,
                      isExpanded: true,
                      style: appInputTextStyle,
                      borderRadius: BorderRadius.circular(10),
                      decoration: const InputDecoration(
                        labelText: 'តួនាទី',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      selectedItemBuilder: (_) => [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ជ្រើសរើសតួនាទី...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        for (final x in items)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(x),
                          ),
                      ],
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Row(
                            children: [
                              Expanded(
                                child: const Text(
                                  'ជ្រើសរើសតួនាទី...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              if (roleValue.isEmpty)
                                Icon(
                                  Icons.check,
                                  color: Theme.of(ctx).colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                        for (final x in items)
                          DropdownMenuItem(
                            value: x,
                            child: Row(
                              children: [
                                Expanded(child: Text(x)),
                                if (roleValue == x)
                                  Icon(
                                    Icons.check,
                                    color: Theme.of(ctx).colorScheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setSt(() => roleValue = v ?? ''),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (includePhone)
                AppInputFocusGlow(
                  child: TextField(
                      controller: p,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [PhoneNumberInputFormatter()],
                      style: appInputTextStyle,
                      decoration: const InputDecoration(
                          labelText: 'លេខទូរស័ព្ទ',
                          border: OutlineInputBorder())),
                ),
            ],
            if (showStatus && statusOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppInputFocusGlow(
                child: DropdownButtonFormField<String>(
                  initialValue: statusValue,
                  isExpanded: true,
                  style: appInputTextStyle,
                  decoration: const InputDecoration(
                    labelText: 'ស្ថានភាព',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final option in statusOptions)
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: (value) => statusValue = value ?? statusValue,
                ),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('បោះបង់')),
          FilledButton(
            onPressed: () {
              if (n.text.trim().isEmpty) return;
              if (isStaff &&
                  requireOrdinationDate &&
                  ordinationDateValue == null) {
                setDialogState(() => ordinationDateError = true);
                return;
              }
              Navigator.pop(dialogContext, {
                'name': n.text.trim(),
                'role': roleValue,
                'phone': p.text.trim(),
                'ordination_date':
                    ordinationDateValue?.toIso8601String().split('T').first ??
                        '',
                'status': statusValue,
              });
            },
            child: const Text('រក្សាទុក'),
          ),
        ],
      ),
    ),
  );
}
