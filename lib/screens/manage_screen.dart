// អេក្រង់គ្រប់គ្រងទិន្នន័យ: បុគ្គលិក អ្នកដឹកនាំ ទីតាំង
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/roles.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget section(String title, String table, List<Map<String, dynamic>> rows,
        {bool withRole = false}) {
      // បញ្ជីតួនាទីតាមលំដាប់ + តួនាទីចាស់ណាដែលមានក្នុងបុគ្គលិកស្រាប់ តែមិនមានក្នុង roleOrder
      final roleOptions = [
        ...roleOrder,
        ...s.roles.where((x) => !roleOrder.contains(x))
      ];

      Future<void> edit(Map<String, dynamic> r) async {
        final v = await recordDialog(context, 'កែប្រែ$title',
            name: r['name'] ?? '',
            role: r['role'] ?? '',
            phone: r['phone'] ?? '',
            age: r['age']?.toString() ?? '',
            roleOptions: roleOptions,
            isStaff: withRole);
        if (v == null) return;
        await Db.update(table, r['id'], {
          'name': v['name'],
          if (withRole) 'role': v['role'],
          if (withRole) 'phone': v['phone'],
          if (withRole) 'age': int.tryParse(v['age'] ?? ''),
        });
        s.load();
      }

      return ExpansionTile(
        title: Text('$title (${kh(rows.length)})'),
        children: [
          for (final r in rows)
            ListTile(
              title: Text(r['name']),
              subtitle: withRole
                  ? Text([
                      r['role'],
                      if (r['age'] != null) 'អាយុ ${kh(r['age'])} ឆ្នាំ',
                      r['phone']
                    ]
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(' • '))
                  : null,
              onTap: () => edit(r),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => edit(r)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('លុប "${r['name']}" ?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('បោះបង់')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('លុប')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await Db.delete(table, r['id']);
                      s.load();
                    },
                  ),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('បន្ថែម'),
            onTap: () async {
              final v = await recordDialog(context, 'បន្ថែម$title',
                  roleOptions: roleOptions, isStaff: withRole);
              if (v == null) return;
              await Db.insert(table, {
                'name': v['name'],
                if (withRole) 'role': v['role'],
                if (withRole) 'phone': v['phone'],
                if (withRole) 'age': int.tryParse(v['age'] ?? ''),
              });
              s.load();
            },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('គ្រប់គ្រងទិន្នន័យ')),
      body: ListView(children: [
        section('ព្រះសង្ឃ', 'staff', s.staff, withRole: true),
        section('អាចារ្យ', 'leaders', s.leaders),
        section('ទីតាំង', 'places', s.places),
      ]),
    );
  }
}
