// Dialog និង SnackBar ដែលប្រើរួមគ្នា
import 'package:flutter/material.dart';

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<String?> askText(BuildContext context, String title,
    {String hint = '', String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint)),
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
    String age = '',
    List<String> roleOptions = const [],
    bool isStaff = false,
    bool includeAgeAndPhone = true}) {
  final n = TextEditingController(text: name);
  String roleValue = role; // '' = មិនទាន់ជ្រើសរើស
  final p = TextEditingController(text: phone);
  final a = TextEditingController(text: age);
  return showDialog<Map<String, String>>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: n,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'ឈ្មោះ', border: OutlineInputBorder())),
          SizedBox(height: 12),
          if (isStaff) ...[
            StatefulBuilder(
              builder: (ctx, setSt) {
                // បញ្ចូលតម្លៃបច្ចុប្បន្នផង ដើម្បីកុំឱ្យតួនាទីចាស់ (ក្រៅបញ្ជី) បាត់
                final items = <String>{
                  ...roleOptions,
                  if (roleValue.isNotEmpty) roleValue
                }.toList();
                return DropdownButtonFormField<String>(
                  value: roleValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'តួនាទី', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: '',
                        child: Text('ជ្រើសរើសតួនាទី...',
                            style: TextStyle(color: Colors.grey))),
                    for (final x in items)
                      DropdownMenuItem(value: x, child: Text(x)),
                  ],
                  onChanged: (v) => setSt(() => roleValue = v ?? ''),
                );
              },
            ),
            const SizedBox(height: 12),
            if (includeAgeAndPhone) ...[
              TextField(
                  controller: a,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'វស្សា', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: p,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'លេខទូរស័ព្ទ', border: OutlineInputBorder())),
            ],
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('បោះបង់')),
        FilledButton(
          onPressed: () {
            if (n.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': n.text.trim(),
              'role': roleValue,
              'phone': p.text.trim(),
              'age': a.text.trim()
            });
          },
          child: const Text('រក្សាទុក'),
        ),
      ],
    ),
  );
}
