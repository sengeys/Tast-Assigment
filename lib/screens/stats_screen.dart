// អេក្រង់ស្ថិតិការទៅធ្វើការ
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../core/khmer.dart';
import '../core/roles.dart';
import '../core/staff_avatar_color.dart';
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

enum StatParticipation { all, direct, indirect, sermon, precepts }

class _ChartPoint {
  const _ChartPoint(this.date, this.count);

  final DateTime date;
  final int count;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _sanghaFilter = '__sangha_group__';
  static const _vassaFilter = '__vassa_order__';

  StatPeriod period = StatPeriod.month;
  StatSort sort = StatSort.most; // ពេលចូលដំបូង: ច្រើនជាងគេមុន
  DateTime anchor = DateTime.now();
  String? roleFilter; // null = ទាំងអស់ (គ្រប់តួនាទី)
  StatParticipation participationFilter = StatParticipation.all;
  List<Map<String, dynamic>> rows = [];
  List<_ChartPoint> chartData = [];
  int taskCount = 0;
  bool loading = true;

  int _countFor(Map<String, dynamic> row) {
    return switch (participationFilter) {
      StatParticipation.all => row['c'] as int,
      StatParticipation.direct => row['direct_c'] as int,
      StatParticipation.indirect => row['indirect_c'] as int,
      StatParticipation.sermon => row['sermon_c'] as int,
      StatParticipation.precepts => row['precept_c'] as int,
    };
  }

  int _roleFilterCount(String? role) {
    if (role == null || role == _vassaFilter) return rows.length;
    if (role == _sanghaFilter) {
      return rows.where((row) => isSanghaRole(row['role'])).length;
    }
    return rows.where((row) => matchesRoleFilter(row['role'], role)).length;
  }

  String _roleFilterName(String role) => switch (role) {
        _sanghaFilter => 'គណៈសង្ឃ',
        _vassaFilter => 'វស្សា',
        _ => role,
      };

