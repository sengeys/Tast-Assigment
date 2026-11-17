// អេក្រង់ជ្រើសរើសបុគ្គលិក
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import 'details_screen.dart';

// ---------------- 2. Staff selection ----------------
class StaffSelectScreen extends StatefulWidget {
  const StaffSelectScreen({super.key});
  @override
  State<StaffSelectScreen> createState() => _StaffSelectScreenState();
}

class _StaffSelectScreenState extends State<StaffSelectScreen> {
  String? roleFilter;
  String query = '';
  bool initialized = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!initialized) {
      final r = s.template?['role'];
      if (r != null && r.toString().isNotEmpty) roleFilter = r;
      initialized = true;
    }
    final list = s.staff.where((x) {
      final okRole = roleFilter == null || x['role'] == roleFilter;
      final okName = query.isEmpty || (x['name'] as String).contains(query);
      return okRole && okName;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('ជ្រើសរើសបុគ្គលិក (${kh(s.selected.length)})')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'ស្វែងរកឈ្មោះ', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                      label: const Text('ទាំងអស់'),
                      selected: roleFilter == null,
                      onSelected: (_) => setState(() => roleFilter = null)),
                ),
                for (final r in s.roles)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(r),
                        selected: roleFilter == r,
                        onSelected: (_) => setState(() => roleFilter = r)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final x = list[i];
                return CheckboxListTile(
                  value: s.selected.contains(x['id']),
                  onChanged: (_) => s.toggle(x['id']),
                  title: Text(x['name']),
                  subtitle: Text([
                    x['role'],
                    if (x['age'] != null) 'អាយុ ${kh(x['age'])} ឆ្នាំ',
                    x['phone']
                  ]
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(' • ')),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add',
            child: const Icon(Icons.person_add),
            onPressed: () async {
              final name = await askText(context, 'ឈ្មោះបុគ្គលិកថ្មី');
              if (name == null || name.isEmpty) return;
              await Db.insert('staff', {'name': name, 'role': roleFilter ?? '', 'phone': ''});
              s.load();
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'next',
            icon: const Icon(Icons.arrow_forward),
            label: const Text('បន្ទាប់'),
            onPressed: s.selected.isEmpty
                ? null
                : () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const DetailsScreen())),
          ),
        ],
      ),
    );
  }
}
