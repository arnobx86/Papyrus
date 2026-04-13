import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import '../../core/permissions.dart';
import '../../core/shop_provider.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _parties = [];
  String _searchQuery = '';
  RealtimeChannel? _partiesChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Refresh UI on tab change
      }
    });
    _fetchParties();
    _setupRealtime();
  }

  @override
  void dispose() {
    _partiesChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to parties changes
    _partiesChannel = supabase
        .channel('parties')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parties',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Parties change detected: ${payload.eventType}');
            if (mounted) {
              _fetchParties();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Parties subscription status: $status');
        });
  }

  Future<void> _fetchParties() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('parties')
          .select()
          .eq('shop_id', shopId)
          .order('name');
      
      if (mounted) {
        setState(() {
          _parties = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching parties: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteParty(String id) async {
    try {
      final supabase = Supabase.instance.client;
      final shopProvider = context.read<ShopProvider>();
      await supabase.from('parties').delete().eq('id', id);
      await shopProvider.logActivity(
        action: 'Delete Party',
        details: {'message': 'Deleted party ID: $id'},
      );
      _fetchParties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Party deleted')));
      }
    } catch (e) {
      debugPrint('Error deleting party: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTabType = _tabController.index == 0 ? 'customer' : 'supplier';
    final accentColor = activeTabType == 'customer' ? Colors.teal : Colors.amber;

    final filtered = _parties.where((p) {
      final typeMatch = p['type'] == activeTabType;
      final name = p['name'].toString().toLowerCase();
      final phone = p['phone']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return typeMatch && (name.contains(q) || phone.contains(q));
    }).toList();

    final auth = context.watch<AuthProvider>();
    final isOwner = auth.currentRole == 'Owner';
    final canAddCustomer = isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageCustomers);
    final canAddSupplier = isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageSuppliers);
    final canAddCurrentTab = activeTabType == 'customer' ? canAddCustomer : canAddSupplier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (canAddCurrentTab)
            IconButton(
              icon: const Icon(LucideIcons.plus),
              onPressed: () async {
                final refresh = await context.push<bool>('/add-person', extra: {'type': activeTabType});
                if (refresh == true) _fetchParties();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.user), text: 'Customers'),
            Tab(icon: Icon(LucideIcons.users), text: 'Suppliers'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchParties,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search $activeTabType...',
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  fillColor: Theme.of(context).colorScheme.surface,
                  filled: true,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                activeTabType == 'customer' ? LucideIcons.user : LucideIcons.users,
                                size: 64,
                                color: Colors.teal,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No $activeTabType yet' : 'No $activeTabType found',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (_searchQuery.isEmpty && canAddCurrentTab)
                                TextButton(
                                  onPressed: () async {
                                    final refresh = await context.push<bool>('/add-person', extra: {'type': activeTabType});
                                    if (refresh == true) _fetchParties();
                                  },
                                  child: Text('Add $activeTabType'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                              child: ListTile(
                                onTap: () => context.push('/ledger/${p['id']}/${p['name']}'),
                                onLongPress: () => _showContextMenu(context, p),
                                leading: CircleAvatar(
                                  backgroundColor: accentColor.withOpacity(0.1),
                                  backgroundImage: p['image_url'] != null ? NetworkImage(p['image_url']) : null,
                                  child: p['image_url'] == null 
                                    ? Icon(
                                      activeTabType == 'customer' ? LucideIcons.user : LucideIcons.users,
                                      color: accentColor,
                                      size: 20,
                                    )
                                    : null,
                                ),
                                title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(p['phone'] ?? (p['email'] ?? 'No contact info')),
                                trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: canAddCurrentTab ? FloatingActionButton(
        onPressed: () async {
          final refresh = await context.push<bool>('/add-person', extra: {'type': activeTabType});
          if (refresh == true) _fetchParties();
        },
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ) : null,
    );
  }

  void _showContextMenu(BuildContext context, dynamic person) {
    final auth = context.read<AuthProvider>();
    final isOwner = auth.currentRole == 'Owner';
    final canManageCustomer = isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageCustomers);
    final canManageSupplier = isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageSuppliers);
    final canManage = person['type'] == 'customer' ? canManageCustomer : canManageSupplier;

    if (!canManage) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.pencil),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  final refresh = await context.push<bool>('/add-person', extra: {'person': person, 'type': person['type']});
                  if (refresh == true) _fetchParties();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteParty(person['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
