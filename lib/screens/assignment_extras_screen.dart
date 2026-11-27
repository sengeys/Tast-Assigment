import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/preaching.dart';
import '../core/roles.dart';
import '../core/statuses.dart';
import '../state/app_state.dart';
import 'preview_screen.dart';

class AssignmentExtrasScreen extends StatelessWidget {
  const AssignmentExtrasScreen({super.key});

  Widget _checkboxContainer(Widget child) {
    final borderRadius = BorderRadius.circular(12);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F9),
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }

  Future<void> _selectMonks(
    BuildContext context,
    AppState state, {
    required String title,
    required Set<int> selectedIds,
    List<Map<String, dynamic>>? availablePeople,
  }) async {
    final candidates = (availablePeople ?? state.staff)
        .where((person) =>
            canAttendWithMonks(person['status']) &&
            !state.busyStaffIds.contains(person['id']))
        .toList();
    final candidateIds =
        candidates.map((person) => person['id'] as int).toSet();
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        final draft = selectedIds.where(candidateIds.contains).toSet();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(dialogContext).size.height * 0.55,
              child: candidates.isEmpty
                  ? const Text('មិនមានព្រះសង្ឃដែលអាចជ្រើសរើសបានទេ')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final person in candidates)
                          _checkboxContainer(
                            CheckboxListTile(
                              value: draft.contains(person['id']),
                              checkboxShape: const CircleBorder(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                formatStaffName(person, includeRole: false),
                              ),
                              onChanged: (value) {
                                final id = person['id'] as int;
                                setDialogState(() {
                                  value == true
                                      ? draft.add(id)
                                      : draft.remove(id);
                                });
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('បោះបង់'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, draft),
                child: const Text('រក្សាទុក'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    state.update(() {
      selectedIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _showSelectionRequiredAlert(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('យល់ព្រម'),
          ),
        ],
      ),
    );
  }

  Future<void> _goPreview(BuildContext context, AppState state) async {
    if (state.directInviteEnabled && state.directInvites.isEmpty) {
      await _showSelectionRequiredAlert(
        context,
        title: 'មិនទាន់បានជ្រើសរើសព្រះសង្ឃនិមន្តផ្ទាល់',
        message: 'សូមជ្រើសរើសព្រះសង្ឃនិមន្តផ្ទាល់សិន',
      );
      return;
    }
    if (state.preachDharma && state.selectedPreachers.isEmpty) {
      await _showSelectionRequiredAlert(
        context,
        title: 'មិនទាន់បានជ្រើសរើសអ្នកសម្ដែងធម្មទេសនា',
        message: 'សូមជ្រើសរើសព្រះសង្ឃសម្រាប់សម្ដែងធម្មទេសនាសិន',
      );
      return;
    }
    if (state.preceptsType != null && state.selectedPreceptGivers.isEmpty) {
      await _showSelectionRequiredAlert(
        context,
        title: 'មិនទាន់បានជ្រើសរើសអ្នកប្រទានសីល',
        message: 'សូមជ្រើសរើសព្រះសង្ឃសម្រាប់ប្រទានសីលសិន',
      );
      return;
    }
    final leaderConflicts = await state.findLeaderConflicts();
    final monkConflicts = await state.findConflicts();
    if (!context.mounted) return;
    if (leaderConflicts.isNotEmpty || monkConflicts.isNotEmpty) {
      String range(Map<String, dynamic> conflict) {
        final start = conflict['start_min'] as int;
        final end = conflict['end_min'] as int;
        return '${khTime(TimeOfDay(hour: start ~/ 60, minute: start % 60))} - '
            '${khTime(TimeOfDay(hour: end ~/ 60, minute: end % 60))}';
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber, color: Colors.orange),
          title: const Text('មានការចាត់ជាន់ពេលគ្នា'),
          content: SingleChildScrollView(
            child: Text([
              for (final conflict in leaderConflicts)
                'អាចារ្យ៖ ${conflict['title']} (${range(conflict)})',
              for (final conflict in monkConflicts)
                'ព្រះសង្ឃ៖ ${conflict['staff_name']} — '
                    '${conflict['title']} (${range(conflict)})',
            ].join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('បិទ'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final preachers = state.selectedPreachers;
    final preceptGivers = state.selectedPreceptGivers;
    final selectedMonks = state.staff
        .where((person) =>
            state.selected.contains(person['id']) &&
            canAttendWithMonks(person['status']))
        .toList();
    final directInvitees = selectedMonks
        .where((person) => state.directInvites.contains(person['id']))
        .toList();
    Widget monkDropdown(String title, List<Map<String, dynamic>> selectedPeople,
        Set<int> selectedIds,
        {List<Map<String, dynamic>>? availablePeople}) {
      final label = selectedPeople.isEmpty
          ? 'ចុចដើម្បីជ្រើសរើស...'
          : selectedPeople
              .map((person) => formatStaffName(person, includeRole: false))
              .join(' និង ');
      return InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: InkWell(
          onTap: () => _selectMonks(
            context,
            state,
            title: title,
            selectedIds: selectedIds,
            availablePeople: availablePeople,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: selectedPeople.isEmpty
                      ? TextStyle(
                          color: Colors.grey.shade600,
                        )
                      : null,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ព្រះសង្ឃដែលមានភារៈកិច្ចបន្ថែម'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _checkboxContainer(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: state.preachDharma,
                  checkboxShape: const CircleBorder(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text('សម្ដែងធម្មទេសនា'),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'សូមចុច '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.check_circle_outline_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text: ' ដើម្បីជ្រើសរើសព្រះសង្ឃសម្ដែងធម្មទេសនា',
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) => state.update(() {
                    state.preachDharma = value ?? false;
                    if (!state.preachDharma) state.preacherIds.clear();
                  }),
                ),
                if (state.preachDharma)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        monkDropdown(
                          'ជ្រើសរើសអ្នកសម្ដែងធម្មទេសនា',
                          preachers,
                          state.preacherIds,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'អាចជ្រើសរើសព្រះសង្ឃដែលមិនមានក្នុងបញ្ជីចាត់តាំងបានផងដែរ។',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _checkboxContainer(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: state.preceptsType != null,
                  checkboxShape: const CircleBorder(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text('ប្រទានសីល'),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'សូមចុច '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.check_circle_outline_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text: ' ដើម្បីជ្រើសរើសព្រះសង្ឃប្រទានសីល',
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) => state.update(() {
                    state.preceptsType =
                        value == true ? preceptsTypes.first : null;
                    if (state.preceptsType == null) {
                      state.preceptGiverIds.clear();
                    }
                  }),
                ),
                if (state.preceptsType != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ប្រភេទសីល',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final (value, label) in [
                              (preceptsNissaya, 'ប្រទាននិច្ចសីល'),
                              (preceptsUposatha, 'ប្រទានឧបោសថសីល'),
                              (preceptsBoth, 'ប្រទាននិច្ចសីល និងឧបោសថសីល'),
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: state.preceptsType == value,
                                onSelected: (_) => state
                                    .update(() => state.preceptsType = value),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        monkDropdown(
                          'ជ្រើសរើសអ្នកប្រទានសីល',
                          preceptGivers,
                          state.preceptGiverIds,
                          availablePeople: selectedMonks,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _checkboxContainer(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: state.directInviteEnabled,
                  checkboxShape: const CircleBorder(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text('និមន្តផ្ទាល់'),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'សូមចុច '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.check_circle_outline_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text: ' ដើម្បីជ្រើសរើសព្រះសង្ឃនិមន្តផ្ទាល់',
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) async {
                    if (value == true && selectedMonks.isEmpty) {
                      await showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          icon: const Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                          ),
                          title: const Text('មិនទាន់បានជ្រើសរើសព្រះសង្ឃ'),
                          content: const Text(
                            'សូមជ្រើសរើសព្រះសង្ឃនៅជំហានមុនសិន',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('យល់ព្រម'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    state.update(() {
                      state.directInviteEnabled = value ?? false;
                      if (!state.directInviteEnabled) {
                        state.directInvites.clear();
                      }
                    });
                  },
                ),
                if (state.directInviteEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedMonks.isEmpty)
                          const Text('សូមជ្រើសរើសព្រះសង្ឃនៅជំហានមុនសិន')
                        else
                          monkDropdown(
                            'ជ្រើសរើសព្រះសង្ឃនិមន្តផ្ទាល់',
                            directInvitees,
                            state.directInvites,
                            availablePeople: selectedMonks,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'អាចជ្រើសរើសតែព្រះសង្ឃដែលបានចាត់ចែងតែប៉ុណ្ណោះ។',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.preview),
            label: const Text('មើលសារ'),
            onPressed: () => _goPreview(context, state),
          ),
        ],
      ),
    );
  }
}
