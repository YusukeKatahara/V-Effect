import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// 通知画面
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
        return Icons.person_add;
      case NotificationType.friendRequestAccepted:
        return Icons.how_to_reg;
      case NotificationType.wakeUpReminder:
        return Icons.alarm;
      case NotificationType.taskReminder:
        return Icons.schedule;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
        return Colors.blue;
      case NotificationType.friendRequestAccepted:
        return Colors.green;
      case NotificationType.wakeUpReminder:
        return Colors.orange;
      case NotificationType.taskReminder:
        return Colors.amber;
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _notificationService.deleteNotification(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('通知を全て削除'),
        content: const Text('全ての通知を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _notificationService.deleteAllNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAll,
            tooltip: '全て削除',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                '通知はありません',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(notif.id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _colorForType(notif.type).withValues(alpha: 0.2),
                      child: Icon(
                        _iconForType(notif.type),
                        color: _colorForType(notif.type),
                      ),
                    ),
                    title: Text(notif.title),
                    subtitle: Text(notif.body),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _deleteNotification(notif.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
