// អេក្រង់ដើម: ប្រវត្តិការចាត់តាំង
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import 'history_actions.dart';
import 'history_detail_screen.dart';
import 'app_settings_screen.dart';
import 'manage_screen.dart';
import 'notification_inbox_screen.dart';
import 'notification_settings_screen.dart';
import '../services/notification_service.dart';
import 'stats_screen.dart';
import 'templates_screen.dart';

enum _HistoryAction { edit, delete, copy, select }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _selectedHistoryIds = {};
  bool _historySelectionMode = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ពិនិត្យម្តងទៀតរាល់ ៣០ វិនាទី ដើម្បីឱ្យ Icon កែ/លុប បាត់ពេលផុតម៉ោង
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(NotificationService.instance.reconcileDueNotifications());
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleHistorySelection(Map<String, dynamic> history) {
    final id = history['id'] as int;
    setState(() {
      _historySelectionMode = true;
      if (!_selectedHistoryIds.add(id)) _selectedHistoryIds.remove(id);
    });
  }

  void _cancelHistorySelection() {
    setState(() {
      _historySelectionMode = false;
      _selectedHistoryIds.clear();
    });
  }

  Future<void> _showHistoryActions(
    AppState state,
    Map<String, dynamic> history,
  ) async {
    final action = await showModalBottomSheet<_HistoryAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                (history['title'] ?? '').toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!historyEnded(history))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('កែប្រែ'),
                onTap: () => Navigator.pop(sheetContext, _HistoryAction.edit),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('លុប'),
              onTap: () => Navigator.pop(sheetContext, _HistoryAction.delete),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('ចម្លងសារ'),
              onTap: () => Navigator.pop(sheetContext, _HistoryAction.copy),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('ជ្រើសរើស'),
              onTap: () => Navigator.pop(sheetContext, _HistoryAction.select),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _HistoryAction.edit:
        await editHistory(context, state, history);
      case _HistoryAction.delete:
        await deleteHistoryConfirm(context, state, history);
      case _HistoryAction.copy:
        copyHistory(context, history);
      case _HistoryAction.select:
        _toggleHistorySelection(history);
    }
  }

  Future<void> _deleteSelectedHistory(AppState state) async {
    final ids = Set<int>.of(_selectedHistoryIds);
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('លុប ${kh(ids.length)} ប្រវត្តិដែលបានជ្រើសរើស?'),
        content: const Text(
          'ប្រវត្តិ និងព័ត៌មានពាក់ព័ន្ធនឹងត្រូវលុបចេញពីប្រវត្តិ និងស្ថិតិ។',
        ),
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
          'task_staff',
          where: 'history_id = ?',
          whereArgs: [id],
        );
        await transaction.delete(
          'task_preachers',
          where: 'history_id = ?',
          whereArgs: [id],
        );
        await transaction.delete(
          'task_precept_givers',
          where: 'history_id = ?',
          whereArgs: [id],
        );
        await transaction.delete(
          'task_history',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    if (mounted) _cancelHistorySelection();
    await state.load();
    await NotificationService.instance.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);

    Widget drawerItem({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) {
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
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Color(0xFF757575)),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Color(0xFF757575)),
                          ),
                        ],
                      ],
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
      key: _scaffoldKey,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            drawerItem(
              icon: Icons.notifications_outlined,
              title: 'ការជូនដំណឹង',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            drawerItem(
              icon: Icons.palette_outlined,
              title: 'ការកំណត់',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppSettingsScreen(),
                  ),
                );
              },
            ),
            drawerItem(
              icon: Icons.manage_accounts_outlined,
              title: 'គ្រប់គ្រងទិន្នន័យ',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: _historySelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'បោះបង់ការជ្រើសរើស',
                onPressed: _cancelHistorySelection,
              )
            : null,
        // leading: Padding(
        //   padding: const EdgeInsets.all(8),
        //   child: Image.asset(
        //     'assets/icons/icon.png',
        //   ),
        // ),
        title: Text(
          _historySelectionMode
              ? 'បានជ្រើសរើស (${kh(_selectedHistoryIds.length)})'
              : 'ប្រវត្តិការទៅបុណ្យ',
        ),
        actions: _historySelectionMode
            ? [
                if (_selectedHistoryIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'លុបប្រវត្តិដែលបានជ្រើសរើស',
                    onPressed: () => _deleteSelectedHistory(s),
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'មើល និងបង្កើតគំរូបុណ្យ',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'ស្ថិតិ',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService.instance.inboxCount,
                  builder: (context, count, _) => IconButton(
                    tooltip: 'Notification Alert',
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text(count > 99 ? '99+' : '$count'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationInboxScreen(),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'បើក Sidebar menu',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
      ),
      body: s.history.isEmpty
          ? const Center(
              child: Text(
                  'មិនទាន់មានប្រវត្តិ ចុច «ចាត់ទៅបុណ្យថ្មី» ដើម្បីចាប់ផ្តើម'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: s.history.length,
              itemBuilder: (_, i) {
                final h = s.history[i];
                final id = h['id'] as int;
                final selected = _selectedHistoryIds.contains(id);
                final ended = historyEnded(h);
                final time = historyTimeText(h);
                final names = (h['staff_names'] ?? '').toString();
                final count = names.isEmpty ? 0 : names.split(', ').length;
                final colors = Theme.of(context).colorScheme;
                final borderRadius = BorderRadius.circular(12);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primaryContainer
                        : ended
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
                      leading: _historySelectionMode
                          ? Checkbox(
                              value: selected,
                              shape: const CircleBorder(),
                              activeColor: colors.primary,
                              side: BorderSide(color: colors.primary),
                              onChanged: (_) => _toggleHistorySelection(h),
                            )
                          : Icon(
                              ended ? Icons.check_circle : Icons.schedule,
                              color: colors.primary.withValues(alpha: 1),
                            ),
                      title: Text('${h['title']}  •  ${kh(count)} អង្គ'),
                      subtitle: Text(
                        [
                          historyDateText(h),
                          if (time.isNotEmpty) time,
                          if (names.isNotEmpty) names,
                        ].join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: _historySelectionMode
                          ? () => _toggleHistorySelection(h)
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HistoryDetailScreen(id: id),
                                ),
                              ),
                      onLongPress: _historySelectionMode
                          ? () => _toggleHistorySelection(h)
                          : () => _showHistoryActions(s, h),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _historySelectionMode
          ? null
          : FloatingActionButton(
              tooltip: 'ចាត់ទៅបុណ្យថ្មី',
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemplatesScreen()),
              ),
            ),
    );
  }
}
