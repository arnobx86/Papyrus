import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/shop_provider.dart';

class EmployeeReportScreen extends StatefulWidget {
  final Map<String, dynamic> member;

  const EmployeeReportScreen({super.key, required this.member});

  @override
  State<EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<EmployeeReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  int _totalSales = 0;
  int _totalPurchases = 0;
  RealtimeChannel? _activityLogsChannel;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeReport();
    _setupRealtime();
  }

  @override
  void dispose() {
    _activityLogsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to activity_logs changes
    _activityLogsChannel = supabase
        .channel('employee_activity_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activity_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Employee activity logs change detected: ${payload.eventType}');
            if (mounted) {
              _fetchEmployeeReport();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Employee activity logs subscription status: $status');
        });
  }

  Future<void> _fetchEmployeeReport() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final userId = widget.member['user_id'];
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      
      // Get current month date range
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toUtc().toIso8601String();

      // Fetch activity logs for this user this month
      final activityRes = await supabase
          .from('activity_logs')
          .select()
          .eq('shop_id', shopId)
          .eq('user_id', userId)
          .gte('created_at', startOfMonth)
          .lte('created_at', endOfMonth)
          .order('created_at', ascending: false);

      final activities = List<Map<String, dynamic>>.from(activityRes);
      
      int sales = 0;
      int purchases = 0;

      for (var a in activities) {
        final action = a['action'].toString().toLowerCase();
        if (action.contains('sale')) sales++;
        if (action.contains('purchase')) purchases++;
      }

      if (mounted) {
        setState(() {
          _activities = activities;
          _totalSales = sales;
          _totalPurchases = purchases;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.member['user_name'] ?? widget.member['user_email'] ?? 'Member';
    final roleName = widget.member['role_name'] ?? 'Employee';
    final email = widget.member['user_email'] ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: Text('$memberName\'s Report'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEmployeeReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileHeader(memberName, roleName, email),
                  const SizedBox(height: 24),
                  _buildMonthlySummary(),
                  const SizedBox(height: 24),
                  const Text('Monthly Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildActivityList(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String name, String role, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'M', 
              style: TextStyle(fontSize: 28, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Sales', '$_totalSales', LucideIcons.shoppingBag, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('Purchases', '$_totalPurchases', LucideIcons.shoppingCart, Colors.amber)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('Actions', '${_activities.length}', LucideIcons.activity, Colors.blue)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(LucideIcons.clock, size: 48, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('No activities recorded this month', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final a = _activities[index];
        final action = a['action'] ?? 'Action';
        final details = a['details'] as Map<String, dynamic>? ?? {};
        final message = details['message'] ?? 'User performed $action';
        final date = DateTime.parse(a['created_at']).toLocal();
        
        IconData actionIcon = LucideIcons.checkCircle;
        Color actionColor = Colors.blue;
        
        if (action.toString().toLowerCase().contains('sale')) {
          actionIcon = LucideIcons.trendingUp;
          actionColor = Colors.green;
        } else if (action.toString().toLowerCase().contains('purchase')) {
          actionIcon = LucideIcons.trendingDown;
          actionColor = Colors.amber;
        } else if (action.toString().toLowerCase().contains('delete') || action.toString().toLowerCase().contains('terminate')) {
          actionIcon = LucideIcons.trash2;
          actionColor = Colors.red;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: actionColor.withOpacity(0.1),
              child: Icon(actionIcon, size: 18, color: actionColor),
            ),
            title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(message, style: const TextStyle(fontSize: 12)),
            trailing: Text(
              DateFormat('dd MMM\nhh:mm a').format(date),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
