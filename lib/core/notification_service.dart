import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Check if activity notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('activity_notifications_enabled') ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Send notification to owner when a non-owner creates a sale or purchase
  Future<void> notifyOwnerOfActivity({
    required String shopId,
    required String actionType, // 'sale' or 'purchase'
    required String entityName,
    required double amount,
    required String performedBy,
    required String ownerId,
  }) async {
    // Check if notifications are enabled
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) return;

    // Don't notify if the owner performed the action
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id == ownerId) return;

    try {
      // Create a notification record
      await _supabase.from('notifications').insert({
        'shop_id': shopId,
        'user_id': ownerId,
        'type': actionType == 'sale' ? 'new_sale' : 'new_purchase',
        'title': actionType == 'sale' ? 'New Sale Created' : 'New Purchase Created',
        'message': '$entityName: ৳${amount.toStringAsFixed(2)} by $performedBy',
        'data': {
          'action_type': actionType,
          'entity_name': entityName,
          'amount': amount,
          'performed_by': performedBy,
          'performed_by_id': currentUser.id,
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - notifications shouldn't block the main action
      print('Error sending notification: $e');
    }
  }

  /// Send notification to owner when a deletion request is made
  Future<void> notifyOwnerOfDeletionRequest({
    required String shopId,
    required String entityType, // 'product', 'sale', 'purchase'
    required String entityName,
    required String performedBy,
    required String ownerId,
    required String referenceId,
  }) async {
    // Check if notifications are enabled
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) return;

    // Don't notify if the owner performed the action
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id == ownerId) return;

    try {
      // Create a notification record
      await _supabase.from('notifications').insert({
        'shop_id': shopId,
        'user_id': ownerId,
        'type': 'deletion_request',
        'title': 'Deletion Request: $entityType',
        'message': '$performedBy requested to delete $entityName',
        'data': {
          'entity_type': entityType,
          'entity_name': entityName,
          'performed_by': performedBy,
          'performed_by_id': currentUser.id,
          'reference_id': referenceId,
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - notifications shouldn't block the main action
      print('Error sending deletion notification: $e');
    }
  }

  /// Get unread notifications for the current user
  Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', currentUser.id)
          .eq('read', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', currentUser.id);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
