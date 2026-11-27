// SQLite Database (តារាង staff, leaders, places, templates, task_history, task_staff)
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/vassa.dart';

class Db {
  static Database? _db;
  static const _lastVassaUpdateKey = 'last_vassa_update_year';
  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'task_assign.db');
    return openDatabase(path, version: 13, onUpgrade: (d, oldV, newV) async {
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
        await d
            .execute('ALTER TABLE task_history ADD COLUMN start_min INTEGER');
        await d.execute('ALTER TABLE task_history ADD COLUMN end_min INTEGER');
        await _createTaskStaff(d);
        // បម្លែងប្រវត្តិចាស់ ឱ្យចូលក្នុងស្ថិតិ (មិនមានម៉ោង ដូច្នេះមិនយកមកពិនិត្យការជាន់ពេល)
        final rows = await d.query('task_history');
        for (final h in rows) {
          final names = (h['staff_names'] ?? '')
              .toString()
              .split(', ')
              .where((e) => e.isNotEmpty);
          for (final n in names) {
            final m = await d.query('staff',
                where: 'name = ?', whereArgs: [n], limit: 1);
            await d.insert('task_staff', {
              'history_id': h['id'],
              'staff_id': m.isEmpty ? null : m.first['id'],
              'staff_name': n,
              'task_date': h['task_date'],
            });
          }
        }
      }
      if (oldV >= 2 && oldV < 6) {
        await d.execute(
            'ALTER TABLE task_staff ADD COLUMN direct INTEGER NOT NULL DEFAULT 0');
      }
      if (oldV < 7) {
        await d.execute(
            'ALTER TABLE templates ADD COLUMN is_temporary INTEGER NOT NULL DEFAULT 0');
        await d.execute(
            'ALTER TABLE templates ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      }
      if (oldV < 8) {
        await d.execute('ALTER TABLE templates ADD COLUMN task_date TEXT');
      }
      if (oldV < 9) {
        await d.execute(
            "ALTER TABLE staff ADD COLUMN status TEXT NOT NULL DEFAULT 'នៅវត្ត'");
        await d.execute(
            "ALTER TABLE leaders ADD COLUMN status TEXT NOT NULL DEFAULT 'អាចធ្វើបាន'");
      }
      if (oldV < 10) {
        await d
            .execute('ALTER TABLE task_history ADD COLUMN leader_id INTEGER');
        await _createTaskPreachers(d);
      }
      if (oldV < 11) {
        await d.execute(
            'ALTER TABLE task_history ADD COLUMN preach_dharma INTEGER NOT NULL DEFAULT 0');
        await d.execute(
            "ALTER TABLE task_history ADD COLUMN precepts_type TEXT NOT NULL DEFAULT ''");
        await d.execute('UPDATE task_history SET preach_dharma = 1 WHERE id IN '
            '(SELECT history_id FROM task_preachers)');
      }
      if (oldV < 12) {
        await _createTaskPreceptGivers(d);
        await d.execute(
          'INSERT OR IGNORE INTO task_precept_givers '
          '(history_id, staff_id, staff_name) '
          'SELECT p.history_id, p.staff_id, p.staff_name FROM task_preachers p '
          'JOIN task_history h ON h.id = p.history_id '
          "WHERE h.precepts_type != ''",
        );
      }
      if (oldV < 13) {
        await d.execute('ALTER TABLE staff ADD COLUMN ordination_date TEXT');
        await d.execute(
          'CREATE TABLE app_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      }
    }, onCreate: (d, v) async {
      await d.execute('CREATE TABLE staff('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, role TEXT, phone TEXT, age INTEGER, ordination_date TEXT, '
          "status TEXT NOT NULL DEFAULT 'នៅវត្ត')");
      await d.execute(
        'CREATE TABLE app_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await d.execute('CREATE TABLE leaders('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
          "status TEXT NOT NULL DEFAULT 'អាចធ្វើបាន')");
      await d.execute('CREATE TABLE places('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      await d.execute('CREATE TABLE templates('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, role TEXT, '
          'start_time TEXT, end_time TEXT, leader_id INTEGER, place TEXT, note TEXT, '
          'is_temporary INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0, '
          'task_date TEXT)');
      await d.execute('CREATE TABLE task_history('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, task_date TEXT, '
          'staff_names TEXT, leader TEXT, place TEXT, message TEXT, created_at TEXT, '
          'start_min INTEGER, end_min INTEGER, note TEXT, leader_id INTEGER, '
          "preach_dharma INTEGER NOT NULL DEFAULT 0, precepts_type TEXT NOT NULL DEFAULT '')");
      await _createTaskStaff(d);
      await _createTaskPreachers(d);
      await _createTaskPreceptGivers(d);

      // ទិន្នន័យគំរូ (កែ ឬលុបបានតាមចិត្ត)
      for (final n in ['អាចារ្យ ម៉ៅ', 'អាចារ្យ ហូ']) {
        await d.insert('leaders', {'name': n});
      }
      for (final n in ['សូភី១', 'រំចេក៣']) {
        await d.insert('places', {'name': n});
      }
      for (final s in [
        ['នៅ យូឡុង', 'ចៅអធិការ'],
        ['វឿន ចាន់ធឿន', 'វិន័យធរ'],
        ['ស៊ន សេងអ៊ី', 'គ្រូសូត្រស្ដាំ'],
        ['ពេជ្រ សុភា', 'គ្រូសូត្រឆ្វេង'],
        ['ហេង ប៊ុនហៀង', 'គ្រូសូត្រឆ្វេង'],
        ['សាង សល់', 'ភត្តុទ្ទេសកៈ'],
        ['រស់ រតនា', 'ភិក្ខុ'],
      ]) {
        await d.insert('staff', {'name': s[0], 'role': s[1], 'phone': ''});
      }
      await d.insert('templates', {
        'title': 'សង្ឃទាន',
        'role': 'វិន័យធរ',
        'start_time': '07:00',
        'end_time': '10:00',
        'leader_id': 1,
        'place': 'រំចេក៣',
      });
    });
  }

  static Future<void> _createTaskStaff(Database d) => d.execute(
      'CREATE TABLE task_staff('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, history_id INTEGER, staff_id INTEGER, '
      'staff_name TEXT, task_date TEXT, start_min INTEGER, end_min INTEGER, '
      'direct INTEGER NOT NULL DEFAULT 0)');

  static Future<void> _createTaskPreachers(Database d) =>
      d.execute('CREATE TABLE task_preachers('
          'history_id INTEGER NOT NULL, staff_id INTEGER NOT NULL, '
          'staff_name TEXT NOT NULL, PRIMARY KEY(history_id, staff_id))');

  static Future<void> _createTaskPreceptGivers(Database d) =>
      d.execute('CREATE TABLE task_precept_givers('
          'history_id INTEGER NOT NULL, staff_id INTEGER NOT NULL, '
          'staff_name TEXT NOT NULL, PRIMARY KEY(history_id, staff_id))');

  static Future<void> deleteHistory(int id) async {
    final d = await instance;
    await d.delete('task_staff', where: 'history_id = ?', whereArgs: [id]);
    await d.delete('task_preachers', where: 'history_id = ?', whereArgs: [id]);
    await d.delete('task_precept_givers',
        where: 'history_id = ?', whereArgs: [id]);
    await d.delete('task_history', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> all(String table,
          {String? orderBy}) async =>
      (await instance).query(table, orderBy: orderBy ?? 'id');

  static Future<int> insert(String table, Map<String, Object?> v) async =>
      (await instance).insert(table, v);

  static Future<void> applyAnnualVassaUpdate({DateTime? now}) async {
    final todayValue = now ?? DateTime.now();
    final today = DateTime(todayValue.year, todayValue.month, todayValue.day);
    final database = await instance;
    await database.transaction((transaction) async {
      final metadata = await transaction.query(
        'app_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_lastVassaUpdateKey],
        limit: 1,
      );
      final lastProcessedYear = metadata.isEmpty
          ? null
          : int.tryParse((metadata.first['value'] ?? '').toString());
      final firstYear =
          lastProcessedYear == null ? today.year : lastProcessedYear + 1;

      final staff = (await transaction.query('staff'))
          .map((record) => Map<String, Object?>.from(record))
          .toList();
      final recalculatedIds = <int>{};
      for (final record in staff) {
        if (isVassaExcludedStatus(record['status'])) continue;
        final id = record['id'];
        if (id is! int) continue;

        final updatedAge = completedVassaCount(
          ordinationDate: record['ordination_date'],
          throughDate: today,
        );
        if (updatedAge == null) continue;

        final currentAge = int.tryParse((record['age'] ?? '').toString()) ?? 0;
        if (currentAge != updatedAge) {
          await transaction.update(
            'staff',
            {'age': updatedAge},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        record['age'] = updatedAge;
        recalculatedIds.add(id);
      }

      int? processedYear;
      for (var year = firstYear; year <= today.year; year++) {
        final incrementDate = vassaIncrementDateForYear(year);
        final vassaStartDate = vassaStartDateForYear(year);
        if (incrementDate == null || vassaStartDate == null) break;
        if (today.isBefore(incrementDate)) break;

        for (final record in staff) {
          final id = record['id'];
          if (id is! int || recalculatedIds.contains(id)) continue;
          if (!shouldIncrementVassa(
            status: record['status'],
            ordinationDate: record['ordination_date'],
            vassaStartDate: vassaStartDate,
          )) {
            continue;
          }
          final currentAge =
              int.tryParse((record['age'] ?? '').toString()) ?? 0;
          final updatedAge = currentAge + 1;
          await transaction.update(
            'staff',
            {'age': updatedAge},
            where: 'id = ?',
            whereArgs: [id],
          );
          record['age'] = updatedAge;
        }
        processedYear = year;
      }

      if (processedYear != null) {
        await transaction.insert(
          'app_meta',
          {
            'key': _lastVassaUpdateKey,
            'value': processedYear.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> update(
          String table, int id, Map<String, Object?> v) async =>
      (await instance).update(table, v, where: 'id = ?', whereArgs: [id]);

  static Future<void> delete(String table, int id) async =>
      (await instance).delete(table, where: 'id = ?', whereArgs: [id]);
}
