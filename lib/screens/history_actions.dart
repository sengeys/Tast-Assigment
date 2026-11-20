// មុខងាររួមសម្រាប់ប្រវត្តិការចាត់តាំង: ពិនិត្យផុតម៉ោង, Copy, កែ, លុប
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/khmer.dart';
import '../core/khmer_lunar.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import 'staff_select_screen.dart';

// ---------------- History (Home) ----------------

/// ផុតម៉ោងហើយ? (បើគ្មានម៉ោងបញ្ចប់ ចាត់ទុកថាផុតនៅចុងថ្ងៃនោះ)
bool historyEnded(Map<String, dynamic> h) {
  final d = DateTime.tryParse((h['task_date'] ?? '').toString());
  if (d == null) return true;
  final m = h['end_min'];
  final endAt = m == null
      ? DateTime(d.year, d.month, d.day, 23, 59, 59)
      : DateTime(d.year, d.month, d.day, (m as int) ~/ 60, m % 60);
  return DateTime.now().isAfter(endAt);
}

String historyTimeText(Map<String, dynamic> h) {
  final a = h['start_min'], b = h['end_min'];
  if (a == null) return '';
  String f(int m) => khTime(TimeOfDay(hour: m ~/ 60, minute: m % 60));
  return b == null ? f(a as int) : '${f(a as int)} - ${f(b as int)}';
}

String historyDateText(Map<String, dynamic> h) {
  final d = DateTime.tryParse((h['task_date'] ?? '').toString());
  return d == null ? '' : khDate(d);
}

/// ថ្ងៃទម្រង់ពេញ (មានចន្ទគតិ) សម្រាប់អេក្រង់ព័ត៌មានលម្អិត
String historyDateFullText(Map<String, dynamic> h) {
  final d = DateTime.tryParse((h['task_date'] ?? '').toString());
  return d == null ? '' : khDateFull(d);
}

void copyHistory(BuildContext context, Map<String, dynamic> h) {
  Clipboard.setData(ClipboardData(text: (h['message'] ?? '').toString()));
  showSnack(context, 'បាន Copy សាររួចរាល់ ✔');
}

Future<void> editHistory(BuildContext context, AppState s, Map<String, dynamic> h) async {
  await s.startEdit(h);
  if (context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffSelectScreen()));
  }
}

Future<bool> deleteHistoryConfirm(BuildContext context, AppState s, Map<String, dynamic> h) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('លុប "${h['title']}" ?'),
      content: const Text('ការចាត់ទៅបុណ្យនេះនឹងត្រូវលុបចេញពីប្រវត្តិ និងស្ថិតិ។'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('បោះបង់')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('លុប')),
      ],
    ),
  );
  if (ok != true) return false;
  await Db.deleteHistory(h['id'] as int);
  await NotificationService.instance.rescheduleAll();
  await s.load();
  return true;
}
