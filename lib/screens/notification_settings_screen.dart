import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/input_styles.dart';
import '../services/notification_service.dart';
import '../widgets/dialogs.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationService.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _leadMinutes = settings.leadMinutes;
      _loading = false;
    });
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
                  title: const Text('បើក Notification'),
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
              ],
            ),
    );
  }
}
