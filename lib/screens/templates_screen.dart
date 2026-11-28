// អេក្រង់គំរូការងារ និងអេក្រង់បង្កើត/កែគំរូ
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/khmer_lunar.dart';
import '../core/input_styles.dart';
import '../core/roles.dart';
import '../core/statuses.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/reminder_preset_picker.dart';
import 'details_screen.dart';

enum TemplateFilter { temporary, permanent, archived }

enum _TemplateCreationChoice { blank }

enum _TemplateAction { use, edit, reminder, delete, select }

// ---------------- 1. Templates (គំរូការងារ) ----------------
List<String> roleOptionsOf(AppState s) =>
    [...roleOrder, ...s.roles.where((x) => !roleOrder.contains(x))];

List<Map<String, dynamic>> _newestFirstTemplates(
  Iterable<Map<String, dynamic>> templates,
) =>
    templates.toList()
      ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  TemplateFilter filter = TemplateFilter.temporary;
  final Set<int> _selectedTemplateIds = {};
  bool _selectionMode = false;

  void _toggleTemplateSelection(Map<String, dynamic> template) {
    final id = template['id'] as int;
    setState(() {
      _selectionMode = true;
      if (!_selectedTemplateIds.add(id)) _selectedTemplateIds.remove(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedTemplateIds.clear();
    });
  }

  void _useTemplate(AppState state, Map<String, dynamic> template) {
    state.startFromTemplate(template);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetailsScreen()),
    );
  }

  void _editTemplate(Map<String, dynamic> template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditScreen(template: template),
      ),
    );
  }

  Future<void> _showTemplateActions(
    AppState state,
    Map<String, dynamic> template,
  ) async {
    final archived = template['archived'] == 1;
    final action = await showModalBottomSheet<_TemplateAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                (template['title'] ?? '').toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!archived)
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('ប្រើគំរូ'),
                onTap: () => Navigator.pop(sheetContext, _TemplateAction.use),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('កែគំរូ'),
              onTap: () => Navigator.pop(sheetContext, _TemplateAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('កំណត់ការរំលឹក'),
              onTap: () =>
                  Navigator.pop(sheetContext, _TemplateAction.reminder),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('លុបគំរូ'),
              onTap: () => Navigator.pop(sheetContext, _TemplateAction.delete),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('ជ្រើសរើស'),
              onTap: () => Navigator.pop(sheetContext, _TemplateAction.select),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TemplateAction.use:
        _useTemplate(state, template);
      case _TemplateAction.edit:
        _editTemplate(template);
      case _TemplateAction.reminder:
        await _setTemplateReminder(state, template);
      case _TemplateAction.delete:
        await _deleteTemplates(state, {template['id'] as int},
            templateTitle: (template['title'] ?? '').toString());
      case _TemplateAction.select:
        _toggleTemplateSelection(template);
    }
  }

  Future<void> _setTemplateReminder(
    AppState state,
    Map<String, dynamic> template,
  ) async {
    final id = template['id'] as int;
    final selectedId = await showReminderPresetPicker(
      context,
      selectedId: (template['reminder_preset_id'] ?? 'evening').toString(),
    );
    if (!mounted || selectedId == null) return;

    final date = DateTime.tryParse((template['task_date'] ?? '').toString());
    final start = (template['start_time'] ?? '').toString().split(':');
    final startHour = start.length == 2 ? int.tryParse(start[0]) : null;
    final startMinute = start.length == 2 ? int.tryParse(start[1]) : null;
    final preset = (await NotificationService.instance.loadReminderPresets())
        .where((item) => item.id == selectedId)
        .firstOrNull;
    if (!mounted) return;
    if (date != null &&
        startHour != null &&
        startMinute != null &&
        preset != null) {
      final eventAt =
          DateTime(date.year, date.month, date.day, startHour, startMinute);
      if (!preset.scheduledAt(eventAt).isBefore(eventAt)) {
        showSnack(context, 'ពេលរំលឹកត្រូវតែមុនម៉ោងចាប់ផ្ដើមកម្មវិធី');
        return;
      }
    }

    await Db.update('templates', id, {'reminder_preset_id': selectedId});
    await state.load();
    await NotificationService.instance.rescheduleAll();
  }

  Future<void> _deleteTemplates(
    AppState state,
    Set<int> ids, {
    String? templateTitle,
  }) async {
    if (ids.isEmpty) return;
    final title = templateTitle == null
        ? 'លុប ${kh(ids.length)} គំរូដែលបានជ្រើសរើស?'
        : 'លុបគំរូ "$templateTitle" ?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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

    final database = await Db.instance;
    await database.transaction((transaction) async {
      for (final id in ids) {
        await transaction.delete(
          'templates',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    if (mounted) _cancelSelection();
    await state.load();
    await NotificationService.instance.rescheduleAll();
  }

  String _templateSubtitle(
    AppState state,
    Map<String, dynamic> template,
  ) {
    String? leaderName;
    for (final leader in state.leaders) {
      if (leader['id'] == template['leader_id']) {
        leaderName = (leader['name'] ?? '').toString().trim();
        break;
      }
    }

    final details = <String>[
      if (leaderName != null && leaderName.isNotEmpty) 'អាចារ្យ: $leaderName',
      if ((template['place'] ?? '').toString().trim().isNotEmpty)
        'ទីតាំង: ${template['place']}',
      if ((template['note'] ?? '').toString().trim().isNotEmpty)
        'បញ្ជាក់: ${template['note']}',
    ];
    return details.isEmpty
        ? 'មិនទាន់មានព័ត៌មានគ្រប់គ្រាន់'
        : details.join(' • ');
  }

  Future<void> _createTemplate(AppState state) async {
    final permanentTemplates = _newestFirstTemplates(
      state.templates.where((template) =>
          template['is_temporary'] != 1 && template['archived'] != 1),
    );
    Widget pickerTile({
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      bool showArrow = true,
    }) {
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(
              title,
              style: const TextStyle(color: Color(0xFF757575)),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: showArrow
                ? const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF757575),
                  )
                : null,
            onTap: onTap,
          ),
        ),
      );
    }

    final selection = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('បង្កើតគំរូថ្មី'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (permanentTemplates.isEmpty)
                pickerTile(
                  icon: Icons.assignment_outlined,
                  title: 'មិនទាន់មានគំរូអចិន្ត្រៃយ៍',
                  onTap: null,
                  showArrow: false,
                )
              else
                for (final template in permanentTemplates)
                  pickerTile(
                    icon: Icons.copy_outlined,
                    title: (template['title'] ?? '').toString(),
                    subtitle: _templateSubtitle(state, template),
                    onTap: () => Navigator.pop(dialogContext, template),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('បិទ'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              _TemplateCreationChoice.blank,
            ),
            icon: const Icon(Icons.add),
            label: const Text('បង្កើតថ្មីសុទ្ធ'),
          ),
        ],
      ),
    );
    if (!mounted || selection == null) return;

    final Widget templateScreen;
    if (selection == _TemplateCreationChoice.blank) {
      templateScreen = const TemplateEditScreen();
    } else if (selection is Map<String, dynamic>) {
      templateScreen = TemplateEditScreen(copyFrom: selection);
    } else {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => templateScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final visibleTemplates = _newestFirstTemplates(
      s.templates.where((t) {
        final archived = t['archived'] == 1;
        final temporary = t['is_temporary'] == 1;
        switch (filter) {
          case TemplateFilter.temporary:
            return temporary && !archived;
          case TemplateFilter.permanent:
            return !temporary && !archived;
          case TemplateFilter.archived:
            return archived;
        }
      }),
    );
    String leaderOf(Object? id) {
      for (final l in s.leaders) {
        if (l['id'] == id) return l['name'] as String;
      }
      return '';
    }

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'បោះបង់ការជ្រើសរើស',
                onPressed: _cancelSelection,
              )
            : null,
        title: Text(
          _selectionMode
              ? 'បានជ្រើសរើស (${kh(_selectedTemplateIds.length)})'
              : 'គំរូព្រះសង្ឃទៅបុណ្យ',
        ),
        actions: [
          if (_selectionMode && _selectedTemplateIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'លុបគំរូដែលបានជ្រើសរើស',
              onPressed: () => _deleteTemplates(
                s,
                Set<int>.of(_selectedTemplateIds),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('បណ្ដោះអាសន្ន'),
                    selected: filter == TemplateFilter.temporary,
                    onSelected: (_) =>
                        setState(() => filter = TemplateFilter.temporary),
                  ),
                  ChoiceChip(
                    label: const Text('អចិន្ត្រៃយ៍'),
                    selected: filter == TemplateFilter.permanent,
                    onSelected: (_) =>
                        setState(() => filter = TemplateFilter.permanent),
                  ),
                  ChoiceChip(
                    label: const Text('បានប្រើរួច'),
                    selected: filter == TemplateFilter.archived,
                    onSelected: (_) =>
                        setState(() => filter = TemplateFilter.archived),
                  ),
                ],
              ),
            ),
          Expanded(
            child: visibleTemplates.isEmpty
                ? Center(
                    child: Text(
                      switch (filter) {
                        TemplateFilter.temporary =>
                          'មិនទាន់មានគំរូបណ្ដោះអាសន្ន ចុច + ដើម្បីបន្ថែម',
                        TemplateFilter.permanent => 'មិនទាន់មានគំរូអចិន្ត្រៃយ៍',
                        TemplateFilter.archived =>
                          'មិនទាន់មានគំរូដែលបានប្រើរួច',
                      },
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: visibleTemplates.length,
                    itemBuilder: (context, index) {
                      final template = visibleTemplates[index];
                      final id = template['id'] as int;
                      final archived = template['archived'] == 1;
                      final selected = _selectedTemplateIds.contains(id);
                      final colors = Theme.of(context).colorScheme;
                      final borderRadius = BorderRadius.circular(12);
                      final startTime =
                          (template['start_time'] ?? '').toString();
                      final endTime = (template['end_time'] ?? '').toString();
                      final subtitle = [
                        if (startTime.isNotEmpty || endTime.isNotEmpty)
                          'ម៉ោង ${startTime.isNotEmpty ? startTime : '—'}'
                              '${endTime.isNotEmpty ? ' - $endTime' : ''}',
                        [
                          if (leaderOf(template['leader_id']).isNotEmpty)
                            'អាចារ្យ: ${leaderOf(template['leader_id'])}',
                          if ((template['place'] ?? '').toString().isNotEmpty)
                            'ទីតាំង: ${template['place']}',
                        ].where((value) => value.isNotEmpty).join(' • '),
                        if ((template['note'] ?? '').toString().isNotEmpty)
                          'បញ្ជាក់: ${template['note']}',
                      ].where((value) => value.isNotEmpty).join('\n');

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primaryContainer
                              : archived
                                  ? Colors.white
                                  : Color.lerp(
                                      Colors.white,
                                      colors.primaryContainer,
                                      0.45,
                                    ),
                          borderRadius: borderRadius,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: borderRadius,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: borderRadius,
                            ),
                            leading: _selectionMode
                                ? Checkbox(
                                    value: selected,
                                    shape: const CircleBorder(),
                                    activeColor: colors.primary,
                                    side: BorderSide(color: colors.primary),
                                    onChanged: (_) =>
                                        _toggleTemplateSelection(template),
                                  )
                                : Icon(
                                    archived
                                        ? Icons.archive_outlined
                                        : Icons.assignment,
                                    color:
                                        colors.primary.withValues(alpha: 0.60),
                                  ),
                            title: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: (template['title'] ?? '').toString(),
                                  ),
                                  const TextSpan(text: ' • '),
                                  TextSpan(
                                    text: template['is_temporary'] == 1
                                        ? 'បណ្ដោះអាសន្ន'
                                        : 'អចិន្ត្រៃយ៍',
                                    style: TextStyle(
                                      color: template['is_temporary'] == 1 &&
                                              !archived
                                          ? Colors.orange.shade800
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            onTap: _selectionMode
                                ? () => _toggleTemplateSelection(template)
                                : archived
                                    ? null
                                    : () => _useTemplate(s, template),
                            onLongPress: _selectionMode
                                ? () => _toggleTemplateSelection(template)
                                : () => _showTemplateActions(s, template),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              tooltip: 'គំរូថ្មី',
              shape: CircleBorder(),
              child: const Icon(Icons.assignment_add),
              onPressed: () => _createTemplate(s),
            ),
    );
  }
}

