// អេក្រង់ព័ត៌មានលម្អិតនៃប្រវត្តិការចាត់តាំង
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../state/app_state.dart';
import 'history_actions.dart';

// ---------------- History detail ----------------
class HistoryDetailScreen extends StatelessWidget {
  final int id;
  const HistoryDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final matches = s.history.where((x) => x['id'] == id);
    if (matches.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('ព័ត៌មានលម្អិត')),
          body: const Center(child: Text('ការចាត់ទៅបុណ្យនេះត្រូវបានលុបហើយ')));
    }
    final h = matches.first;
    final ended = historyEnded(h);
    final names =
        (h['staff_names'] ?? '').toString().split(', ').where((e) => e.isNotEmpty).toList();
    final time = historyTimeText(h);

    Widget row(IconData icon, String label, String value) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 16)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('${h['title']}'),
        actions: [
          // ក្នុងអេក្រង់លម្អិតនេះ កែ/លុប បានជានិច្ច (ទោះផុតម៉ោងហើយក៏ដោយ)
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'កែប្រែ',
              onPressed: () => editHistory(context, s, h)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'លុប',
            onPressed: () async {
              final ok = await deleteHistoryConfirm(context, s, h);
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (ended)
            Container(
              color: Colors.redAccent.shade100,
              padding: const EdgeInsets.all(12),
              child: const Text('ព្រះសង្ឃដែលបានទៅបុណ្យនេះផុតម៉ោងហើយ — កែ ឬលុបបានតែនៅទំព័រនេះប៉ុណ្ណោះ', 
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          row(Icons.calendar_today, 'កាលបរិច្ឆេទ', historyDateFullText(h)),
          row(Icons.access_time, 'ម៉ោង', time),
          row(Icons.person, 'អាចារ្យ', (h['leader'] ?? '').toString()),
          row(Icons.place, 'ទីតាំង', (h['place'] ?? '').toString()),
          row(Icons.info_outline, 'បញ្ជាក់', (h['note'] ?? '').toString()),
          ListTile(
            dense: true,
            leading: const Icon(Icons.groups),
            title: Text('ព្រះសង្ឃ (${kh(names.length)} អង្គ)',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(
              [for (var i = 0; i < names.length; i++) '${kh(i + 1)}. ${names[i]}'].join('\n'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: SelectableText((h['message'] ?? '').toString(),
                  style: const TextStyle(fontSize: 15, height: 1.3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy សារ'),
              onPressed: () => copyHistory(context, h),
            ),
          ),
        ],
      ),
    );
  }
}