  Widget _roleFilterMenuItem({
    required String label,
    required int count,
    required bool selected,
  }) {
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return Row(
      children: [
        if (selected)
          Icon(Icons.check_circle_outline, size: 20, color: color)
        else
          const SizedBox(width: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text('(${kh(count)})', style: TextStyle(color: color)),
      ],
    );
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
        'SELECT history_id, staff_id, COALESCE(direct, 0) AS direct, '
        '0 AS sermon, 0 AS precept '
        'FROM task_staff '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct, 1 AS sermon, '
        '0 AS precept FROM task_preachers '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct, 0 AS sermon, '
        '1 AS precept FROM task_precept_givers'
        '), attendance AS ('
        'SELECT history_id, staff_id, MAX(direct) AS direct, '
        'MAX(sermon) AS sermon, MAX(precept) AS precept '
        'FROM participation GROUP BY history_id, staff_id'
        ') '
        'SELECT s.id, s.name, s.role, s.age, COUNT(h.id) AS c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.direct = 1 '
        'THEN 1 ELSE 0 END) AS direct_c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.direct = 0 '
        'THEN 1 ELSE 0 END) AS indirect_c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.sermon = 1 '
        'THEN 1 ELSE 0 END) AS sermon_c, '
        'SUM(CASE WHEN h.id IS NOT NULL AND a.precept = 1 '
        'THEN 1 ELSE 0 END) AS precept_c FROM staff s '
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
    final chart = await _loadChartData(db, r);
    if (!mounted) return;
    setState(() {
      rows = data;
      taskCount = Sqflite.firstIntValue(t) ?? 0;
      chartData = chart;
      loading = false;
    });
  }

  Future<List<_ChartPoint>> _loadChartData(
      Database db, (String?, String?) dateRange) async {
    final counts = <int, int>{};
    switch (period) {
      case StatPeriod.day:
        final date = DateFormat('yyyy-MM-dd').format(anchor);
        final data = await db.rawQuery(
          'SELECT CAST(start_min / 60 AS INTEGER) AS bucket, COUNT(*) AS c '
          'FROM task_history WHERE task_date = ? AND start_min IS NOT NULL '
          'GROUP BY bucket',
          [date],
        );
        for (final row in data) {
          counts[row['bucket'] as int] = row['c'] as int;
        }
        return List.generate(
          24,
          (hour) => _ChartPoint(
            DateTime(anchor.year, anchor.month, anchor.day, hour),
            counts[hour] ?? 0,
          ),
        );
      case StatPeriod.month:
        final data = await db.rawQuery(
          'SELECT CAST(substr(task_date, 9, 2) AS INTEGER) AS bucket, '
          'COUNT(*) AS c FROM task_history '
          'WHERE task_date BETWEEN ? AND ? GROUP BY bucket',
          [dateRange.$1, dateRange.$2],
        );
        for (final row in data) {
          counts[row['bucket'] as int] = row['c'] as int;
        }
        final days = DateTime(anchor.year, anchor.month + 1, 0).day;
        return List.generate(
          days,
          (index) => _ChartPoint(
            DateTime(anchor.year, anchor.month, index + 1),
            counts[index + 1] ?? 0,
          ),
        );
      case StatPeriod.year:
        final data = await db.rawQuery(
          'SELECT CAST(substr(task_date, 6, 2) AS INTEGER) AS bucket, '
          'COUNT(*) AS c FROM task_history '
          'WHERE task_date BETWEEN ? AND ? GROUP BY bucket',
          [dateRange.$1, dateRange.$2],
        );
        for (final row in data) {
          counts[row['bucket'] as int] = row['c'] as int;
        }
        return List.generate(
          12,
          (index) => _ChartPoint(
            DateTime(anchor.year, index + 1),
            counts[index + 1] ?? 0,
          ),
        );
      case StatPeriod.all:
        final data = await db.rawQuery(
          'SELECT substr(task_date, 1, 7) AS bucket, COUNT(*) AS c '
          'FROM task_history WHERE task_date IS NOT NULL '
          'GROUP BY bucket ORDER BY bucket',
        );
        if (data.isEmpty) return [];
        final first = DateTime.parse('${data.first['bucket']}-01');
        final last = DateTime.parse('${data.last['bucket']}-01');
        for (final row in data) {
          final date = DateTime.parse('${row['bucket']}-01');
          counts[date.year * 12 + date.month] = row['c'] as int;
        }
        final monthCount =
            (last.year - first.year) * 12 + last.month - first.month + 1;
        return List.generate(
          monthCount,
          (index) {
            final date = DateTime(first.year, first.month + index);
            return _ChartPoint(
              date,
              counts[date.year * 12 + date.month] ?? 0,
            );
          },
        );
    }
  }

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final r = range;
    final db = await Db.instance;
    final d = await db.rawQuery(
        'WITH participation AS ('
        'SELECT history_id, staff_id, COALESCE(direct, 0) AS direct, '
        '0 AS sermon, 0 AS precept '
        'FROM task_staff '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct, 1 AS sermon, '
        '0 AS precept FROM task_preachers '
        'UNION ALL '
        'SELECT history_id, staff_id, 0 AS direct, 0 AS sermon, '
        '1 AS precept FROM task_precept_givers'
        '), attendance AS ('
        'SELECT history_id, staff_id, MAX(direct) AS direct, '
        'MAX(sermon) AS sermon, MAX(precept) AS precept '
        'FROM participation GROUP BY history_id, staff_id'
        ') '
        'SELECT h.title, h.place, h.task_date, h.start_min, h.end_min, '
        'a.direct, a.sermon, a.precept '
        'FROM attendance a '
        'JOIN task_history h ON h.id = a.history_id '
        'WHERE a.staff_id = ? AND h.task_date IS NOT NULL '
        'AND (? IS NULL OR h.task_date BETWEEN ? AND ?) '
        'AND CASE ? '
        "WHEN 'all' THEN 1 "
        "WHEN 'direct' THEN a.direct "
        "WHEN 'indirect' THEN 1 - a.direct "
        "WHEN 'sermon' THEN a.sermon "
        "WHEN 'precepts' THEN a.precept "
        'END = 1 '
        'ORDER BY h.task_date DESC, h.start_min DESC',
        [
          row['id'],
          r.$1,
          r.$1,
          r.$2,
          participationFilter.name,
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
                        final labels = [
                          if (d[i]['direct'] == 1) 'ផ្ទាល់',
                          if (d[i]['sermon'] == 1) 'ទេសនា',
                          if (d[i]['precept'] == 1) 'ប្រទានសីល',
                        ];
                        return ListTile(
                          dense: true,
                          title: Text(
                              '${d[i]['title']}${place.isEmpty ? '' : ' • នៅ $place'}'
                              '${labels.isEmpty ? '' : ' (${labels.join(' • ')})'}'),
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
    final filterRoles = [
      _sanghaFilter,
      ...roles.where((role) => !isSanghaRole(role)),
    ];
    var list = rows
        .where((x) =>
            roleFilter == null ||
            roleFilter == _vassaFilter ||
            (roleFilter == _sanghaFilter
                ? isSanghaRole(x['role'])
                : matchesRoleFilter(x['role'], roleFilter)))
        .where((x) =>
            participationFilter == StatParticipation.all || _countFor(x) > 0)
        .toList();
    if (roleFilter == _vassaFilter) {
      list.sort(compareStaffByVassa);
    } else {
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
    }
    final total = list.fold<int>(0, (s, x) => s + _countFor(x));
    final maxC =
        list.fold<int>(0, (s, x) => _countFor(x) > s ? _countFor(x) : s);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ស្ថិតិការទៅបុណ្យ'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'ត្រងតាមតួនាទី',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(
              () => roleFilter = value.isEmpty ? null : value,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '',
                child: _roleFilterMenuItem(
                  label: 'ទាំងអស់',
                  count: _roleFilterCount(null),
                  selected: roleFilter == null,
                ),
              ),
              for (final role in filterRoles)
                PopupMenuItem(
                  value: role,
                  child: _roleFilterMenuItem(
                    label: _roleFilterName(role),
                    count: _roleFilterCount(role),
                    selected: roleFilter == role,
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _vassaFilter,
                child: _roleFilterMenuItem(
                  label: 'វស្សា',
                  count: _roleFilterCount(_vassaFilter),
                  selected: roleFilter == _vassaFilter,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<StatPeriod>(
                segments: const [
                  ButtonSegment(
                      value: StatPeriod.day, label: Text('ប្រចាំថ្ងៃ')),
                  ButtonSegment(
                      value: StatPeriod.month, label: Text('ប្រចាំខែ')),
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
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 240,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'និន្នាការចំនួនបុណ្យ'),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat(switch (period) {
                        StatPeriod.day => 'HH:mm',
                        StatPeriod.month => 'd/M',
                        StatPeriod.year => 'MMM',
                        StatPeriod.all => 'MM/yy',
                      }),
                      intervalType: switch (period) {
                        StatPeriod.day => DateTimeIntervalType.hours,
                        StatPeriod.month => DateTimeIntervalType.days,
                        StatPeriod.year ||
                        StatPeriod.all =>
                          DateTimeIntervalType.months,
                      },
                      interval: switch (period) {
                        StatPeriod.day => 3,
                        StatPeriod.month => 5,
                        StatPeriod.year => 2,
                        StatPeriod.all => null,
                      },
                    ),
                    primaryYAxis: NumericAxis(minimum: 0),
                    series: <SplineAreaSeries<_ChartPoint, DateTime>>[
                      SplineAreaSeries<_ChartPoint, DateTime>(
                        dataSource: chartData,
                        xValueMapper: (point, _) => point.date,
                        yValueMapper: (point, _) => point.count,
                        name: 'ចំនួនបុណ្យ',
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.25),
                        borderColor: Theme.of(context).colorScheme.primary,
                        borderWidth: 2,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                    ],
                  ),
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
                  for (final entry in <(StatParticipation, String)>[
                    (StatParticipation.all, 'ទាំងអស់'),
                    (StatParticipation.direct, 'ផ្ទាល់'),
                    (StatParticipation.indirect, 'មិនផ្ទាល់'),
                    (StatParticipation.sermon, 'ទេសនា'),
                    (StatParticipation.precepts, 'ប្រទានសីល'),
                  ])
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text(entry.$2),
                        selected: participationFilter == entry.$1,
                        onSelected: (_) =>
                            setState(() => participationFilter = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              const Center(child: Text('គ្មានទិន្នន័យ'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final x = list[i];
                  final c = _countFor(x);
                  final isTop = roleFilter != _vassaFilter &&
                      sort == StatSort.most &&
                      i == 0 &&
                      c > 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: staffAvatarColor(x['id'] as int),
                      foregroundColor: Colors.white,
                      child: isTop
                          ? Icon(
                              Icons.emoji_events,
                              color: Colors.white,
                            )
                          : Text(
                              kh(i + 1),
                              style: const TextStyle(fontSize: 14),
                            ),
                    ),
                    title: Text(formatStaffName(x),
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: maxC == 0 ? 0 : c / maxC,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    trailing: Text('${kh(c)} ដង',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _showDetail(x),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
