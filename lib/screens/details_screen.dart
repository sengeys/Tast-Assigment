// អេក្រង់ពេលវេលា ទីតាំង និងបញ្ជាក់
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/khmer_lunar.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import 'preview_screen.dart';

// ---------------- 3. Details form ----------------
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('ពេលវេលា និង ទីតាំង')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            initialValue: s.title,
            decoration: const InputDecoration(
                labelText: 'ឈ្មោះបុណ្យ',
                labelStyle: TextStyle(color: Colors.grey),
                // focusedBorder: OutlineInputBorder(
                //     borderSide: BorderSide(color: Colors.grey)),
                hintText: 'ឧ. សង្ឃទាន...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
            onChanged: (v) => s.title = v,
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4)),
            leading: const Icon(Icons.calendar_today),
            title: Text(khDateFull(s.date)),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: s.date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100));
              if (d != null) s.update(() => s.date = d);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _timeTile(context, 'ម៉ោងចាប់ផ្តើម', s.start,
                      (t) => s.update(() => s.start = t))),
              const SizedBox(width: 8),
              Expanded(
                  child: _timeTile(context, 'ម៉ោងបញ្ចប់', s.end,
                      (t) => s.update(() => s.end = t))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: s.leaders.any((l) => l['id'] == s.leaderId)
                      ? s.leaderId
                      : null,
                  hint: const Text('ជ្រើសរើសអាចារ្យ...'),
                  decoration: const InputDecoration(
                      labelText: 'អាចារ្យ', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('គ្មានអាចារ្យ',
                            style: TextStyle(color: Colors.grey))),
                    for (final x in s.leaders)
                      DropdownMenuItem<int?>(
                          value: x['id'] as int, child: Text(x['name'])),
                  ],
                  onChanged: (v) => s.update(() => s.leaderId = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final n = await askText(context, 'អាចារ្យថ្មី');
                  if (n == null || n.isEmpty) return;
                  final id = await Db.insert('leaders', {'name': n});
                  await s.load();
                  s.update(() => s.leaderId = id);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: s.places.any((x) => x['name'] == s.place)
                      ? s.place
                      : null,
                  hint: const Text('ជ្រើសរើសទីតាំង...'),
                  decoration: const InputDecoration(
                      labelText: 'ទីតាំង', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('គ្មានទីតាំង',
                            style: TextStyle(color: Colors.grey))),
                    for (final x in s.places)
                      DropdownMenuItem<String?>(
                          value: x['name'] as String, child: Text(x['name'])),
                  ],
                  onChanged: (v) => s.update(() => s.place = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final n = await askText(context, 'ទីតាំងថ្មី');
                  if (n == null || n.isEmpty) return;
                  await Db.insert('places', {'name': n});
                  await s.load();
                  s.update(() => s.place = n);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: s.note,
            minLines: 2,
            maxLines: null,
            decoration: const InputDecoration(
                labelText: 'បញ្ជាក់ (មិនចាំបាច់)',
                labelStyle: TextStyle(color: Colors.grey),

                // focusedBorder: OutlineInputBorder(
                //     borderSide: BorderSide(color: Colors.grey)),
                hintText: 'ឧ. យកបាត្រ និង ស្រាក់...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
            onChanged: (v) => s.note = v,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('រក្សាទុកជាគំរូ'),
            onPressed: () async {
              final name =
                  await askText(context, 'ឈ្មោះគំរូ', initial: s.title);
              if (name == null || name.isEmpty) return;
              await s.saveAsTemplate(name);
              if (context.mounted)
                showSnack(context, 'បានរក្សាទុកជាគំរូរួចរាល់ ✔');
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.preview),
            label: const Text('មើលសារ'),
            onPressed: () => _goPreview(context, s),
          ),
        ],
      ),
    );
  }

  Future<void> _goPreview(BuildContext context, AppState s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (s.start == null || s.end == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('សូមកំណត់ម៉ោងចាប់ផ្តើម និងម៉ោងបញ្ចប់')));
      return;
    }
    if (s.end!.hour * 60 + s.end!.minute <=
        s.start!.hour * 60 + s.start!.minute) {
      messenger.showSnackBar(
          const SnackBar(content: Text('ម៉ោងបញ្ចប់ត្រូវនៅក្រោយម៉ោងចាប់ផ្តើម')));
      return;
    }
    final conflicts = await s.findConflicts();
    if (!context.mounted) return;
    if (conflicts.isNotEmpty) {
      String range(Map<String, dynamic> c) {
        final a = c['start_min'] as int, b = c['end_min'] as int;
        return '${khTime(TimeOfDay(hour: a ~/ 60, minute: a % 60))} - '
            '${khTime(TimeOfDay(hour: b ~/ 60, minute: b % 60))}';
      }

      final goBack = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.warning_amber, color: Colors.orange),
          title: const Text('ព្រះសង្ឃជាន់ពេលគ្នា'),
          content: SingleChildScrollView(
            child: Text([
              'ព្រះសង្ឃខាងក្រោមមានបុណ្យផ្សេងនៅថ្ងៃនេះរួចហើយ៖',
              '',
              for (final c in conflicts)
                '• ${c['staff_name']} — ${c['title']} (${range(c)})',
            ].join('\n')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('កែម៉ោង')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ជ្រើសព្រះសង្ឃថ្មី')),
          ],
        ),
      );
      if (goBack == true && context.mounted) Navigator.pop(context);
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PreviewScreen()));
  }

  Widget _timeTile(BuildContext context, String label, TimeOfDay? t,
      ValueChanged<TimeOfDay> onPick) {
    return ListTile(
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(4)),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(t == null ? '—' : khTime(t),
          style: const TextStyle(fontSize: 15)),
      onTap: () async {
        final r = await showTimePicker(
            context: context,
            initialTime: t ?? const TimeOfDay(hour: 7, minute: 0));
        if (r != null) onPick(r);
      },
    );
  }
}
