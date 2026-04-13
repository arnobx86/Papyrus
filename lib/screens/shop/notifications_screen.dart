import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/notification_service.dart';
import '../../core/shop_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(Supabase.instance.client);
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final notes = await _notificationService.getUnreadNotifications();
    if (mounted) {
      setState(() {
        _notifications = notes;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllAsRead();
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bellOff, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No new notifications', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final note = _notifications[index];
          final type = note['type'] as String?;
          final date = DateTime.parse(note['created_at']);
          final timeStr = DateFormat('h:mm a, MMM dd').format(date.toLocal());

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              onTap: () {
                _notificationService.markAsRead(note['id']);
                if (type == 'deletion_request') {
                  context.push('/approvals');
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconColor(type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(type), color: _getIconColor(type), size: 20),
              ),
              title: Text(note['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(note['message'] ?? '', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'new_sale': return LucideIcons.shoppingBag;
      case 'new_purchase': return LucideIcons.truck;
      case 'deletion_request': return LucideIcons.alertTriangle;
      default: return LucideIcons.bell;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'new_sale': return Colors.green;
      case 'new_purchase': return Colors.blue;
      case 'deletion_request': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
