// SQLite Database (តារាង staff, leaders, places, templates, task_history, task_staff)
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Db {
  static Database? _db;
  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'task_assign.db');
    return openDatabase(path, version: 5, onUpgrade: (d, oldV, newV) async {
      if (oldV < 5) {
        await d.execute('ALTER TABLE templates ADD COLUMN note TEXT');
      }
      if (oldV < 4) {
        await d.execute('ALTER TABLE task_history ADD COLUMN note TEXT');
      }
      if (oldV < 3) {
        await d.execute('ALTER TABLE staff ADD COLUMN age INTEGER');
      }
      if (oldV < 2) {
        await d.execute('ALTER TABLE task_history ADD COLUMN start_min INTEGER');
        await d.execute('ALTER TABLE task_history ADD COLUMN end_min INTEGER');
        await _createTaskStaff(d);
        // បម្លែងប្រវត្តិចាស់ ឱ្យចូលក្នុងស្ថិតិ (មិនមានម៉ោង ដូច្នេះមិនយកមកពិនិត្យការជាន់ពេល)
        final rows = await d.query('task_history');
        for (final h in rows) {
          final names =
              (h['staff_names'] ?? '').toString().split(', ').where((e) => e.isNotEmpty);
          for (final n in names) {
            final m = await d.query('staff', where: 'name = ?', whereArgs: [n], limit: 1);
            await d.insert('task_staff', {
              'history_id': h['id'],
              'staff_id': m.isEmpty ? null : m.first['id'],
              'staff_name': n,
              'task_date': h['task_date'],
            });
          }
        }
      }
    }, onCreate: (d, v) async {
      await d.execute('CREATE TABLE staff('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, role TEXT, phone TEXT, age INTEGER)');
      await d.execute('CREATE TABLE leaders('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      await d.execute('CREATE TABLE places('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      await d.execute('CREATE TABLE templates('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, role TEXT, '
          'start_time TEXT, end_time TEXT, leader_id INTEGER, place TEXT, note TEXT)');
      await d.execute('CREATE TABLE task_history('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, task_date TEXT, '
          'staff_names TEXT, leader TEXT, place TEXT, message TEXT, created_at TEXT, '
          'start_min INTEGER, end_min INTEGER, note TEXT)');
      await _createTaskStaff(d);

      // ទិន្នន័យគំរូ (កែ ឬលុបបានតាមចិត្ត)
      for (final n in ['អាចារ្យ ម៉ៅ', 'មេការ សុខ']) {
        await d.insert('leaders', {'name': n});
      }
      for (final n in ['ទួលគោក', 'ភ្នំពេញថ្មី']) {
        await d.insert('places', {'name': n});
      }
      for (final s in [
        ['វឿន ចាន់ធឿន', 'ដឹកដី'],
        ['ស៊ន សេងអ៊ី', 'ដឹកដី'],
        ['ពេជ្រ សុភា', 'ដឹកដី'],
        ['រស់ រតនា', 'ដឹកដី'],
        ['សាង សល់', 'ដឹកដី'],
        ['សុខ វិចិត្រ', 'ជាង'],
      ]) {
        await d.insert('staff', {'name': s[0], 'role': s[1], 'phone': ''});
      }
      await d.insert('templates', {
        'title': 'ទៅដឹកដី',
        'role': 'ដឹកដី',
        'start_time': '07:00',
        'end_time': '10:00',
        'leader_id': 1,
        'place': 'ទួលគោក',
      });
    });
  }

  static Future<void> _createTaskStaff(Database d) => d.execute('CREATE TABLE task_staff('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, history_id INTEGER, staff_id INTEGER, '
      'staff_name TEXT, task_date TEXT, start_min INTEGER, end_min INTEGER)');

  static Future<void> deleteHistory(int id) async {
    final d = await instance;
    await d.delete('task_staff', where: 'history_id = ?', whereArgs: [id]);
    await d.delete('task_history', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> all(String table, {String? orderBy}) async =>
      (await instance).query(table, orderBy: orderBy ?? 'id');

  static Future<int> insert(String table, Map<String, Object?> v) async =>
      (await instance).insert(table, v);

  static Future<void> update(String table, int id, Map<String, Object?> v) async =>
      (await instance).update(table, v, where: 'id = ?', whereArgs: [id]);

  static Future<void> delete(String table, int id) async =>
      (await instance).delete(table, where: 'id = ?', whereArgs: [id]);
}
