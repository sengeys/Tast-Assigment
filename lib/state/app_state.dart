// State ទូទៅរបស់ App (Provider): ទិន្នន័យ, Draft ការចាត់តាំង, សារ, ការពិនិត្យជាន់ម៉ោង
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/khmer.dart';
import '../core/khmer_lunar.dart';
import '../core/preaching.dart';
import '../core/roles.dart';
import '../core/statuses.dart';
import '../data/db.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  static const themeSeeds = <Color>[
    Colors.teal,
    Colors.blue,
    Colors.deepPurple,
    Colors.deepOrange,
  ];
  static const _themeSeedKey = 'appThemeSeedIndex';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();
  int _themeSeedIndex = 0;

  Color get themeSeed => themeSeeds[_themeSeedIndex];

  List<Map<String, dynamic>> staff = [],
      leaders = [],
      templates = [],
      places = [],
      history = [];

  // current task draft
  Map<String, dynamic>? template;
  String title = '';
  String note = ''; // បញ្ជាក់
  final Set<int> selected = {};
  final Set<int> directInvites = {};
  bool directInviteEnabled = false;
  final Set<int> preacherIds = {};
  final Set<int> preceptGiverIds = {};
  Set<int> busyStaffIds = {};
  bool preachDharma = false;
  String? preceptsType;
  DateTime date = DateTime.now();
  TimeOfDay? start, end;
  int? leaderId;
  String? place;

  Future<void> load() async {
    final savedThemeIndex = await _preferences.getInt(_themeSeedKey);
    if (savedThemeIndex != null &&
        savedThemeIndex >= 0 &&
        savedThemeIndex < themeSeeds.length) {
      _themeSeedIndex = savedThemeIndex;
    }
    await Db.applyAnnualVassaUpdate();
    staff = List.of(await Db.all('staff'))..sort(compareStaff);
    leaders = await Db.all('leaders');
    templates = await Db.all('templates');
    places = await Db.all('places');
    history = await Db.all('task_history',
        orderBy: 'task_date DESC, start_min DESC, id DESC');
    notifyListeners();
  }

  Future<void> setThemeSeed(int index) async {
    if (index < 0 || index >= themeSeeds.length) {
      throw RangeError.index(index, themeSeeds, 'index');
    }
    await _preferences.setInt(_themeSeedKey, index);
    _themeSeedIndex = index;
    notifyListeners();
  }

  int? editingId; // មានតម្លៃ = កំពុងកែប្រវត្តិការចាត់តាំងមួយ

  /// ផ្ទុកទិន្នន័យការចាត់តាំងចាស់ ចូលក្នុង Form ដើម្បីកែប្រែ
  Future<void> startEdit(Map<String, dynamic> h) async {
    final db = await Db.instance;
    final rows = await db
        .query('task_staff', where: 'history_id = ?', whereArgs: [h['id']]);
    final preacherRows = await db.query(
      'task_preachers',
      where: 'history_id = ?',
      whereArgs: [h['id']],
    );
    final preceptGiverRows = await db.query(
      'task_precept_givers',
      where: 'history_id = ?',
      whereArgs: [h['id']],
    );
    editingId = h['id'] as int;
    template = null;
    title = (h['title'] ?? '').toString();
    note = (h['note'] ?? '').toString();
    selected
      ..clear()
      ..addAll(rows.map((r) => r['staff_id']).whereType<int>().where((id) =>
          staff.any((x) => x['id'] == id && canAttendWithMonks(x['status']))));
    directInvites
      ..clear()
      ..addAll(rows
          .where((r) => r['direct'] == 1)
          .map((r) => r['staff_id'])
          .whereType<int>()
          .where(selected.contains));
    directInviteEnabled = directInvites.isNotEmpty;
    preacherIds
      ..clear()
      ..addAll(preacherRows.map((r) => r['staff_id']).whereType<int>().where(
          (id) => staff
              .any((x) => x['id'] == id && canAttendWithMonks(x['status']))));
    preceptGiverIds
      ..clear()
      ..addAll(preceptGiverRows
          .map((r) => r['staff_id'])
          .whereType<int>()
          .where((id) => staff
              .any((x) => x['id'] == id && canAttendWithMonks(x['status']))));
    preachDharma = h['preach_dharma'] == 1;
    final savedPreceptsType = (h['precepts_type'] ?? '').toString();
    preceptsType =
        preceptsTypes.contains(savedPreceptsType) ? savedPreceptsType : null;
    busyStaffIds = {};
    date =
        DateTime.tryParse((h['task_date'] ?? '').toString()) ?? DateTime.now();
    TimeOfDay? t(Object? m) =>
        m == null ? null : TimeOfDay(hour: (m as int) ~/ 60, minute: m % 60);
    start = t(h['start_min']);
    end = t(h['end_min']);
    leaderId = null;
    final ln = (h['leader'] ?? '').toString();
    final storedLeaderId = h['leader_id'];
    for (final l in leaders) {
      final matchesLeader =
          storedLeaderId == null ? l['name'] == ln : l['id'] == storedLeaderId;
      if (matchesLeader && canAttendAsLeader(l['status'])) {
        leaderId = l['id'] as int;
      }
    }
    final pl = (h['place'] ?? '').toString();
    place = pl.isEmpty ? null : pl;
    notifyListeners();
  }

  void startFromTemplate(Map<String, dynamic>? t) {
    editingId = null;
    template = t;
    title = t?['title'] ?? '';
    note = (t?['note'] ?? '').toString();
    selected.clear();
    directInvites.clear();
    directInviteEnabled = false;
    preacherIds.clear();
    preceptGiverIds.clear();
    busyStaffIds = {};
    preachDharma = false;
    preceptsType = null;
    date =
        DateTime.tryParse((t?['task_date'] ?? '').toString()) ?? DateTime.now();
    start = parseTime(t?['start_time']);
    end = parseTime(t?['end_time']);
    final templateLeaderId = t?['leader_id'];
    leaderId = leaders.any((leader) =>
            leader['id'] == templateLeaderId &&
            canAttendAsLeader(leader['status']))
        ? templateLeaderId as int?
        : null;
    place = t?['place'];
    notifyListeners();
  }

  /// រក្សាទុកការចាត់តាំងបច្ចុប្បន្ន ជាគំរូថ្មី (ព័ត៌មានពេញលេញ)
  Future<void> saveAsTemplate(String name) async {
    _sanitizeAssignments();
    final roleSet = staff
        .where((x) =>
            selected.contains(x['id']) && canAttendWithMonks(x['status']))
        .map((x) => (x['role'] ?? '').toString())
        .where((r) => r.isNotEmpty)
        .toSet();
    final role = roleSet.length == 1
        ? roleSet.first
        : (template?['role'] ?? '').toString();
    await Db.insert('templates', {
      'title': name,
      'role': role,
      'start_time': fmtTime(start),
      'end_time': fmtTime(end),
      'leader_id': leaderId,
      'place': place ?? '',
      'note': note.trim(),
      'is_temporary': 0,
      'archived': 0,
      'task_date': DateFormat('yyyy-MM-dd').format(date),
    });
    await load();
  }

  List<String> get roles {
    final r = staff
        .map((s) => (s['role'] ?? '') as String)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
    r.sort((a, b) {
      final c = roleRank(a).compareTo(roleRank(b));
      return c != 0 ? c : a.compareTo(b);
    });
    return r;
  }

  List<Map<String, dynamic>> get _eligibleSelectedStaff => staff
      .where(
          (s) => selected.contains(s['id']) && canAttendWithMonks(s['status']))
      .toList();

  List<String> get selectedNames =>
      _eligibleSelectedStaff.map((s) => s['name'] as String).toList();

  List<Map<String, dynamic>> get selectedPreachers => !preachDharma
      ? []
      : staff
          .where((s) =>
              preacherIds.contains(s['id']) && canAttendWithMonks(s['status']))
          .toList();

  List<Map<String, dynamic>> get selectedPreceptGivers => preceptsType == null
      ? []
      : staff
          .where((s) =>
              preceptGiverIds.contains(s['id']) &&
              selected.contains(s['id']) &&
              canAttendWithMonks(s['status']))
          .toList();

  List<Map<String, dynamic>> get _eligibleAttendees {
    final peopleById = <int, Map<String, dynamic>>{};
    for (final person in [
      ..._eligibleSelectedStaff,
      ...selectedPreachers,
      ...selectedPreceptGivers,
    ]) {
      final id = person['id'];
      if (id is int) peopleById[id] = person;
    }
    return peopleById.values.toList();
  }

  void _sanitizeAssignments() {
    final eligibleStaffIds = staff
        .where((x) => canAttendWithMonks(x['status']))
        .map((x) => x['id'])
        .whereType<int>()
        .toSet();
    selected.removeWhere((id) => !eligibleStaffIds.contains(id));
    directInvites.removeWhere((id) => !selected.contains(id));
    preacherIds.removeWhere((id) => !eligibleStaffIds.contains(id));
    preceptGiverIds.removeWhere(
        (id) => !eligibleStaffIds.contains(id) || !selected.contains(id));
    if (preceptsType != null && !preceptsTypes.contains(preceptsType)) {
      preceptsType = null;
    }
    if (!preachDharma) preacherIds.clear();
    if (preceptsType == null) preceptGiverIds.clear();
    if (leaderId != null &&
        !leaders.any(
            (x) => x['id'] == leaderId && canAttendAsLeader(x['status']))) {
      leaderId = null;
    }
  }

  String? get leaderName {
    for (final l in leaders) {
      if (l['id'] == leaderId && canAttendAsLeader(l['status'])) {
        return l['name'];
      }
    }
    return null;
  }

  void toggle(int id) {
    if (selected.contains(id)) {
      selected.remove(id);
      directInvites.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void toggleDirectInvite(int id) {
    if (!selected.contains(id)) return;
    directInvites.contains(id)
        ? directInvites.remove(id)
        : directInvites.add(id);
    notifyListeners();
  }

  void update(void Function() f) {
    f();
    notifyListeners();
  }

  String lengthOfTitle() {
    const middleText = ' ⋆⋅𖤓⋅⋆ ';
    final sideCount = title.characters.length + 2;
    final sideText = '-' * (sideCount > 0 ? sideCount : 0);
    return sideText + middleText + sideText;
  }

  String buildMessage() {
    final selectedStaff = _eligibleSelectedStaff;
    final names = selectedStaff.map((s) => s['name'] as String).toList();
    final b = StringBuffer()
      ..writeln('᯽⋆⊱ $title ${kh(_eligibleAttendees.length)} អង្គ ⊰⋆᯽')
      ..writeln(('  ') + lengthOfTitle())
      ..writeln();
    for (var i = 0; i < names.length; i++) {
      final staff = selectedStaff[i];
      b
        ..writeln('${kh(i + 1)}. '
            '${formatStaffName(staff, includeRole: false)}'
            '${directInvites.contains(staff['id']) ? ' (ផ្ទាល់)' : ''}')
        ..writeln();
    }

    if (names.isNotEmpty) {
      b.writeln(lengthOfTitle());
    }

    if (preachDharma && selectedPreachers.isNotEmpty) {
      final preacherNames = selectedPreachers
          .map((x) => formatStaffName(x, includeRole: false))
          .join(' និង ');
      b
        ..writeln('👏 សម្ដែងធម្មទេសនាដោយ ៖ $preacherNames')
        ..writeln();
    }
    if (preceptsType != null && selectedPreceptGivers.isNotEmpty) {
      final preceptsNames = selectedPreceptGivers
          .map((x) => formatStaffName(x, includeRole: false))
          .join(' និង ');
      final preceptsLabel = switch (preceptsType) {
        preceptsNissaya => '👏 ប្រទាននិច្ចសីល',
        preceptsUposatha => '👏 ប្រទានឧបោសថសីល',
        preceptsBoth => '👏 ប្រទាននិច្ចសីល និងឧបោសថសីល',
        _ => '',
      };
      if (preceptsLabel.isNotEmpty) {
        b
          ..writeln('$preceptsLabelដោយ ៖ $preceptsNames')
          ..writeln();
      }
    }
    if (start != null) {
      final t = khTime(start!);
      b
        ..writeln('⏰ ( ម៉ោង : $t )')
        ..writeln();
    }
    if (leaderName != null) {
      b
        ..writeln('👨‍🦳 អាចារ្យ : ( $leaderName )')
        ..writeln();
    }
    if (place != null && place!.isNotEmpty) {
      b
        ..writeln('📍 ទីតាំង : ( $place )')
        ..writeln();
    }
    if (note.trim().isNotEmpty) {
      b
        ..writeln('✏️ បញ្ជាក់: ${note.trim()}')
        ..writeln();
    }
    b
      ..writeln('🗓 ( ${khDateFull(date)} )')
      ..writeln()
      ..writeln('✧⊰⋆ ${khDate(date)} ⋆⊱✧')
      ..write('───⋆⊱༻𖥸༺⊰⋆───');
    return b.toString();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;
  String get _dateStr => DateFormat('yyyy-MM-dd').format(date);

  Future<void> refreshBusyStaffIds() async {
    if (start == null || end == null) {
      busyStaffIds = {};
      notifyListeners();
      return;
    }
    final db = await Db.instance;
    final rows = await db.rawQuery(
      'SELECT DISTINCT staff_id FROM ('
      'SELECT ts.staff_id, h.id AS history_id, h.task_date, h.start_min, h.end_min '
      'FROM task_staff ts JOIN task_history h ON h.id = ts.history_id '
      'UNION ALL '
      'SELECT tp.staff_id, h.id AS history_id, h.task_date, h.start_min, h.end_min '
      'FROM task_preachers tp JOIN task_history h ON h.id = tp.history_id '
      'UNION ALL '
      'SELECT tg.staff_id, h.id AS history_id, h.task_date, h.start_min, h.end_min '
      'FROM task_precept_givers tg JOIN task_history h ON h.id = tg.history_id'
      ') WHERE task_date = ? AND history_id != ? AND staff_id IS NOT NULL '
      'AND start_min < ? AND end_min > ?',
      [_dateStr, editingId ?? -1, _min(end!), _min(start!)],
    );
    busyStaffIds = rows.map((row) => row['staff_id']).whereType<int>().toSet();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> findLeaderConflicts() async {
    if (leaderId == null || start == null || end == null) return [];
    final name = leaderName;
    if (name == null) return [];
    final db = await Db.instance;
    return db.rawQuery(
      'SELECT title, start_min, end_min FROM task_history '
      'WHERE task_date = ? AND id != ? '
      'AND (leader_id = ? OR (leader_id IS NULL AND leader = ?)) '
      'AND start_min IS NOT NULL AND end_min IS NOT NULL '
      'AND start_min < ? AND end_min > ?',
      [
        _dateStr,
        editingId ?? -1,
        leaderId,
        name,
        _min(end!),
        _min(start!),
      ],
    );
  }

  /// រកព្រះសង្ឃដែលបានជ្រើស ដែលមានបុណ្យផ្សេងជាន់ម៉ោងនៅថ្ងៃដូចគ្នា
  Future<List<Map<String, dynamic>>> findConflicts() async {
    final ids = <int>{
      ..._eligibleSelectedStaff.map((x) => x['id']).whereType<int>(),
      ...selectedPreachers.map((x) => x['id']).whereType<int>(),
      ...selectedPreceptGivers.map((x) => x['id']).whereType<int>(),
    }.toList();
    if (start == null || end == null || ids.isEmpty) return [];
    final db = await Db.instance;
    final q = ids.map((_) => '?').join(',');
    return db.rawQuery(
      'SELECT DISTINCT staff_id, staff_name, start_min, end_min, title FROM ('
      'SELECT ts.staff_id, ts.staff_name, h.start_min, h.end_min, h.title, '
      'h.id AS history_id, h.task_date FROM task_staff ts '
      'JOIN task_history h ON h.id = ts.history_id '
      'UNION ALL '
      'SELECT tp.staff_id, tp.staff_name, h.start_min, h.end_min, h.title, '
      'h.id AS history_id, h.task_date FROM task_preachers tp '
      'JOIN task_history h ON h.id = tp.history_id '
      'UNION ALL '
      'SELECT tg.staff_id, tg.staff_name, h.start_min, h.end_min, h.title, '
      'h.id AS history_id, h.task_date FROM task_precept_givers tg '
      'JOIN task_history h ON h.id = tg.history_id'
      ') WHERE task_date = ? AND history_id != ? AND staff_id IN ($q) '
      'AND start_min IS NOT NULL AND end_min IS NOT NULL '
      'AND start_min < ? AND end_min > ?',
      [
        _dateStr,
        editingId ?? -1,
        ...ids,
        _min(end!),
        _min(start!),
      ],
    );
  }

  /// return false បើមានបុណ្យជាន់ម៉ោង (មិនរក្សាទុក)
  Future<bool> copyAndSave() async {
    _sanitizeAssignments();
    if (preachDharma && selectedPreachers.isEmpty) return false;
    if (preceptsType != null && selectedPreceptGivers.isEmpty) {
      return false;
    }
    if ((await findLeaderConflicts()).isNotEmpty) return false;
    if ((await findConflicts()).isNotEmpty) return false;
    final msg = buildMessage();
    await Clipboard.setData(ClipboardData(text: msg));
    final db = await Db.instance;
    final sMin = start == null ? null : _min(start!);
    final eMin = end == null ? null : _min(end!);
    final row = <String, Object?>{
      'title': title,
      'task_date': _dateStr,
      'staff_names': _eligibleAttendees
          .map((x) => (x['name'] ?? '').toString())
          .join(', '),
      'leader': leaderName ?? '',
      'leader_id': leaderId,
      'preach_dharma': preachDharma ? 1 : 0,
      'precepts_type': preceptsType ?? '',
      'place': place ?? '',
      'message': msg,
      'note': note.trim(),
      'start_min': sMin,
      'end_min': eMin,
    };
    final templateId = template?['id'];
    final archiveTemporary = template?['is_temporary'] == 1 &&
        template?['archived'] != 1 &&
        templateId is int;
    await db.transaction((txn) async {
      final int hid;
      if (editingId == null) {
        hid = await txn.insert('task_history',
            {...row, 'created_at': DateTime.now().toIso8601String()});
      } else {
        hid = editingId!;
        await txn
            .update('task_history', row, where: 'id = ?', whereArgs: [hid]);
        await txn
            .delete('task_staff', where: 'history_id = ?', whereArgs: [hid]);
        await txn.delete(
          'task_preachers',
          where: 'history_id = ?',
          whereArgs: [hid],
        );
        await txn.delete(
          'task_precept_givers',
          where: 'history_id = ?',
          whereArgs: [hid],
        );
      }
      for (final x in _eligibleSelectedStaff) {
        await txn.insert('task_staff', {
          'history_id': hid,
          'staff_id': x['id'],
          'staff_name': x['name'],
          'task_date': _dateStr,
          'start_min': sMin,
          'end_min': eMin,
          'direct': directInvites.contains(x['id']) ? 1 : 0,
        });
      }
      for (final x in selectedPreachers) {
        await txn.insert('task_preachers', {
          'history_id': hid,
          'staff_id': x['id'],
          'staff_name': x['name'],
        });
      }
      for (final x in selectedPreceptGivers) {
        await txn.insert('task_precept_givers', {
          'history_id': hid,
          'staff_id': x['id'],
          'staff_name': x['name'],
        });
      }
      if (archiveTemporary) {
        await txn.update(
          'templates',
          {'archived': 1},
          where: 'id = ? AND is_temporary = 1 AND archived = 0',
          whereArgs: [templateId],
        );
      }
    });
    editingId = null;
    await load();
    await NotificationService.instance.rescheduleAll();
    return true;
  }
}
