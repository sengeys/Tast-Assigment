// អេក្រង់ដើម: ប្រវត្តិការចាត់តាំង
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/khmer.dart';
import '../state/app_state.dart';
import 'history_actions.dart';
import 'history_detail_screen.dart';
import 'manage_screen.dart';
import 'stats_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      appBar: AppBar(
        title: const Text('ប្រវត្តិការចាត់តាំង'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'ស្ថិតិ',
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'គំរូការងារ',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const TemplatesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'គ្រប់គ្រងទិន្នន័យ',
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageScreen())),
          ),
        ],
      ),
      body: s.history.isEmpty
          ? const Center(child: Text('មិនទាន់មានប្រវត្តិ ចុច «ចាត់តាំងថ្មី» ដើម្បីចាប់ផ្តើម'))
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
                      color: ended ? Colors.grey : Theme.of(context).colorScheme.primary),
                  title: Text('${h['title']}  •  ${kh(count)} នាក់'),
                  subtitle: Text(
                    [historyDateText(h), if (time.isNotEmpty) time].join('\n') +
                        (names.isEmpty ? '' : '\n$names'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HistoryDetailScreen(id: h['id'] as int))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!ended) ...[
                        IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'កែប្រែ',
                            onPressed: () => editHistory(context, s, h)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'លុប',
                            onPressed: () => deleteHistoryConfirm(context, s, h)),
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
        label: const Text('ចាត់តាំងថ្មី'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TemplatesScreen())),
      ),
    );
  }
}
