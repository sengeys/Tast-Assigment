// អេក្រង់ស្ថិតិការទៅធ្វើការ
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

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

enum StatPeriod { day, month, year, all }

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
  bool? directFilter;
  List<Map<String, dynamic>> rows = [];
  int taskCount = 0;
  bool loading = true;

  int _countFor(Map<String, dynamic> row) {
    if (directFilter == true) return row['direct_c'] as int;
    if (directFilter == false) return row['indirect_c'] as int;
    return row['c'] as int;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  (String?, String?) get range {
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
      case StatPeriod.all:
        return (null, null);
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
      case StatPeriod.all:
        return 'ទាំងអស់';
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
      case StatPeriod.all:
        return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = range;
    final db = await Db.instance;
    final data = await db.rawQuery(
        'WITH participation AS ('
        'SELECT history_id, staff_id, COALESCE(direct, 0) AS direct '
        'FROM task_staff '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct FROM task_preachers '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct FROM task_precept_givers'
        '), attendance AS ('
        'SELECT history_id, staff_id, MAX(direct) AS direct '
        'FROM participation GROUP BY history_id, staff_id'
        ') '
        'SELECT s.id, s.name, s.role, COUNT(h.id) AS c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.direct = 1 '
        'THEN 1 ELSE 0 END) AS direct_c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.direct = 0 '
        'THEN 1 ELSE 0 END) AS indirect_c FROM staff s '
        'LEFT JOIN attendance a ON a.staff_id = s.id '
        'LEFT JOIN task_history h ON h.id = a.history_id '
        'AND h.task_date IS NOT NULL '
        'AND (? IS NULL OR h.task_date BETWEEN ? AND ?) '
        'GROUP BY s.id',
        [r.$1, r.$1, r.$2]);
    final t = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM task_history '
        'WHERE task_date IS NOT NULL '
        'AND (? IS NULL OR task_date BETWEEN ? AND ?)',
        [r.$1, r.$1, r.$2]);
    if (!mounted) return;
    setState(() {
      rows = data;
      taskCount = Sqflite.firstIntValue(t) ?? 0;
      loading = false;
    });
  }

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final r = range;
    final filterValue = directFilter == null ? null : (directFilter! ? 1 : 0);
    final db = await Db.instance;
    final d = await db.rawQuery(
        'WITH participation AS ('
        'SELECT history_id, staff_id, COALESCE(direct, 0) AS direct '
        'FROM task_staff '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct FROM task_preachers '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct FROM task_precept_givers'
        '), attendance AS ('
        'SELECT history_id, staff_id, MAX(direct) AS direct '
        'FROM participation GROUP BY history_id, staff_id'
        ') '
        'SELECT h.title, h.place, h.task_date, h.start_min, h.end_min, a.direct '
        'FROM attendance a '
        'JOIN task_history h ON h.id = a.history_id '
        'WHERE a.staff_id = ? AND h.task_date IS NOT NULL '
        'AND (? IS NULL OR h.task_date BETWEEN ? AND ?) '
        'AND (? IS NULL OR a.direct = ?) '
        'ORDER BY h.task_date DESC, h.start_min DESC',
        [
          row['id'],
          r.$1,
          r.$1,
          r.$2,
          filterValue,
          filterValue,
        ]);
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
                  ? const Center(child: Text('មិនមានប្រវត្តិការទៅបុណ្យ'))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: d.length,
                      itemBuilder: (_, i) {
                        final place = (d[i]['place'] ?? '').toString();
                        final direct = (d[i]['direct'] as int? ?? 0) == 1;
                        return ListTile(
                          dense: true,
                          title: Text(
                              '${d[i]['title']}${place.isEmpty ? '' : ' • នៅ $place'}'
                              '${direct ? ' (ផ្ទាល់)' : ''}'),
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
    final appState = context.watch<AppState>();
    final roles = appState.roles;
    final usesCustomOrangeTheme = appState.usesCustomOrangeTheme;
    var list = rows
        .where((x) =>
            roleFilter == null ||
            (roleFilter == 'ភិក្ខុ'
                ? isBhikkhuRole(x['role'])
                : x['role'] == roleFilter))
        .where((x) => directFilter == null || _countFor(x) > 0)
        .toList();
    switch (sort) {
      case StatSort.most:
        list.sort((a, b) {
          final c = _countFor(b).compareTo(_countFor(a));
          return c != 0
              ? c
              : (a['name'] as String).compareTo(b['name'] as String);
        });
      case StatSort.least:
        list.sort((a, b) {
          final c = _countFor(a).compareTo(_countFor(b));
          return c != 0
              ? c
              : (a['name'] as String).compareTo(b['name'] as String);
        });
      case StatSort.name:
        list.sort(compareStaff);
    }
    final total = list.fold<int>(0, (s, x) => s + _countFor(x));
    final maxC =
        list.fold<int>(0, (s, x) => _countFor(x) > s ? _countFor(x) : s);

    return Scaffold(
      appBar: AppBar(title: const Text('ស្ថិតិការទៅបុណ្យ')),
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
                ButtonSegment(value: StatPeriod.all, label: Text('ទាំងអស់')),
              ],
              selected: {period},
              onSelectionChanged: (v) {
                period = v.first;
                _load();
              },
            ),
          ),
          if (period == StatPeriod.all)
            SizedBox(
              height: 48,
              child: Center(
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
            )
          else
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
                    const Text('ចំនួនបុណ្យ (សរុប)'),
                  ]),
                  Column(children: [
                    Text(kh(total),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('ចំនួនអ្នកទៅបុណ្យ (សរុប)'),
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
                        side: appState.usesCustomOrangeTheme
                            ? BorderSide(
                                color: sort == e.key
                                    ? const Color(0xFFFFECDF)
                                    : const Color(0xFFFF7643),
                              )
                            : null,
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
                for (final entry in <(bool?, String)>[
                  (null, 'ទាំងអស់'),
                  (true, 'ផ្ទាល់'),
                  (false, 'មិនផ្ទាល់'),
                ])
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: directFilter == entry.$1,
                      side: appState.usesCustomOrangeTheme
                          ? BorderSide(
                              color: directFilter == entry.$1
                                  ? const Color(0xFFFFECDF)
                                  : const Color(0xFFFF7643),
                            )
                          : null,
                      onSelected: (_) =>
                          setState(() => directFilter = entry.$1),
                    ),
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
                      side: appState.usesCustomOrangeTheme
                          ? BorderSide(
                              color: roleFilter == null
                                  ? const Color(0xFFFFECDF)
                                  : const Color(0xFFFF7643),
                            )
                          : null,
                      onSelected: (_) => setState(() => roleFilter = null)),
                ),
                for (final r in roles)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(r),
                        selected: roleFilter == r,
                        side: appState.usesCustomOrangeTheme
                            ? BorderSide(
                                color: roleFilter == r
                                    ? const Color(0xFFFFECDF)
                                    : const Color(0xFFFF7643),
                              )
                            : null,
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
                          final c = _countFor(x);
                          final isTop =
                              sort == StatSort.most && i == 0 && c > 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: usesCustomOrangeTheme
                                  ? const Color(0xFFFFECDF)
                                  : (isTop ? Colors.amber : null),
                              child: isTop
                                  ? Icon(
                                      Icons.emoji_events,
                                      color: usesCustomOrangeTheme
                                          ? const Color(0xFFFF7643)
                                          : Colors.white,
                                    )
                                  : Text(
                                      kh(i + 1),
                                      style: TextStyle(
                                        color: usesCustomOrangeTheme
                                            ? const Color(0xFF000000)
                                            : null,
                                      ),
                                    ),
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
