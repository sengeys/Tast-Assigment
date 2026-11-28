import 'package:material_ui/material_ui.dart';

import '../models/reminder_preset.dart';

Future<ReminderPreset?> showReminderPresetEditor(
  BuildContext context, {
  ReminderPreset? preset,
}) {
  final nameController = TextEditingController(text: preset?.name ?? '');
  final minutesController =
      TextEditingController(text: '${preset?.minutesBefore ?? 60}');
  final daysController =
      TextEditingController(text: '${preset?.daysBefore ?? 1}');
  var minuteOffset = preset?.isMinuteOffset ?? false;
  var time = TimeOfDay(
    hour: preset?.hour ?? 19,
    minute: preset?.minute ?? 0,
  );
  var validationMessage = '';

  return showDialog<ReminderPreset>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(preset == null ? 'បង្កើតការរំលឹក' : 'កែការរំលឹក'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ឈ្មោះការរំលឹក',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('មុនម៉ោងចាប់ផ្ដើម'),
                    selected: minuteOffset,
                    onSelected: (_) =>
                        setDialogState(() => minuteOffset = true),
                  ),
                  ChoiceChip(
                    label: const Text('មុនថ្ងៃកម្មវិធី'),
                    selected: !minuteOffset,
                    onSelected: (_) =>
                        setDialogState(() => minuteOffset = false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (minuteOffset)
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ចំនួននាទីមុនម៉ោងចាប់ផ្ដើម',
                    border: OutlineInputBorder(),
                  ),
                )
              else ...[
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ចំនួនថ្ងៃមុនកម្មវិធី',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    'ម៉ោង ${time.hour.toString().padLeft(2, '0')}:'
                    '${time.minute.toString().padLeft(2, '0')}',
                  ),
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: dialogContext,
                      initialTime: time,
                    );
                    if (selected != null) {
                      setDialogState(() => time = selected);
                    }
                  },
                ),
              ],
              if (validationMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationMessage,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('បោះបង់'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final minutes = int.tryParse(minutesController.text.trim());
              final days = int.tryParse(daysController.text.trim());
              if (name.isEmpty) {
                setDialogState(() => validationMessage = 'សូមបញ្ចូលឈ្មោះ');
                return;
              }
              if (minuteOffset && (minutes == null || minutes <= 0)) {
                setDialogState(() =>
                    validationMessage = 'សូមបញ្ចូលចំនួននាទីឱ្យបានត្រឹមត្រូវ');
                return;
              }
              if (minuteOffset && minutes! > 525600) {
                setDialogState(() => validationMessage = 'ចំនួននាទីច្រើនពេក');
                return;
              }
              if (!minuteOffset && (days == null || days < 0 || days > 3650)) {
                setDialogState(() =>
                    validationMessage = 'សូមបញ្ចូលចំនួនថ្ងៃឱ្យបានត្រឹមត្រូវ');
                return;
              }

              Navigator.pop(
                dialogContext,
                ReminderPreset(
                  id: preset?.id ??
                      'custom_${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  minutesBefore: minuteOffset ? minutes : null,
                  daysBefore: minuteOffset ? 1 : days!,
                  hour: time.hour,
                  minute: time.minute,
                  isBuiltIn: preset?.isBuiltIn ?? false,
                ),
              );
            },
            child: const Text('រក្សាទុក'),
          ),
        ],
      ),
    ),
  );
}
