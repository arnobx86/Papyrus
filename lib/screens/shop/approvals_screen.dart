import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';
import '../../core/auth_provider.dart';
import '../../core/permissions.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _requests = [];
  
  final Map<String, String> _actionLabels = {
    'delete_sale': 'Delete Sale',
    'edit_old_transaction': 'Edit Old Transaction',
    'stock_adjustment': 'Stock Adjustment',
    'delete_purchase': 'Delete Purchase',
    'delete_product': 'Delete Product',
    'delete_transaction': 'Delete Transaction',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      // Fetch approval requests with requester info from profiles
      final response = await supabase
          .from('approval_requests')
          .select('*, profiles(username, full_name)')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      
      debugPrint('Fetched ${response.length} approval requests for shop $shopId');
      
      // Debug: Print all column names of first request if available
      if (response.isNotEmpty) {
        final firstReq = response[0];
        debugPrint('First request columns: ${firstReq.keys.join(', ')}');
      }
      
      for (var i = 0; i < response.length; i++) {
        final req = response[i];
        
        // Handle both 'type' and 'action_type' column names
        final typeValue = req['type'] ?? req['action_type'];
        debugPrint('Request $i: id=${req['id']}, type=$typeValue, action_type=${req['action_type']}, status=${req['status']}, reference_id=${req['reference_id']}, shop_id=${req['shop_id']}');
        
        if (req['details'] != null) {
          debugPrint('  details: ${req['details']}');
        }
        
        // Debug requester info
        debugPrint('  requester_id=${req['requester_id']}, requested_by=${req['requested_by']}');
      }
      
      if (mounted) {
        setState(() {
          _requests = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching approvals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String id, String action) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final supabase = Supabase.instance.client;
      
      if (action == 'approved') {
        // Fetch the request details to know what to do
        final request = _requests.firstWhere((r) => r['id'] == id);
        final details = request['details'] as Map<String, dynamic>?;
        final refId = request['reference_id'] ?? details?['reference_id'];
        final actionType = request['action_type'] ?? request['type'];

        if (actionType == 'delete_sale' && refId != null) {
          await _executeDeleteSale(refId);
        } else if (actionType == 'delete_purchase' && refId != null) {
          await _executeDeletePurchase(refId);
        } else if (actionType == 'delete_product' && refId != null) {
          await _executeDeleteProduct(refId);
        } else if (actionType == 'delete_transaction' && refId != null) {
          await _executeDeleteTransaction(refId);
        }
      }

      // Only update status and potentially approved_by if column exists
      Map<String, dynamic> updateData = {'status': action};
      // We'll skip approved_by for now to avoid potential schema errors
      // if the user hasn't successfully run the latest migration.
      
      await supabase
          .from('approval_requests')
          .update(updateData)
          .eq('id', id);
      
      // Log the decision
      if (mounted) {
        final request = _requests.firstWhere((r) => r['id'] == id);
        final actionType = request['action_type'] ?? request['type'];
        context.read<ShopProvider>().logActivity(
          action: action == 'approved' ? 'Request Approved' : 'Request Rejected',
          entityType: 'approval',
          entityId: id,
          details: {
            'action': actionType,
            'status': action,
            'message': 'Owner ${action == 'approved' ? 'approved' : 'rejected'} $actionType request'
          },
        );
      }
      
      _fetchRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request ${action == 'approved' ? 'Approved & Executed' : 'Rejected'}'))
        );
      }
    } catch (e) {
      debugPrint('Error updating approval: $e');
    }
  }

  Future<void> _executeDeleteSale(String id) async {
    final supabase = Supabase.instance.client;
    // 1. Revert stock
    final items = await supabase.from('sale_items').select().eq('sale_id', id);
    for (var item in items) {
      final productId = item['product_id'];
      final qty = double.tryParse(item['quantity'].toString()) ?? 0;
      final product = await supabase.from('products').select('stock').eq('id', productId).single();
      final currentStock = double.tryParse(product['stock'].toString()) ?? 0;
      await supabase.from('products').update({'stock': currentStock + qty}).eq('id', productId);
    }
    // 2. Cleanup
    await supabase.from('ledger_entries').delete().eq('reference_id', id).eq('reference_type', 'sale');
    await supabase.from('sale_items').delete().eq('sale_id', id);
    await supabase.from('sales').delete().eq('id', id);
  }

  Future<void> _executeDeletePurchase(String id) async {
    final supabase = Supabase.instance.client;
    // 1. Revert stock (decrease)
    final items = await supabase.from('purchase_items').select().eq('purchase_id', id);
    for (var item in items) {
      final productId = item['product_id'];
      final qty = double.tryParse(item['quantity'].toString()) ?? 0;
      final product = await supabase.from('products').select('stock').eq('id', productId).single();
      final currentStock = double.tryParse(product['stock'].toString()) ?? 0;
      await supabase.from('products').update({'stock': currentStock - qty}).eq('id', productId);
    }
    // 2. Cleanup
    await supabase.from('ledger_entries').delete().eq('reference_id', id).eq('reference_type', 'purchase');
    await supabase.from('purchase_items').delete().eq('purchase_id', id);
    await supabase.from('purchases').delete().eq('id', id);
  }

  Future<void> _executeDeleteProduct(String id) async {
    final supabase = Supabase.instance.client;
    // Delete the product from the products table
    await supabase.from('products').delete().eq('id', id);
  }

  Future<void> _executeDeleteTransaction(String id) async {
    final supabase = Supabase.instance.client;
    // Note: If you want to refund/deduct wallet balance automatically, it should go here.
    // However, the current standard in the system seems to let users adjust manually or not at all unless triggered.
    await supabase.from('transactions').delete().eq('id', id);
  }

  // Helper method to get requester name from the approval request
  String _getRequesterName(dynamic request) {
    // Try to get from profiles join first
    final profiles = request['profiles'];
    if (profiles != null) {
      final username = profiles['username'];
      if (username != null && username.toString().isNotEmpty) {
        return username.toString();
      }
      final fullName = profiles['full_name'];
      if (fullName != null && fullName.toString().isNotEmpty) {
        return fullName.toString();
      }
    }
    // Fallback to requested_by user ID
    final requestedBy = request['requested_by'] ?? request['requester_id'];
    if (requestedBy != null) {
      return 'User ${requestedBy.toString().substring(0, 8)}';
    }
    return 'Unknown';
  }

  // Helper method to get invoice number from sales or purchases table
  Future<String?> _getInvoiceNumber(String entityType, String referenceId) async {
    try {
      final supabase = Supabase.instance.client;
      final table = entityType == 'sale' ? 'sales' : 'purchases';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canApprove = auth.currentRole == 'Owner' || Permissions.hasPermission(auth.currentPermissions, AppPermission.approveActions);

    if (!canApprove) {
      return Scaffold(
        appBar: AppBar(title: const Text('Approvals')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              const Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              const Text('Only the owner or managers can access approvals.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final pending = _requests.where((r) => r['status'] == 'pending').toList();
    final resolved = _requests.where((r) => r['status'] != 'pending').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.clock, size: 16), const SizedBox(width: 8), Text('Pending (${pending.length})')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.checkCircle2, size: 16), const SizedBox(width: 8), const Text('History')])),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildRequestList(pending, canApprove, true),
              _buildRequestList(resolved, canApprove, false),
            ],
          ),
    );
  }

  Widget _buildRequestList(List<dynamic> items, bool canApprove, bool isPending) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPending ? LucideIcons.clock : LucideIcons.checkCircle2, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(isPending ? 'No pending approvals' : 'No history yet', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final r = items[index];
        final actionType = r['action_type'] ?? r['type'];
        final label = _actionLabels[actionType] ?? actionType;
        final details = r['details'] as Map<String, dynamic>?;
        final refId = r['reference_id'] ?? details?['reference_id'];
        final dateStr = DateTime.parse(r['created_at']).toLocal().toString().split('.')[0];
        
        // Fetch invoice number for sales and purchases
        Future<String?>? invoiceNumberFuture;
        if (refId != null && (actionType == 'delete_sale' || actionType == 'delete_purchase')) {
          invoiceNumberFuture = _getInvoiceNumber(actionType == 'delete_sale' ? 'sale' : 'purchase', refId);
        }

        return FutureBuilder<String?>(
          future: invoiceNumberFuture,
          builder: (context, snapshot) {
            final invoiceNumber = snapshot.data;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isPending ? Colors.orange : (r['status'] == 'approved' ? Colors.green : Colors.red)).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPending ? LucideIcons.alertTriangle : (r['status'] == 'approved' ? LucideIcons.checkCircle2 : LucideIcons.xCircle),
                            size: 20,
                            color: isPending ? Colors.orange : (r['status'] == 'approved' ? Colors.green : Colors.red),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (invoiceNumber != null)
                                Text(
                                  'Invoice Number: $invoiceNumber',
                                  style: const TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              // Display requester username
                              Text(
                                'Requested by: ${_getRequesterName(r)}',
                                style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text('Requested at: $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isPending && canApprove) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleAction(r['id'], 'rejected'),
                              icon: const Icon(LucideIcons.xCircle, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleAction(r['id'], 'approved'),
                              icon: const Icon(LucideIcons.checkCircle2, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!isPending) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${r['status'].toString().toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: r['status'] == 'approved' ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