// ---------------- Template edit / create ----------------
class TemplateEditScreen extends StatefulWidget {
  final Map<String, dynamic>? template;
  final Map<String, dynamic>? copyFrom;
  const TemplateEditScreen({super.key, this.template, this.copyFrom})
      : assert(template == null || copyFrom == null);

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late final TextEditingController title;
  late final TextEditingController note;
  String role = '';
  TimeOfDay? start, end;
  int? leaderId;
  String? place;
  bool isTemporary = true;
  late DateTime date;
  String? reminderPresetId;

  @override
  void initState() {
    super.initState();
    final t = widget.template ?? widget.copyFrom;
    isTemporary =
        widget.template == null || widget.template!['is_temporary'] == 1;
    reminderPresetId =
        (t?['reminder_preset_id'] ?? (isTemporary ? 'evening' : null))
            ?.toString();
    date =
        DateTime.tryParse((t?['task_date'] ?? '').toString()) ?? DateTime.now();
    title = TextEditingController(text: (t?['title'] ?? '').toString());
    note = TextEditingController(text: (t?['note'] ?? '').toString());
    role = (t?['role'] ?? '').toString();
    start = parseTime(t?['start_time']);
    end = parseTime(t?['end_time']);
    leaderId = t?['leader_id'] as int?;
    final pl = (t?['place'] ?? '').toString();
    place = pl.isEmpty ? null : pl;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save({bool asTemporaryCopy = false}) async {
    final name = title.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'សូមបញ្ចូលឈ្មោះគំរូ');
      return;
    }
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final selectedLeaderId = state.leaders.any((leader) =>
            leader['id'] == leaderId && canAttendAsLeader(leader['status']))
        ? leaderId
        : null;
    if (start != null && reminderPresetId != null) {
      final preset = (await NotificationService.instance.loadReminderPresets())
          .where((item) => item.id == reminderPresetId)
          .firstOrNull;
      if (!mounted) return;
      if (preset != null) {
        final eventAt = DateTime(date.year, date.month, date.day)
            .add(Duration(hours: start!.hour, minutes: start!.minute));
        if (!preset.scheduledAt(eventAt).isBefore(eventAt)) {
          showSnack(context, 'ពេលរំលឹកត្រូវតែមុនម៉ោងចាប់ផ្ដើមកម្មវិធី');
          return;
        }
      }
    }
    final v = <String, Object?>{
      'title': name,
      'role': role,
      'start_time': fmtTime(start),
      'end_time': fmtTime(end),
      'leader_id': selectedLeaderId,
      'place': place ?? '',
      'note': note.text.trim(),
      'is_temporary': asTemporaryCopy || isTemporary ? 1 : 0,
      'archived': asTemporaryCopy ? 0 : widget.template?['archived'] ?? 0,
      'task_date': DateFormat('yyyy-MM-dd').format(date),
      'reminder_preset_id': reminderPresetId ??
          (asTemporaryCopy || isTemporary ? 'evening' : null),
    };
    if (widget.template == null || asTemporaryCopy) {
      await Db.insert('templates', v);
    } else {
      await Db.update('templates', widget.template!['id'] as int, v);
    }
    await state.load();
    await NotificationService.instance.rescheduleAll();
    nav.pop(true);
  }

  Future<void> _chooseReminderPreset() async {
    final selectedId = await showReminderPresetPicker(
      context,
      selectedId: reminderPresetId,
    );
    if (mounted && selectedId != null) {
      setState(() => reminderPresetId = selectedId);
    }
  }

  Future<void> _addLeader(AppState state) async {
    final name = await askText(context, 'អាចារ្យថ្មី');
    if (name == null || name.isEmpty) return;
    final id = await Db.insert('leaders', {'name': name});
    await state.load();
    if (!mounted) return;
    setState(() => leaderId = id);
  }

  Future<void> _addPlace(AppState state) async {
    final name = await askText(context, 'ទីតាំងថ្មី');
    if (name == null || name.isEmpty) return;
    await Db.insert('places', {'name': name});
    await state.load();
    if (!mounted) return;
    setState(() => place = name);
  }

  Widget _timeTile(
      String label, TimeOfDay? t, ValueChanged<TimeOfDay?> onPick) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(10)),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(t == null ? '—' : khTime(t),
          style: const TextStyle(fontSize: 16, color: Color(0xFF19191D))),
      // trailing: t == null
      //     ? null
      //     : IconButton(
      //         icon: const Icon(Icons.close, size: 18),
      //         onPressed: () => onPick(null)),
      onTap: () async {
        final r = await showTimePicker(
            context: context,
            initialTime: t ?? const TimeOfDay(hour: 7, minute: 0));
        if (r != null) onPick(r);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eligibleLeaders =
        s.leaders.where((leader) => canAttendAsLeader(leader['status']));
    final options =
        <String>{...roleOptionsOf(s), if (role.isNotEmpty) role}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'គំរូថ្មី' : 'កែគំរូ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'កំណត់ការរំលឹក',
            onPressed: _chooseReminderPreset,
          ),
          IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'រក្សាទុក',
              onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppInputFocusGlow(
            child: TextField(
              controller: title,
              style: appInputTextStyle,
              decoration: const InputDecoration(
                labelText: 'ឈ្មោះបុណ្យ',
                hintText: 'ឧ. សង្ឃទាន...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.calendar_today),
            title: Text(khDateFull(date)),
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null) setState(() => date = selected);
            },
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ប្រភេទគំរូ'),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('បណ្ដោះអាសន្ន'),
                selected: isTemporary,
                onSelected: (_) => setState(() => isTemporary = true),
              ),
              ChoiceChip(
                label: const Text('អចិន្ត្រៃយ៍'),
                selected: !isTemporary,
                onSelected: (_) => setState(() => isTemporary = false),
              ),
            ],
          ),
          Text(
            isTemporary
                ? 'គំរូនេះនឹងទៅបណ្ណសារបន្ទាប់ពីចាត់ព្រះសង្ឃទៅបុណ្យ។'
                : 'គំរូនេះនឹងរក្សាទុករហូតដល់អ្នកលុបវា។',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          AppDropdownButtonFormField<String?>(
            initialValue: role.isEmpty ? null : role,
            isExpanded: true,
            hint: const Text('ជ្រើសរើសតួនាទី...'),
            decoration: const InputDecoration(
                labelText: 'តួនាទី (សម្រាប់ Filter ព្រះសង្ឃ)',
                labelStyle: TextStyle(color: Colors.grey),
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('គ្មានតួនាទី',
                      style: TextStyle(color: Colors.grey))),
              for (final x in options)
                DropdownMenuItem<String?>(value: x, child: Text(x)),
            ],
            onChanged: (v) => setState(() => role = v ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _timeTile('ម៉ោងចាប់ផ្តើម', start,
                      (t) => setState(() => start = t))),
              const SizedBox(width: 8),
              Expanded(
                  child: _timeTile(
                      'ម៉ោងបញ្ចប់', end, (t) => setState(() => end = t))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppDropdownButtonFormField<int?>(
                  key: ValueKey(leaderId),
                  initialValue: eligibleLeaders.any((l) => l['id'] == leaderId)
                      ? leaderId
                      : null,
                  hint: const Text('ជ្រើសរើសអាចារ្យ...'),
                  decoration: const InputDecoration(
                      labelText: 'អាចារ្យ', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('គ្មានអាចារ្យ',
                            style: TextStyle(color: Colors.grey))),
                    for (final l in eligibleLeaders)
                      DropdownMenuItem<int?>(
                          value: l['id'] as int, child: Text(l['name'])),
                  ],
                  onChanged: (v) => setState(() => leaderId = v),
                ),
              ),
              SizedBox(
                width: 12,
              ),
              IconButton(
                padding: EdgeInsets.all(14),
                style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade400)),
                    backgroundColor: Color.lerp(
                        Theme.of(context).primaryColor, Colors.white, 1)),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'បន្ថែមអាចារ្យថ្មី',
                onPressed: () => _addLeader(s),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppDropdownButtonFormField<String?>(
                  key: ValueKey(place),
                  initialValue:
                      s.places.any((x) => x['name'] == place) ? place : null,
                  hint: const Text('ជ្រើសរើសទីតាំង...'),
                  decoration: const InputDecoration(
                      labelText: 'ទីតាំង', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('គ្មានទីតាំង',
                            style: TextStyle(color: Colors.grey))),
                    for (final x in s.places)
                      DropdownMenuItem<String?>(
                          value: x['name'] as String, child: Text(x['name'])),
                  ],
                  onChanged: (v) => setState(() => place = v),
                ),
              ),
              SizedBox(
                width: 12,
              ),
              IconButton(
                padding: EdgeInsets.all(14),
                style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Color.lerp(
                        Theme.of(context).primaryColor, Colors.white, 1)),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'បន្ថែមទីតាំងថ្មី',
                onPressed: () => _addPlace(s),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppInputFocusGlow(
            child: TextField(
              controller: note,
              minLines: 2,
              maxLines: null,
              style: appInputTextStyle,
              decoration: const InputDecoration(
                labelText: 'បញ្ជាក់ (មិនចាំបាច់)',
                hintText: 'ឧ. យកបាត្រ និង ស្រាក់...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('រក្សាទុកគំរូ'),
              onPressed: _save),
          if (widget.template != null && widget.template!['is_temporary'] != 1)
            OutlinedButton.icon(
              icon: const Icon(Icons.save_as),
              label: const Text('រក្សាទុកជាគំរូបណ្ដោះអាសន្ន'),
              onPressed: () => _save(asTemporaryCopy: true),
            ),
        ],
      ),
    );
  }
}
