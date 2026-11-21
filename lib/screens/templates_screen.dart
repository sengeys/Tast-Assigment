// អេក្រង់គំរូការងារ និងអេក្រង់បង្កើត/កែគំរូ
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/roles.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import 'staff_select_screen.dart';

// ---------------- 1. Templates (គំរូការងារ) ----------------
List<String> roleOptionsOf(AppState s) =>
    [...roleOrder, ...s.roles.where((x) => !roleOrder.contains(x))];

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    String leaderOf(Object? id) {
      for (final l in s.leaders) {
        if (l['id'] == id) return l['name'] as String;
      }
      return '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('គំរូព្រះសង្ឃទៅបុណ្យ')),
      body: s.templates.isEmpty
          ? const Center(child: Text('មិនទាន់មានគំរូ ចុច + ដើម្បីបន្ថែម'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final t in s.templates)
                  ListTile(
                    leading: const Icon(Icons.assignment),
                    title: Text(t['title']),
                    isThreeLine: true,
                    subtitle: Text([
                      [
                        if ((t['role'] ?? '').toString().isNotEmpty)
                          '${t['role']}',
                        if ((t['start_time'] ?? '').toString().isNotEmpty)
                          'ម៉ោង ${t['start_time']}'
                              '${(t['end_time'] ?? '').toString().isNotEmpty ? ' - ${t['end_time']}' : ''}',
                      ].join(' • '),
                      [
                        if (leaderOf(t['leader_id']).isNotEmpty)
                          'អាចារ្យ: ${leaderOf(t['leader_id'])}',
                        if ((t['place'] ?? '').toString().isNotEmpty)
                          'ទីតាំង: ${t['place']}',
                      ].join(' • '),
                      if ((t['note'] ?? '').toString().isNotEmpty)
                        'បញ្ជាក់: ${t['note']}',
                    ].where((e) => e.isNotEmpty).join('\n')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'កែគំរូ',
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      TemplateEditScreen(template: t))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'លុបគំរូ',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('លុបគំរូ "${t['title']}" ?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('បោះបង់')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('លុប')),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            await Db.delete('templates', t['id']);
                            s.load();
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      s.startFromTemplate(t);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StaffSelectScreen()));
                    },
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('គំរូថ្មី'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TemplateEditScreen())),
      ),
    );
  }
}

// ---------------- Template edit / create ----------------
class TemplateEditScreen extends StatefulWidget {
  final Map<String, dynamic>? template;
  const TemplateEditScreen({super.key, this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late final TextEditingController title;
  late final TextEditingController note;
  String role = '';
  TimeOfDay? start, end;
  int? leaderId;
  String? place;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    title = TextEditingController(text: (t?['title'] ?? '').toString());
    note = TextEditingController(text: (t?['note'] ?? '').toString());
    role = (t?['role'] ?? '').toString();
    start = parseTime(t?['start_time']);
    end = parseTime(t?['end_time']);
    leaderId = t?['leader_id'] as int?;
    final pl = (t?['place'] ?? '').toString();
    place = pl.isEmpty ? null : pl;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = title.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'សូមបញ្ចូលឈ្មោះគំរូ');
      return;
    }
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final v = <String, Object?>{
      'title': name,
      'role': role,
      'start_time': fmtTime(start),
      'end_time': fmtTime(end),
      'leader_id': leaderId,
      'place': place ?? '',
      'note': note.text.trim(),
    };
    if (widget.template == null) {
      await Db.insert('templates', v);
    } else {
      await Db.update('templates', widget.template!['id'] as int, v);
    }
    await state.load();
    nav.pop();
  }

  Widget _timeTile(
      String label, TimeOfDay? t, ValueChanged<TimeOfDay?> onPick) {
    return ListTile(
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(4)),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(t == null ? '—' : khTime(t),
          style: const TextStyle(fontSize: 15)),
      trailing: t == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onPick(null)),
      onTap: () async {
        final r = await showTimePicker(
            context: context,
            initialTime: t ?? const TimeOfDay(hour: 7, minute: 0));
        if (r != null) onPick(r);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final options =
        <String>{...roleOptionsOf(s), if (role.isNotEmpty) role}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'គំរូថ្មី' : 'កែគំរូ'),
        actions: [
          IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'រក្សាទុក',
              onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(
                labelText: 'ឈ្មោះបុណ្យ',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'ឧ. សង្ឃទាន...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: role.isEmpty ? null : role,
            isExpanded: true,
            hint: const Text('ជ្រើសរើសតួនាទី...'),
            decoration: const InputDecoration(
                labelText: 'តួនាទី (សម្រាប់ Filter ព្រះសង្ឃ)',
                labelStyle: TextStyle(color: Colors.grey),
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('គ្មានតួនាទី',
                      style: TextStyle(color: Colors.grey))),
              for (final x in options)
                DropdownMenuItem<String?>(value: x, child: Text(x)),
            ],
            onChanged: (v) => setState(() => role = v ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _timeTile('ម៉ោងចាប់ផ្តើម', start,
                      (t) => setState(() => start = t))),
              const SizedBox(width: 8),
              Expanded(
                  child: _timeTile(
                      'ម៉ោងបញ្ចប់', end, (t) => setState(() => end = t))),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue:
                s.leaders.any((l) => l['id'] == leaderId) ? leaderId : null,
            hint: const Text('ជ្រើសរើសអាចារ្យ...'),
            decoration: const InputDecoration(
                labelText: 'អាចារ្យ', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('គ្មានអាចារ្យ',
                      style: TextStyle(color: Colors.grey))),
              for (final l in s.leaders)
                DropdownMenuItem<int?>(
                    value: l['id'] as int, child: Text(l['name'])),
            ],
            onChanged: (v) => setState(() => leaderId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue:
                s.places.any((x) => x['name'] == place) ? place : null,
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
            onChanged: (v) => setState(() => place = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: null,
            decoration: const InputDecoration(
                labelText: 'បញ្ជាក់ (មិនចាំបាច់)',
                hintText: 'ឧ. យកបាត្រ និង ស្រាក់...',
                labelStyle: TextStyle(color: Colors.grey),
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('រក្សាទុកគំរូ'),
              onPressed: _save),
        ],
      ),
    );
  }
}
