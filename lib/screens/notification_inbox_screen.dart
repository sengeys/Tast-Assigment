import 'dart:async';

import 'package:material_ui/material_ui.dart';
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
  late final VoidCallback _inboxCountListener;

  @override
  void initState() {
    super.initState();
    _inboxCountListener = () => unawaited(_load());
    NotificationService.instance.inboxCount.addListener(_inboxCountListener);
    unawaited(_load());
  }

  @override
  void dispose() {
    NotificationService.instance.inboxCount.removeListener(_inboxCountListener);
    super.dispose();
  }

  Future<void> _load() async {
    await NotificationService.instance.reconcileDueNotifications();
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

  Future<void> _openNotification(
    Map<String, dynamic> notification,
    int index,
  ) async {
    await NotificationService.instance
        .markInboxEntryRead((notification['id'] ?? '').toString());
    if (!mounted) return;
    setState(() => _notifications[index]['isRead'] = true);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((notification['title'] ?? '').toString()),
        content: Text(
          (notification['body'] ?? 'មិនមានព័ត៌មានបន្ថែម').toString(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('បិទ'),
          ),
        ],
      ),
    );
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
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final receivedAt = DateTime.tryParse(
                      (notification['receivedAt'] ?? '').toString(),
                    );
                    final colors = Theme.of(context).colorScheme;
                    final borderRadius = BorderRadius.circular(12);
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: notification['isRead'] == true
                            ? Colors.white
                            : Color.lerp(
                                Colors.white, colors.primaryContainer, 0.45),
                        borderRadius: borderRadius,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: borderRadius,
                        child: InkWell(
                          borderRadius: borderRadius,
                          onTap: () => _openNotification(notification, index),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      child: Icon(
                                        Icons.notifications_active_outlined,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (notification['title'] ?? '')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (receivedAt != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('yyyy-MM-dd HH:mm')
                                                  .format(receivedAt),
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
                                if ((notification['body'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    notification['body'].toString(),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
