// អេក្រង់ជ្រើសរើសបុគ្គលិក
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../core/input_styles.dart';
import '../core/roles.dart';
import '../core/statuses.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../widgets/dialogs.dart';
import 'assignment_extras_screen.dart';

// ---------------- 2. Staff selection ----------------
class StaffSelectScreen extends StatefulWidget {
  const StaffSelectScreen({super.key});
  @override
  State<StaffSelectScreen> createState() => _StaffSelectScreenState();
}

class _StaffSelectScreenState extends State<StaffSelectScreen> {
  static const _sanghaFilter = '__sangha_group__';
  static const _vassaFilter = '__vassa_order__';

  String? roleFilter;
  String query = '';
  bool _searchExpanded = false;
  bool initialized = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!initialized) {
      final r = s.template?['role'];
      if (r != null && r.toString().isNotEmpty) roleFilter = r;
      initialized = true;
    }
    final filterRoles = [
      _sanghaFilter,
      ...roleOrder.where((role) => !isSanghaRole(role)),
      ...s.roles.where((role) => !roleOrder.contains(role)),
    ];
    final list = s.staff.where((x) {
      final eligible = canAttendWithMonks(x['status']);
      final available = !s.busyStaffIds.contains(x['id']);
      final okRole = roleFilter == null ||
          roleFilter == _vassaFilter ||
          (roleFilter == _sanghaFilter
              ? isSanghaRole(x['role'])
              : matchesRoleFilter(x['role'], roleFilter));
      final okName = query.isEmpty || (x['name'] as String).contains(query);
      return eligible && available && okRole && okName;
    }).toList();
    if (roleFilter == _vassaFilter) list.sort(compareStaffByVassa);

    return Scaffold(
      appBar: AppBar(
        title: _searchExpanded
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
            : Text('ជ្រើសរើសព្រះសង្ឃ'),
        // : Text('ជ្រើសរើសព្រះសង្ឃ (${kh(s.selected.length)})'),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
            tooltip: _searchExpanded ? 'បិទការស្វែងរក' : 'ស្វែងរក',
            onPressed: () => setState(() {
              _searchExpanded = !_searchExpanded;
              if (!_searchExpanded) query = '';
            }),
          ),
          PopupMenuButton<String>(
            tooltip: 'ត្រងតាមតួនាទី ឬវស្សា',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) =>
                setState(() => roleFilter = value.isEmpty ? null : value),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: '',
                child: Row(
                  children: [
                    const Expanded(child: Text('ទាំងអស់')),
                    if (roleFilter == null) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
              for (final role in filterRoles)
                PopupMenuItem(
                  value: role,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          role == _sanghaFilter ? 'គណៈសង្ឃ' : role,
                        ),
                      ),
                      if (roleFilter == role) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _vassaFilter,
                child: Row(
                  children: [
                    const Expanded(child: Text('វស្សា')),
                    if (roleFilter == _vassaFilter)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            ],
          ),
          if (s.selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'ដោះជ្រើសរើសទាំងអស់',
              onPressed: () => s.update(() {
                s.selected.clear();
                s.directInvites.clear();
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 160),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final staff = list[index];
                      final selected = s.selected.contains(staff['id']);
                      final colors = Theme.of(context).colorScheme;
                      final borderRadius = BorderRadius.circular(12);
                      final role = (staff['role'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6F9),
                          borderRadius: borderRadius,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: borderRadius,
                          child: InkWell(
                            borderRadius: borderRadius,
                            onTap: () => s.toggle(staff['id'] as int),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selected,
                                    shape: const CircleBorder(),
                                    activeColor: colors.primary,
                                    side: BorderSide(color: colors.primary),
                                    onChanged: (_) =>
                                        s.toggle(staff['id'] as int),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (staff['name'] ?? '').toString(),
                                          style: const TextStyle(
                                              color: Color(0xFF757575),
                                              fontSize: 16),
                                        ),
                                        if (role.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            role,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (s.selected.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 86 + MediaQuery.of(context).padding.bottom,
                    child: IgnorePointer(
                      child: SizedBox(
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.white,
                                Theme.of(context).colorScheme.primaryContainer,
                                0.45,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_outlined,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ជ្រើសរើសបានចំនួន ${kh(s.selected.length)} អង្គ',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: 100,
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.white,
                              Theme.of(context).colorScheme.primaryContainer,
                              0.45,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'សរុបមានចំនួន ${kh(list.length)} អង្គ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add',
            shape: CircleBorder(),
            child: const Icon(Icons.person_add),
            onPressed: () async {
              final value = await recordDialog(
                context,
                'បន្ថែមព្រះសង្ឃថ្មី',
                role: roleFilter ?? '',
                ordinationDate:
                    DateTime.now().toIso8601String().split('T').first,
                status: monkStatuses.first,
                roleOptions: [
                  ...roleOrder,
                  ...s.roles.where((role) => !roleOrder.contains(role)),
                ],
                statusOptions: monkStatuses,
                isStaff: true,
                showOrdinationDate: false,
                showStatus: false,
                includePhone: false,
              );
              if (value == null) return;
              await Db.insert('staff', {
                'name': value['name'],
                'role': value['role'],
                'phone': '',
                'ordination_date': value['ordination_date'],
                'status': value['status'],
              });
              await s.load();
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'next',
            tooltip: 'បន្ទាប់',
            shape: CircleBorder(),
            onPressed: s.selected.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AssignmentExtrasScreen())),
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}
