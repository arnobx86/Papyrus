import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  final SupabaseClient _supabase;

  ActivityService(this._supabase);

  Future<void> log({
    required String action,
    required String shopId,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    try {
      // Get current user info
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      var userEmail = user?.email;
      
      // If user email is null, try to get it from user metadata or provide a fallback
      if (userEmail == null || userEmail.isEmpty) {
        if (userId != null) {
          // Try to get email from user metadata
          final userMetadata = user?.userMetadata;
          if (userMetadata != null && userMetadata['email'] != null) {
            userEmail = userMetadata['email'].toString();
          } else {
            // Fallback to a default email based on user ID
            userEmail = 'user_${userId.substring(0, 8)}@app.local';
          }
        } else {
          // No user ID either, use system email
          userEmail = 'system@papyrus.app';
        }
      }
      
      print('ActivityService: Logging activity - action: $action, shopId: $shopId, userId: $userId, userEmail: $userEmail');
      print('ActivityService: Parameters - entityType: $entityType, entityId: $entityId, details: $details');
      
      // Check if user is authenticated
      if (user == null) {
        print('ActivityService: WARNING - No authenticated user found, using fallback email: $userEmail');
      }
      
      // Check if shopId is valid
      if (shopId.isEmpty) {
        print('ActivityService: ERROR - shopId is empty, cannot log activity');
        return;
      }
      
      final result = await _supabase.rpc(
        'log_activity',
        params: {
          'p_action': action,
          'p_shop_id': shopId,
          'p_user_id': userId,
          'p_user_email': userEmail,
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_details': details ?? {},
        },
      ).timeout(const Duration(seconds: 10));
      
      print('ActivityService: RPC call completed successfully');
      print('ActivityService: Successfully logged activity "$action" for shop $shopId with user email: $userEmail');
    } catch (e) {
      // Log error but don't crash the app
      print('ActivityService: ERROR logging activity: $e');
      print('ActivityService: Error details: ${e.toString()}');
      print('ActivityService: Error type: ${e.runtimeType}');
      
      // Also print stack trace if available
      if (e is Error) {
        print('ActivityService: Error stack trace: ${e.stackTrace}');
      }
      
      // Check for specific common errors
      if (e.toString().contains('column') && e.toString().contains('does not exist')) {
        print('ActivityService: CRITICAL - Database column missing. Please run the activity logging migration.');
        print('ActivityService: Migration file: supabase/migrations/20260331_final_fix_activity_functions.sql');
      } else if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        print('ActivityService: CRITICAL - Database function missing. Please run the activity logging migration.');
        print('ActivityService: Migration file: supabase/migrations/20260331_final_fix_activity_functions.sql');
      } else if (e.toString().contains('timeout')) {
        print('ActivityService: WARNING - RPC call timed out. The activity may not have been logged.');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity(String shopId, {int limit = 20}) async {
    try {
      print('ActivityService: Fetching recent activity for shop $shopId with limit $limit');
      print('ActivityService: Calling RPC get_recent_activity with p_shop_id: $shopId, p_limit: $limit');
      
      // Check if shopId is valid
      if (shopId.isEmpty) {
        print('ActivityService: ERROR - shopId is empty, cannot fetch activities');
        return [];
      }
      
      // Query the activity_logs table directly instead of RPC
      // This ensures we bypass any potentially outdated RPC functions that filter by user_id
      final List<dynamic> response = await _supabase
          .from('activity_logs')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 10));
      
      print('ActivityService: RPC call completed, received ${response.length} activities');
      if (response.isNotEmpty) {
        print('ActivityService: First activity: ${response[0]}');
        print('ActivityService: First activity keys: ${(response[0] as Map).keys}');
        print('ActivityService: First activity details field: ${(response[0] as Map)['details']}');
        print('ActivityService: First activity details type: ${(response[0] as Map)['details'].runtimeType}');
        
        // Log all activities for debugging
        for (int i = 0; i < min(response.length, 3); i++) {
          final activity = response[i] as Map;
          print('ActivityService: Activity $i - action: ${activity['action']}, user_email: ${activity['user_email']}, created_at: ${activity['created_at']}');
        }
      } else {
        print('ActivityService: No activities found in database');
        print('ActivityService: Possible reasons:');
        print('ActivityService: 1. The activity_logs table is empty (no activities logged yet)');
        print('ActivityService: 2. The get_recent_activity function does not exist (run migration)');
        print('ActivityService: 3. The RPC call failed silently (check console for errors)');
        print('ActivityService: 4. No activities match the shop_id $shopId');
        print('ActivityService: 5. Database permissions issue (RLS policies)');
        
        // Suggest running migration
        print('ActivityService: RECOMMENDATION: Run the activity logging migration if not already done');
        print('ActivityService: Migration file: supabase/migrations/20260331_fix_activity_logging_columns.sql');
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('ActivityService: ERROR fetching activity: $e');
      print('ActivityService: Error details: ${e.toString()}');
      print('ActivityService: Error type: ${e.runtimeType}');
      
      // Also print stack trace if available
      if (e is Error) {
        print('ActivityService: Error stack trace: ${e.stackTrace}');
      }
      
      // Check for specific common errors
      if (e.toString().contains('column') && e.toString().contains('does not exist')) {
        print('ActivityService: CRITICAL - Database column missing. Please run the activity logging migration.');
        print('ActivityService: Migration file: supabase/migrations/20260331_fix_activity_logging_columns.sql');
      } else if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        print('ActivityService: CRITICAL - Database function missing. Please run the activity logging migration.');
        print('ActivityService: Migration file: supabase/migrations/20260331_fix_activity_logging_columns.sql');
      } else if (e.toString().contains('timeout')) {
        print('ActivityService: WARNING - RPC call timed out. Network or database issue.');
      } else if (e.toString().contains('permission') || e.toString().contains('RLS')) {
        print('ActivityService: ERROR - Permission denied. Check RLS policies on activity_logs table.');
      }
      
      return [];
    }
  }
}
