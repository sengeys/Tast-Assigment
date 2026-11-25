// អេក្រង់ជ្រើសរើសបុគ្គលិក
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
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
  String? roleFilter;
  String query = '';
  bool initialized = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!initialized) {
      final r = s.template?['role'];
      if (r != null && r.toString().isNotEmpty) roleFilter = r;
      initialized = true;
    }
    final list = s.staff.where((x) {
      final eligible = canAttendWithMonks(x['status']);
      final available = !s.busyStaffIds.contains(x['id']);
      final okRole = roleFilter == null || x['role'] == roleFilter;
      final okName = query.isEmpty || (x['name'] as String).contains(query);
      return eligible && available && okRole && okName;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('ជ្រើសរើសព្រះសង្ឃ (${kh(s.selected.length)})'),
        actions: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ស្វែងរកឈ្មោះ',
                  border: OutlineInputBorder()),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                      label: const Text('ទាំងអស់'),
                      selected: roleFilter == null,
                      side: s.usesCustomOrangeTheme
                          ? BorderSide(
                              color: roleFilter == null
                                  ? const Color(0xFFFFECDF)
                                  : const Color(0xFFFF7643),
                            )
                          : null,
                      onSelected: (_) => setState(() => roleFilter = null)),
                ),
                for (final r in s.roles)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                        label: Text(r),
                        selected: roleFilter == r,
                        side: s.usesCustomOrangeTheme
                            ? BorderSide(
                                color: roleFilter == r
                                    ? const Color(0xFFFFECDF)
                                    : const Color(0xFFFF7643),
                              )
                            : null,
                        onSelected: (_) => setState(() => roleFilter = r)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
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
                                          ),
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
                        alignment: Alignment.bottomLeft,
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
            child: const Icon(Icons.person_add),
            onPressed: () async {
              final value = await recordDialog(
                context,
                'បន្ថែមព្រះសង្ឃថ្មី',
                role: roleFilter ?? '',
                roleOptions: [
                  ...roleOrder,
                  ...s.roles.where((role) => !roleOrder.contains(role)),
                ],
                statusOptions: monkStatuses,
                isStaff: true,
                includeAgeAndPhone: false,
              );
              if (value == null) return;
              await Db.insert('staff', {
                'name': value['name'],
                'role': value['role'],
                'phone': '',
                'status': value['status'],
              });
              await s.load();
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'next',
            icon: const Icon(Icons.arrow_forward),
            label: const Text('បន្ទាប់'),
            onPressed: s.selected.isEmpty
                ? null
                : () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AssignmentExtrasScreen())),
          ),
        ],
      ),
    );
  }
}
