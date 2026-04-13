import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';
import '../../core/auth_provider.dart';
import '../../core/permissions.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) {
      debugPrint('ActivityHistoryScreen: shopId is null');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      debugPrint('ActivityHistoryScreen: Fetching activities for shop $shopId');
      
      // Use the RPC function to get recent activity
      // Query the activity_logs table directly instead of RPC
      final response = await supabase
          .from('activity_logs')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100);

      debugPrint('ActivityHistoryScreen: Received ${response.length} activities');

      if (mounted) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final filteredActivities = List<Map<String, dynamic>>.from(response)
            .where((activity) {
              try {
                final createdAt = DateTime.parse(activity['created_at']);
                return createdAt.isAfter(sevenDaysAgo);
              } catch (e) {
                debugPrint('Error parsing date for activity: $e');
                return false;
              }
            }).toList();
        
        debugPrint('ActivityHistoryScreen: Filtered to ${filteredActivities.length} activities in last 7 days');
        
        setState(() {
          _activities = filteredActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ActivityHistoryScreen: Error fetching activities: $e');
      if (mounted) {
        setState(() {
          _activities = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canViewReports = auth.currentRole == 'Owner' || Permissions.hasPermission(auth.currentPermissions, AppPermission.viewReports);

    if (!canViewReports) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity History')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              const Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              const Text('You do not have permission to view activity history.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF154834))),
        actions: [
          IconButton(
            onPressed: _fetchActivities,
            icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF154834)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.history, size: 64, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'No activity in the last 7 days',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchActivities,
                  color: const Color(0xFF154834),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: _activities.asMap().entries.map((entry) {
                          final index = entry.key;
                          final activity = entry.value;
                          return _buildTimelineItem(activity, index == _activities.length - 1);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, bool isLast) {
    final action = activity['action'].toString();
    final userEmail = activity['user_email']?.toString();
    String userDisplay;
    
    if (userEmail != null && userEmail.isNotEmpty) {
      // Extract username from email (part before @)
      userDisplay = userEmail.split('@')[0];
    } else if (activity['user_id'] != null) {
      // If we have user_id but no email, show a shortened version
      final userId = activity['user_id'].toString();
      userDisplay = 'User ${userId.substring(0, 8)}...';
    } else {
      // No user info at all
      userDisplay = 'System';
    }
    
    final time = DateTime.parse(activity['created_at'].toString()).toLocal();
    
    // Extract entity_id (reference ID) from details if available
    final details = activity['details'] as Map<String, dynamic>?;
    final referenceId = details?['entity_id'] ?? details?['reference_id'] ?? details?['invoice_id'];
    
    Color accentColor = Colors.grey;
    if (action.contains('Sale')) accentColor = Colors.green;
    else if (action.contains('Purchase')) accentColor = Colors.blue;
    else if (action.contains('Update')) accentColor = Colors.orange;
    else if (action.contains('Delete')) accentColor = Colors.red;
    else if (action.contains('Add')) accentColor = Colors.purple;
    else if (action.contains('Transaction')) accentColor = Colors.deepPurple;
    else if (action.contains('Approval')) accentColor = Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.2), width: 4),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.withOpacity(0.1),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['details']['message'] ?? action,
                     style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (referenceId != null)
                  FutureBuilder<String?>(
                    future: _getInvoiceNumber(activity['action']?.toString(), referenceId.toString()),
                    builder: (context, snapshot) {
                      final invoiceNumber = snapshot.data;
                      if (invoiceNumber != null) {
                        return Text(
                          'Invoice Number: $invoiceNumber',
                          style: const TextStyle(color: Colors.deepPurple, fontSize: 11, fontWeight: FontWeight.w500),
                        );
                      }
                      // Fallback to showing reference ID if invoice number not found
                      return Text(
                        'Reference: $referenceId',
                        style: const TextStyle(color: Colors.deepPurple, fontSize: 11, fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                const SizedBox(height: 2),
                Text('by $userDisplay • ${_formatTimeAgo(time)}',
                     style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get invoice number from sales or purchases table
  Future<String?> _getInvoiceNumber(String? action, String referenceId) async {
    try {
      if (action == null) return null;
      
      final supabase = Supabase.instance.client;
      String? table;
      
      // Determine table based on action type
      if (action.toLowerCase().contains('sale')) {
        table = 'sales';
      } else if (action.toLowerCase().contains('purchase')) {
        table = 'purchases';
      }
      
      if (table == null) return null;
      
      final response = await supabase
          .from(table)
          .select('invoice_number')
          .eq('id', referenceId)
          .single();
      return response['invoice_number']?.toString();
    } catch (e) {
      debugPrint('Error fetching invoice number: $e');
      return null;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
