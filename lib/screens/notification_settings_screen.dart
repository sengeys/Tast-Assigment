import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/reminder_preset.dart';
import '../core/input_styles.dart';
import '../services/notification_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/reminder_preset_dialog.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  int _leadMinutes = 15;
  List<ReminderPreset> _presets = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationService.instance.loadSettings();
    final presets = await NotificationService.instance.loadReminderPresets();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _leadMinutes = settings.leadMinutes;
      _presets = presets;
      _loading = false;
    });
  }

  Future<void> _editPreset([ReminderPreset? preset]) async {
    final updated = await showReminderPresetEditor(context, preset: preset);
    if (updated == null) return;
    final presets = [
      for (final existing in _presets)
        if (existing.id != updated.id) existing,
      updated,
    ];
    await NotificationService.instance.saveReminderPresets(presets);
    if (mounted) setState(() => _presets = presets);
  }

  Future<void> _deletePreset(ReminderPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('លុបការរំលឹក "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('បោះបង់'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('លុប'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationService.instance.deleteReminderPreset(preset.id);
    if (mounted) {
      setState(() => _presets =
          _presets.where((existing) => existing.id != preset.id).toList());
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _saving = true);
    try {
      NotificationPermissionResult? permission;
      if (enabled) {
        permission = await NotificationService.instance.requestPermissions();
        if (!permission.notificationsGranted) {
          if (mounted) {
            showSnack(context,
                'សូមអនុញ្ញាត Notification ក្នុង Settings របស់ទូរស័ព្ទ');
          }
          return;
        }
      }

      await NotificationService.instance.saveSettings(
        ReminderSettings(enabled: enabled, leadMinutes: _leadMinutes),
      );
      if (!mounted) return;
      setState(() => _enabled = enabled);

      if (permission?.exactAlarmsGranted == false) {
        showSnack(context,
            'មិនទាន់អនុញ្ញាត Exact alarm; Notification អាចមកយឺតជាងម៉ោងកំណត់');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLeadMinutes(int minutes) async {
    setState(() => _saving = true);
    try {
      await NotificationService.instance.saveSettings(
        ReminderSettings(enabled: _enabled, leadMinutes: minutes),
      );
      if (mounted) setState(() => _leadMinutes = minutes);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _leadLabel(int minutes) =>
      minutes == 0 ? 'តែពេលដល់ម៉ោង' : 'មុន $minutes នាទី';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ការកំណត់ Notification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('បើកការជូនដំណឹងទូទៅ'),
                  subtitle: const Text('ជូនដំណឹងមុនពេលចាប់ផ្ដើម និងពេលដល់ម៉ោង'),
                  value: _enabled,
                  onChanged: _saving ? null : _setEnabled,
                ),
                if (_enabled) ...[
                  const SizedBox(height: 12),
                  AppDropdownButtonFormField<int>(
                    initialValue: _leadMinutes,
                    decoration: const InputDecoration(
                      labelText: 'រំលឹកមុនម៉ោង',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final minutes in [0, 5, 10, 15, 30, 60])
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(_leadLabel(minutes)),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (minutes) {
                            if (minutes != null) {
                              unawaited(_setLeadMinutes(minutes));
                            }
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _leadMinutes == 0
                        ? 'នឹងទទួល Notification តែពេលដល់ម៉ោងចាប់ផ្ដើមប៉ុណ្ណោះ។'
                        : 'នឹងទទួល Notification មុន $_leadMinutes នាទី និងម្ដងទៀតពេលដល់ម៉ោងចាប់ផ្ដើម។',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('បញ្ជីម៉ោងរំលឹក'),
                  subtitle: const Text(
                    'គំរូបណ្ដោះអាសន្នរំលឹកល្ងាចម៉ោង ៧។ បើហួសម៉ោងនេះ '
                    'កម្មវិធីព្រឹករំលឹកមុន ១ ម៉ោង ហើយកម្មវិធីល្ងាចរំលឹកម៉ោង ៦ ព្រឹក។ '
                    'អាចជ្រើសម៉ោងទាំងនេះសម្រាប់គំរូ និងកម្មវិធីបាន។',
                  ),
                  trailing: IconButton(
                    tooltip: 'បង្កើតការរំលឹក',
                    onPressed: () => _editPreset(),
                    icon: const Icon(Icons.add),
                  ),
                ),
                for (final preset in _presets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm),
                    title: Text(preset.name),
                    subtitle: Text(_presetDescription(preset)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          _editPreset(preset);
                        } else {
                          _deletePreset(preset);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('កែប្រែ'),
                        ),
                        if (!preset.isBuiltIn)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('លុប'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _presetDescription(ReminderPreset preset) {
    if (preset.minutesBefore case final minutes?) {
      return 'មុនម៉ោងចាប់ផ្ដើម $minutes នាទី';
    }
    final time =
        '${preset.hour.toString().padLeft(2, '0')}:${preset.minute.toString().padLeft(2, '0')}';
    return preset.daysBefore == 0
        ? 'ថ្ងៃកម្មវិធី ម៉ោង $time'
        : 'មុន ${preset.daysBefore} ថ្ងៃ ម៉ោង $time';
  }
}
