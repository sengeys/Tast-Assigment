// អេក្រង់ស្ថិតិការទៅធ្វើការ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:task_assignment/core/khmer_lunar.dart';

import '../core/khmer.dart';
import '../core/roles.dart';
import '../data/db.dart';
import '../state/app_state.dart';

// ---------------- Statistics ----------------
const _khMonths = [
  'មករា',
  'កុម្ភៈ',
  'មីនា',
  'មេសា',
  'ឧសភា',
  'មិថុនា',
  'កក្កដា',
  'សីហា',
  'កញ្ញា',
  'តុលា',
  'វិច្ឆិកា',
  'ធ្នូ'
];

enum StatPeriod { day, month, year }

enum StatSort { most, least, name }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatPeriod period = StatPeriod.month;
  StatSort sort = StatSort.most; // ពេលចូលដំបូង: ច្រើនជាងគេមុន
  DateTime anchor = DateTime.now();
  String? roleFilter; // null = ទាំងអស់ (គ្រប់តួនាទី)
  List<Map<String, dynamic>> rows = [];
  int taskCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (String, String) get range {
    final f = DateFormat('yyyy-MM-dd');
    switch (period) {
      case StatPeriod.day:
        final s = f.format(anchor);
        return (s, s);
      case StatPeriod.month:
        return (
          f.format(DateTime(anchor.year, anchor.month, 1)),
          f.format(DateTime(anchor.year, anchor.month + 1, 0))
        );
      case StatPeriod.year:
        return (
          f.format(DateTime(anchor.year, 1, 1)),
          f.format(DateTime(anchor.year, 12, 31))
        );
    }
  }

  String get label {
    switch (period) {
      case StatPeriod.day:
        return khDate(anchor);
      case StatPeriod.month:
        return 'ខែ${_khMonths[anchor.month - 1]} ឆ្នាំ${kh(anchor.year)}';
      case StatPeriod.year:
        return 'ឆ្នាំ ${kh(anchor.year)}';
    }
  }

  void _shift(int dir) {
    switch (period) {
      case StatPeriod.day:
        anchor = anchor.add(Duration(days: dir));
      case StatPeriod.month:
        anchor = DateTime(anchor.year, anchor.month + dir, 1);
      case StatPeriod.year:
        anchor = DateTime(anchor.year + dir, anchor.month, 1);
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = range;
    final db = await Db.instance;
    final data = await db.rawQuery(
        'SELECT s.id, s.name, s.role, COUNT(ts.id) AS c FROM staff s '
        'LEFT JOIN task_staff ts ON ts.staff_id = s.id AND ts.task_date BETWEEN ? AND ? '
        'GROUP BY s.id',
        [r.$1, r.$2]);
    final t = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM task_history WHERE task_date BETWEEN ? AND ?',
        [r.$1, r.$2]);
    if (!mounted) return;
    setState(() {
      rows = data;
      taskCount = Sqflite.firstIntValue(t) ?? 0;
      loading = false;
    });
  }

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final r = range;
    final db = await Db.instance;
    final d = await db.rawQuery(
        'SELECT h.title, h.place, ts.task_date, ts.start_min, ts.end_min FROM task_staff ts '
        'JOIN task_history h ON h.id = ts.history_id '
        'WHERE ts.staff_id = ? AND ts.task_date BETWEEN ? AND ? '
        'ORDER BY ts.task_date DESC, ts.start_min DESC',
        [row['id'], r.$1, r.$2]);
    if (!mounted) return;
    String time(Map<String, dynamic> x) {
      final a = x['start_min'], b = x['end_min'];
      if (a == null || b == null) return '';
      return ' • ${khTime(TimeOfDay(hour: a ~/ 60, minute: a % 60))}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Column(
          children: [
            ListTile(
              title: Text('${formatStaffName(row)} — ${kh(d.length)} ដង',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(label),
            ),
            const Divider(height: 1),
            Expanded(
              child: d.isEmpty
                  ? const Center(child: Text('មិនមានការងារ'))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: d.length,
                      itemBuilder: (_, i) {
                        final place = (d[i]['place'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          title: Text(
                              '${d[i]['title']}${place.isEmpty ? '' : ' • នៅ $place'}'),
                          subtitle: Text(
                              'ថ្ងៃ${khDate(DateTime.parse(d[i]['task_date'] as String))}${time(d[i])}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<AppState>().roles;
    var list = rows
        .where((x) => roleFilter == null || x['role'] == roleFilter)
        .toList();
    switch (sort) {
      case StatSort.most:
        list.sort((a, b) {
          final c = (b['c'] as int).compareTo(a['c'] as int);
          return c != 0
              ? c
              : (a['name'] as String).compareTo(b['name'] as String);
        });
      case StatSort.least:
        list.sort((a, b) {
          final c = (a['c'] as int).compareTo(b['c'] as int);
          return c != 0
              ? c
              : (a['name'] as String).compareTo(b['name'] as String);
        });
      case StatSort.name:
        list.sort(compareStaff);
    }
    final total = list.fold<int>(0, (s, x) => s + (x['c'] as int));
    final maxC =
        list.fold<int>(0, (s, x) => (x['c'] as int) > s ? x['c'] as int : s);

    return Scaffold(
      appBar: AppBar(title: const Text('ស្ថិតិការទៅធ្វើការ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<StatPeriod>(
              segments: const [
                ButtonSegment(value: StatPeriod.day, label: Text('ប្រចាំថ្ងៃ')),
                ButtonSegment(value: StatPeriod.month, label: Text('ប្រចាំខែ')),
                ButtonSegment(
                    value: StatPeriod.year, label: Text('ប្រចាំឆ្នាំ')),
              ],
              selected: {period},
              onSelectionChanged: (v) {
                period = v.first;
                _load();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1)),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: anchor,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2100));
                  if (d != null) {
                    anchor = d;
                    _load();
                  }
                },
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1)),
            ],
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    Text(kh(taskCount),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('ការងារ'),
                  ]),
                  Column(children: [
                    Text(kh(total),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('ចំនួនអ្នកទៅធ្វើការ (សរុប)'),
                  ]),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final e in {
                  StatSort.most: 'ច្រើនជាងគេ',
                  StatSort.least: 'តិចជាងគេ',
                  StatSort.name: 'តាមតួនាទី',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(e.value),
                        selected: sort == e.key,
                        onSelected: (_) => setState(() => sort = e.key)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
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
                for (final r in roles)
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
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('គ្មានទិន្នន័យ'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final x = list[i];
                          final c = x['c'] as int;
                          final isTop =
                              sort == StatSort.most && i == 0 && c > 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isTop ? Colors.amber : null,
                              child: isTop
                                  ? const Icon(Icons.emoji_events,
                                      color: Colors.white)
                                  : Text(kh(i + 1)),
                            ),
                            title: Text(formatStaffName(x)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(
                                  value: maxC == 0 ? 0 : c / maxC),
                            ),
                            trailing: Text('${kh(c)} ដង',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onTap: () => _showDetail(x),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
