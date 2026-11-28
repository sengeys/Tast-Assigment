import 'package:material_ui/material_ui.dart';

import '../models/reminder_preset.dart';
import '../services/notification_service.dart';
import 'reminder_preset_dialog.dart';

const _createPresetValue = '__create_reminder_preset__';
const useGlobalReminderSetting = '__use_global_reminder_setting__';

Future<String?> showReminderPresetPicker(
  BuildContext context, {
  required String? selectedId,
  bool allowDefault = false,
}) async {
  final presets = await NotificationService.instance.loadReminderPresets();
  if (!context.mounted) return null;
  final selection = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (allowDefault)
            ListTile(
              leading: Icon(
                selectedId == null ? Icons.check : Icons.notifications_none,
              ),
              title: const Text('ការជូនដំណឹងទូទៅ'),
              onTap: () =>
                  Navigator.pop(sheetContext, useGlobalReminderSetting),
            ),
          for (final preset in presets)
            ListTile(
              leading: Icon(
                selectedId == preset.id ? Icons.check : Icons.alarm,
              ),
              title: Text(preset.name),
              subtitle: Text(_scheduleLabel(preset)),
              onTap: () => Navigator.pop(sheetContext, preset.id),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_alarm),
            title: const Text('កំណត់តាមចិត្ត'),
            subtitle: const Text('បង្កើត និងរក្សាទុកការរំលឹកថ្មី'),
            onTap: () => Navigator.pop(sheetContext, _createPresetValue),
          ),
        ],
      ),
    ),
  );

  if (selection == _createPresetValue) {
    if (!context.mounted) return null;
    final preset = await showReminderPresetEditor(context);
    if (preset == null) return null;
    await NotificationService.instance.saveReminderPresets(
      [...presets, preset],
    );
    return preset.id;
  }
  if (selection == useGlobalReminderSetting) return selection;
  return selection;
}

String _scheduleLabel(ReminderPreset preset) {
  if (preset.minutesBefore case final minutes?) {
    return 'មុនម៉ោងចាប់ផ្ដើម $minutes នាទី';
  }
  final time =
      '${preset.hour.toString().padLeft(2, '0')}:${preset.minute.toString().padLeft(2, '0')}';
  return preset.daysBefore == 0
      ? 'ថ្ងៃកម្មវិធី ម៉ោង $time'
      : 'មុន ${preset.daysBefore} ថ្ងៃ ម៉ោង $time';
}
