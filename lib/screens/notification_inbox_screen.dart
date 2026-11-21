import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final notifications = await NotificationService.instance.loadInbox();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await NotificationService.instance.clearInbox();
    if (!mounted) return;
    setState(() => _notifications = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'លុប Notification ទាំងអស់',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clear,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('មិនទាន់មាន Notification ទេ'))
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final receivedAt = DateTime.tryParse(
                      (notification['receivedAt'] ?? '').toString(),
                    );
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_active_outlined),
                      ),
                      title: Text((notification['title'] ?? '').toString()),
                      subtitle: Text(
                        [
                          (notification['body'] ?? '').toString(),
                          if (receivedAt != null)
                            DateFormat('yyyy-MM-dd HH:mm').format(receivedAt),
                        ].where((text) => text.isNotEmpty).join('\n'),
                      ),
                      isThreeLine:
                          (notification['body'] ?? '').toString().isNotEmpty,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text((notification['title'] ?? '').toString()),
                          content: Text(
                            (notification['body'] ?? 'មិនមានព័ត៌មានបន្ថែម')
                                .toString(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('បិទ'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
