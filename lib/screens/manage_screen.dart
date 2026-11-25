// អេក្រង់គ្រប់គ្រងទិន្នន័យ: បុគ្គលិក អ្នកដឹកនាំ ទីតាំង
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/roles.dart';
import '../core/statuses.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';

enum ManageCategory {
  monks('ព្រះសង្ឃ', Icons.person_outline, 'staff', true, monkStatuses),
  leaders('អាចារ្យ', Icons.person_pin_outlined, 'leaders', false, leaderStatuses),
  places('ទីតាំង', Icons.place_outlined, 'places', false, []);

  const ManageCategory(
    this.title,
    this.icon,
    this.table,
    this.withRole,
    this.statusOptions,
  );

  final String title;
  final IconData icon;
  final String table;
  final bool withRole;
  final List<String> statusOptions;

  List<Map<String, dynamic>> rows(AppState state) => switch (this) {
        ManageCategory.monks => state.staff,
        ManageCategory.leaders => state.leaders,
        ManageCategory.places => state.places,
      };
}

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    Widget categoryTile(ManageCategory category) {
      final borderRadius = BorderRadius.circular(12);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F9),
          borderRadius: borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageCategoryScreen(category: category),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(category.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${category.title} (${kh(category.rows(state).length)})',
                      style: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF757575),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('គ្រប់គ្រងទិន្នន័យ')),
      body: ListView(
        children: [
          for (final category in ManageCategory.values) categoryTile(category),
        ],
      ),
    );
  }
}

enum _RecordAction { edit, delete, select }

class ManageCategoryScreen extends StatefulWidget {
  const ManageCategoryScreen({super.key, required this.category});

  final ManageCategory category;

  @override
  State<ManageCategoryScreen> createState() => _ManageCategoryScreenState();
}

class _ManageCategoryScreenState extends State<ManageCategoryScreen> {
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  Future<void> _edit(
    AppState state,
    List<String> roleOptions,
    Map<String, dynamic> record,
  ) async {
    final values = await recordDialog(
      context,
      'កែប្រែ${widget.category.title}',
      name: record['name'] ?? '',
      role: record['role'] ?? '',
      phone: record['phone'] ?? '',
      age: record['age']?.toString() ?? '',
      status: (record['status'] ?? '').toString(),
      roleOptions: roleOptions,
      statusOptions: widget.category.statusOptions,
      isStaff: widget.category.withRole,
    );
    if (values == null) return;
    await Db.update(widget.category.table, record['id'] as int, {
      'name': values['name'],
      if (widget.category.withRole) 'role': values['role'],
      if (widget.category.withRole) 'phone': values['phone'],
      if (widget.category.withRole) 'age': int.tryParse(values['age'] ?? ''),
      if (widget.category.statusOptions.isNotEmpty) 'status': values['status'],
    });
    await state.load();
  }

  void _toggleSelection(Map<String, dynamic> record) {
    final id = record['id'] as int;
    setState(() {
      _selectionMode = true;
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _showRecordActions(
    AppState state,
    List<String> roleOptions,
    Map<String, dynamic> record,
  ) async {
    final action = await showModalBottomSheet<_RecordAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                (record['name'] ?? '').toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('កែប្រែ'),
              onTap: () => Navigator.pop(sheetContext, _RecordAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('លុប'),
              onTap: () => Navigator.pop(sheetContext, _RecordAction.delete),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('ជ្រើសរើស'),
              onTap: () => Navigator.pop(sheetContext, _RecordAction.select),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == _RecordAction.edit) {
      await _edit(state, roleOptions, record);
    } else if (action == _RecordAction.delete) {
      await _deleteRecords(
        state,
        {record['id'] as int},
        recordName: (record['name'] ?? '').toString(),
      );
    } else {
      _toggleSelection(record);
    }
  }

  Future<void> _deleteRecords(
    AppState state,
    Set<int> ids, {
    String? recordName,
  }) async {
    if (ids.isEmpty) return;
    final title = recordName == null
        ? 'លុប ${kh(ids.length)} ឈ្មោះដែលបានជ្រើសរើស?'
        : 'លុប "$recordName" ?';
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
          widget.category.table,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    await state.load();
    if (!mounted) return;
    _cancelSelection();
  }

  Future<void> _add(
    AppState state,
    List<String> roleOptions,
  ) async {
    final values = await recordDialog(
      context,
      'បន្ថែម${widget.category.title}',
      roleOptions: roleOptions,
      statusOptions: widget.category.statusOptions,
      isStaff: widget.category.withRole,
    );
    if (values == null) return;
    await Db.insert(widget.category.table, {
      'name': values['name'],
      if (widget.category.withRole) 'role': values['role'],
      if (widget.category.withRole) 'phone': values['phone'],
      if (widget.category.withRole) 'age': int.tryParse(values['age'] ?? ''),
      if (widget.category.statusOptions.isNotEmpty) 'status': values['status'],
    });
    await state.load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = widget.category.rows(state);
    final roleOptions = [
      ...roleOrder,
      ...state.roles.where((role) => !roleOrder.contains(role)),
    ];

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
              ? 'បានជ្រើសរើស (${kh(_selectedIds.length)})'
              : 'គ្រប់គ្រង${widget.category.title}',
        ),
        actions: [
          if (_selectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'លុបឈ្មោះដែលបានជ្រើសរើស',
              onPressed: () => _deleteRecords(
                state,
                Set<int>.of(_selectedIds),
              ),
            ),
        ],
      ),
      body: rows.isEmpty
          ? Center(
              child: Text('មិនទាន់មានទិន្នន័យ${widget.category.title}'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final record = rows[index];
                final id = record['id'] as int;
                final selected = _selectedIds.contains(id);
                final colors = Theme.of(context).colorScheme;
                final subtitle = [
                  if (widget.category.withRole) ...[
                        record['role'],
                        if (record['age'] != null) 'វស្សា ${kh(record['age'])}',
                        record['phone'],
                  ],
                  if (widget.category.statusOptions.isNotEmpty)
                    'ស្ថានភាព: ${record['status'] ?? widget.category.statusOptions.first}',
                ]
                    .where((value) =>
                        value != null && value.toString().isNotEmpty)
                    .join(' • ');
                final borderRadius = BorderRadius.circular(12);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Color.lerp(
                            Colors.white,
                            Theme.of(context).colorScheme.primaryContainer,
                            0.45,
                          )
                        : const Color(0xFFF5F6F9),
                    borderRadius: borderRadius,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: borderRadius,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: borderRadius,
                      ),
                      leading: _selectionMode
                          ? Checkbox(
                              value: selected,
                              shape: const CircleBorder(),
                              activeColor: colors.primary,
                              side: BorderSide(color: colors.primary),
                              onChanged: (_) => _toggleSelection(record),
                            )
                          : Icon(
                              widget.category.icon,
                              color: colors.primary,
                            ),
                      title: Text(
                        (record['name'] ?? '').toString(),
                        style: const TextStyle(color: Color(0xFF757575)),
                      ),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(subtitle),
                      onTap: _selectionMode
                          ? () => _toggleSelection(record)
                          : () => _edit(state, roleOptions, record),
                      onLongPress: _selectionMode
                          ? () => _toggleSelection(record)
                          : () => _showRecordActions(
                                state,
                                roleOptions,
                                record,
                              ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text('បន្ថែម${widget.category.title}'),
        onPressed: () => _add(state, roleOptions),
      ),
    );
  }
}
