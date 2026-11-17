// State ទូទៅរបស់ App (Provider): ទិន្នន័យ, Draft ការចាត់តាំង, សារ, ការពិនិត្យជាន់ម៉ោង
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/khmer.dart';
import '../core/khmer_lunar.dart';
import '../core/roles.dart';
import '../data/db.dart';

class AppState extends ChangeNotifier {
  List<Map<String, dynamic>> staff = [], leaders = [], templates = [], places = [], history = [];

  // current task draft
  Map<String, dynamic>? template;
  String title = '';
  String note = ''; // បញ្ជាក់
  final Set<int> selected = {};
  DateTime date = DateTime.now();
  TimeOfDay? start, end;
  int? leaderId;
  String? place;

  Future<void> load() async {
    staff = List.of(await Db.all('staff'))..sort(compareStaff);
    leaders = await Db.all('leaders');
    templates = await Db.all('templates');
    places = await Db.all('places');
    history = await Db.all('task_history', orderBy: 'task_date DESC, start_min DESC, id DESC');
    notifyListeners();
  }

  int? editingId; // មានតម្លៃ = កំពុងកែប្រវត្តិការចាត់តាំងមួយ

  /// ផ្ទុកទិន្នន័យការចាត់តាំងចាស់ ចូលក្នុង Form ដើម្បីកែប្រែ
  Future<void> startEdit(Map<String, dynamic> h) async {
    final db = await Db.instance;
    final rows = await db.query('task_staff', where: 'history_id = ?', whereArgs: [h['id']]);
    editingId = h['id'] as int;
    template = null;
    title = (h['title'] ?? '').toString();
    note = (h['note'] ?? '').toString();
    selected
      ..clear()
      ..addAll(rows.map((r) => r['staff_id']).whereType<int>());
    date = DateTime.tryParse((h['task_date'] ?? '').toString()) ?? DateTime.now();
    TimeOfDay? t(Object? m) =>
        m == null ? null : TimeOfDay(hour: (m as int) ~/ 60, minute: m % 60);
    start = t(h['start_min']);
    end = t(h['end_min']);
    leaderId = null;
    final ln = (h['leader'] ?? '').toString();
    for (final l in leaders) {
      if (l['name'] == ln) leaderId = l['id'] as int;
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
    date = DateTime.now();
    start = parseTime(t?['start_time']);
    end = parseTime(t?['end_time']);
    leaderId = t?['leader_id'];
    place = t?['place'];
    notifyListeners();
  }

  /// រក្សាទុកការចាត់តាំងបច្ចុប្បន្ន ជាគំរូថ្មី (ព័ត៌មានពេញលេញ)
  Future<void> saveAsTemplate(String name) async {
    final roleSet = staff
        .where((x) => selected.contains(x['id']))
        .map((x) => (x['role'] ?? '').toString())
        .where((r) => r.isNotEmpty)
        .toSet();
    final role = roleSet.length == 1 ? roleSet.first : (template?['role'] ?? '').toString();
    await Db.insert('templates', {
      'title': name,
      'role': role,
      'start_time': fmtTime(start),
      'end_time': fmtTime(end),
      'leader_id': leaderId,
      'place': place ?? '',
      'note': note.trim(),
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

  List<String> get selectedNames =>
      staff.where((s) => selected.contains(s['id'])).map((s) => s['name'] as String).toList();

  String? get leaderName {
    for (final l in leaders) {
      if (l['id'] == leaderId) return l['name'];
    }
    return null;
  }

  void toggle(int id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void update(void Function() f) {
    f();
    notifyListeners();
  }

  
  
String lengthOfTitle() {
  final names = selectedNames;

  String middleText = ' ⋆⋅𖤓⋅⋆ ';
  
  String sideText = '─' * (names.length - 2);
  String combinedText = sideText + middleText + sideText;

  return combinedText;
}



  String buildMessage() {
    final names = selectedNames;
    final b = StringBuffer()
      ..writeln('᯽⋆⊱ $title ${kh(names.length)} អង្គ ⊰⋆᯽')
      ..writeln(lengthOfTitle())
      ..writeln();
    for (var i = 0; i < names.length; i++) {
      b
        ..writeln('${kh(i + 1)}. ${names[i]}')
        ..writeln();
    }
    if (start != null) {
      final t = khTime(start!);
      b
        ..writeln(lengthOfTitle())
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
      ..write('───⋆⊱༻𖥸༺⊰⋆───');
    return b.toString();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;
  String get _dateStr => DateFormat('yyyy-MM-dd').format(date);

  /// រកព្រះសង្ឃដែលបានជ្រើស ដែលមានបុណ្យផ្សេងជាន់ម៉ោងនៅថ្ងៃដូចគ្នា
  Future<List<Map<String, dynamic>>> findConflicts() async {
    if (start == null || end == null || selected.isEmpty) return [];
    final db = await Db.instance;
    final ids = selected.toList();
    final q = ids.map((_) => '?').join(',');
    final rows = await db.rawQuery(
        'SELECT ts.staff_id, ts.staff_name, ts.start_min, ts.end_min, h.title '
        'FROM task_staff ts JOIN task_history h ON h.id = ts.history_id '
        'WHERE ts.task_date = ? AND ts.history_id != ? AND ts.staff_id IN ($q) '
        'AND ts.start_min IS NOT NULL AND ts.end_min IS NOT NULL',
        [_dateStr, editingId ?? -1, ...ids]);
    final a = _min(start!), b = _min(end!);
    return rows.where((r) => a < (r['end_min'] as int) && (r['start_min'] as int) < b).toList();
  }

  /// return false បើមានបុណ្យជាន់ម៉ោង (មិនរក្សាទុក)
  Future<bool> copyAndSave() async {
    if ((await findConflicts()).isNotEmpty) return false;
    final msg = buildMessage();
    await Clipboard.setData(ClipboardData(text: msg));
    final db = await Db.instance;
    final sMin = start == null ? null : _min(start!);
    final eMin = end == null ? null : _min(end!);
    final row = <String, Object?>{
      'title': title,
      'task_date': _dateStr,
      'staff_names': selectedNames.join(', '),
      'leader': leaderName ?? '',
      'place': place ?? '',
      'message': msg,
      'note': note.trim(),
      'start_min': sMin,
      'end_min': eMin,
    };
    final int hid;
    if (editingId == null) {
      hid = await db.insert('task_history', {...row, 'created_at': DateTime.now().toIso8601String()});
    } else {
      hid = editingId!;
      await db.update('task_history', row, where: 'id = ?', whereArgs: [hid]);
      await db.delete('task_staff', where: 'history_id = ?', whereArgs: [hid]);
    }
    editingId = null;
    for (final x in staff.where((x) => selected.contains(x['id']))) {
      await db.insert('task_staff', {
        'history_id': hid,
        'staff_id': x['id'],
        'staff_name': x['name'],
        'task_date': _dateStr,
        'start_min': sMin,
        'end_min': eMin,
      });
    }
    await load();
    return true;
  }
}
