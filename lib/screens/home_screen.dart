// អេក្រង់ដើម: ប្រវត្តិការចាត់តាំង
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ពិនិត្យម្តងទៀតរាល់ ៣០ វិនាទី ដើម្បីឱ្យ Icon កែ/លុប បាត់ពេលផុតម៉ោង
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
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
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('ការជូនដំណឹង'),
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
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('ការកំណត់'),
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
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('គ្រប់គ្រងទិន្នន័យ'),
              subtitle: const Text('ព្រះសង្ឃ អាចារ្យ និងទីតាំង'),
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
        // leading: Padding(
        //   padding: const EdgeInsets.all(8),
        //   child: Image.asset(
        //     'assets/icons/icon.png',
        //   ),
        // ),
        title: const Text('ប្រវត្តិការទៅបុណ្យ'),
        actions: [
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
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
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: s.history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final h = s.history[i];
                final ended = historyEnded(h);
                final time = historyTimeText(h);
                final names = (h['staff_names'] ?? '').toString();
                final count = names.isEmpty ? 0 : names.split(', ').length;
                return ListTile(
                  leading: Icon(ended ? Icons.check_circle : Icons.schedule,
                      color: ended
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary),
                  title: Text('${h['title']}  •  ${kh(count)} អង្គ'),
                  subtitle: Text(
                    [historyDateText(h), if (time.isNotEmpty) time].join('\n') +
                        (names.isEmpty ? '' : '\n$names'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HistoryDetailScreen(id: h['id'] as int))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!ended) ...[
                        IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                            ),
                            tooltip: 'កែប្រែ',
                            onPressed: () => editHistory(context, s, h)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'លុប',
                            onPressed: () =>
                                deleteHistoryConfirm(context, s, h)),
                      ],
                      IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy',
                          onPressed: () => copyHistory(context, h)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('ចាត់ទៅបុណ្យថ្មី'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TemplatesScreen())),
      ),
    );
  }
}
