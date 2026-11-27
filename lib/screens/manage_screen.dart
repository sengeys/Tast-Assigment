// អេក្រង់គ្រប់គ្រងទិន្នន័យ: បុគ្គលិក អ្នកដឹកនាំ ទីតាំង
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/input_styles.dart';
import '../core/roles.dart';
import '../core/staff_avatar_color.dart';
import '../core/statuses.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';

enum ManageCategory {
  monks('ព្រះសង្ឃ', Icons.person_outline, 'staff', true, monkStatuses),
  leaders(
      'អាចារ្យ', Icons.person_pin_outlined, 'leaders', false, leaderStatuses),
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
  static const _sanghaFilter = '__sangha_group__';
  static const _vassaFilter = '__vassa_order__';

  final Set<int> _selectedIds = {};
  bool _selectionMode = false;
  bool _searchExpanded = false;
  String query = '';
  String? filterValue;

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

  int _filterCount(
    List<Map<String, dynamic>> rows,
    String? value,
  ) {
    if (value == null || value == _vassaFilter) return rows.length;
    if (value == _sanghaFilter) {
      return rows.where((record) => isSanghaRole(record['role'])).length;
    }
    if (widget.category.withRole) {
      return rows
          .where((record) => matchesRoleFilter(record['role'], value))
          .length;
    }
    return rows.where((record) => record['status'] == value).length;
  }

  String _filterOptionName(String value) =>
      value == _sanghaFilter ? 'គណៈសង្ឃ' : value;

  Widget _filterMenuItem({
    required String label,
    required int count,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : null;
    return Row(
      children: [
        if (selected)
          Icon(Icons.check_circle_outline, size: 20, color: color)
        else
          const SizedBox(width: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          '(${kh(count)})',
          style: TextStyle(color: color),
        ),
      ],
    );
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
    final filterOptions = widget.category.withRole
        ? [
            _sanghaFilter,
            'ភិក្ខុ',
            ...roleOptions.where(
              (role) => !isSanghaRole(role) && role != 'ភិក្ខុ',
            ),
          ]
        : widget.category.statusOptions;
    final filterField = widget.category.withRole ? 'role' : 'status';
    final filterLabel = widget.category.withRole ? 'តួនាទី' : 'ស្ថានភាព';
    final isSanghaFilter =
        widget.category.withRole && filterValue == _sanghaFilter;
    final isVassaSort = widget.category.withRole && filterValue == _vassaFilter;
    final filteredRows = rows.where((record) {
      final name = (record['name'] ?? '').toString().toLowerCase();
      final matchesQuery = name.contains(query.toLowerCase());
      final bool matchesFilter;
      if (filterValue == null || isVassaSort) {
        matchesFilter = true;
      } else if (isSanghaFilter) {
        matchesFilter = isSanghaRole(record[filterField]);
      } else if (widget.category.withRole) {
        matchesFilter = matchesRoleFilter(record[filterField], filterValue);
      } else {
        matchesFilter = record[filterField] == filterValue;
      }
      return matchesQuery && matchesFilter;
    }).toList();
    if (isVassaSort) filteredRows.sort(compareStaffByVassa);

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'បោះបង់ការជ្រើសរើស',
                onPressed: _cancelSelection,
              )
            : null,
        title: _selectionMode
            ? Text('បានជ្រើសរើស (${kh(_selectedIds.length)})')
            : _searchExpanded
                ? TextField(
                    autofocus: true,
                    style: appInputTextStyle,
                    decoration: const InputDecoration(
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'ស្វែងរកឈ្មោះ',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => query = value),
                  )
                : Text('គ្រប់គ្រង${widget.category.title}'),
        actions: [
          if (!_selectionMode)
            IconButton(
              icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              tooltip: _searchExpanded ? 'បិទការស្វែងរក' : 'ស្វែងរក',
              onPressed: () => setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) query = '';
              }),
            ),
          if (!_selectionMode && filterOptions.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: widget.category.withRole
                  ? 'ត្រងតាមគណៈសង្ឃ តួនាទី ឬវស្សា'
                  : 'ត្រងតាម$filterLabel',
              icon: const Icon(Icons.filter_list),
              onSelected: (value) =>
                  setState(() => filterValue = value.isEmpty ? null : value),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: '',
                  child: _filterMenuItem(
                    label: 'ទាំងអស់',
                    count: _filterCount(rows, null),
                    selected: filterValue == null,
                  ),
                ),
                for (final option in filterOptions)
                  PopupMenuItem(
                    value: option,
                    child: _filterMenuItem(
                      label: _filterOptionName(option),
                      count: _filterCount(rows, option),
                      selected: filterValue == option,
                    ),
                  ),
                if (widget.category.withRole) const PopupMenuDivider(),
                if (widget.category.withRole)
                  PopupMenuItem(
                    value: _vassaFilter,
                    child: _filterMenuItem(
                      label: 'វស្សា',
                      count: _filterCount(rows, _vassaFilter),
                      selected: filterValue == _vassaFilter,
                    ),
                  ),
              ],
            ),
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
          : filteredRows.isEmpty
              ? const Center(child: Text('រកមិនឃើញទិន្នន័យ'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  itemCount: filteredRows.length,
                  itemBuilder: (context, index) {
                    final record = filteredRows[index];
                    final id = record['id'] as int;
                    final selected = _selectedIds.contains(id);
                    final colors = Theme.of(context).colorScheme;
                    final status = widget.category.statusOptions.isEmpty
                        ? ''
                        : (record['status'] ??
                                widget.category.statusOptions.first)
                            .toString();
                    final subtitle = [
                      if (widget.category.withRole) ...[
                        record['role'],
                        if (record['age'] != null) 'វស្សា ${kh(record['age'])}',
                        record['phone'],
                      ],
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
                              : CircleAvatar(
                                  backgroundColor: staffAvatarColor(id),
                                  child: Icon(
                                    widget.category == ManageCategory.places
                                        ? widget.category.icon
                                        : Icons.person_outline,
                                    color: Colors.white,
                                  ),
                                ),
                          title: Text.rich(
                            TextSpan(
                              text: (record['name'] ?? '').toString(),
                              style: const TextStyle(color: Color(0xFF757575)),
                              children: [
                                if (status.isNotEmpty)
                                  TextSpan(
                                    text: ' • $status',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'បន្ថែម${widget.category.title}',
        shape: const CircleBorder(),
        child: const Icon(Icons.person_add),
        onPressed: () => _add(state, roleOptions),
      ),
    );
  }
}
