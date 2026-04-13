import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _returns = [];
  RealtimeChannel? _returnsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchReturns();
    _setupRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _returnsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to returns changes
    _returnsChannel = supabase
        .channel('returns')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'returns',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Returns change detected: ${payload.eventType}');
            if (mounted) {
              _fetchReturns();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Returns subscription status: $status');
        });
  }

  Future<void> _fetchReturns() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('returns')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        final returnsList = response as List;
        // Log BEFORE sorting
        debugPrint('=== RETURNS ORDERING DEBUG ===');
        if (returnsList.isNotEmpty) {
          debugPrint('BEFORE sort - First item: ${returnsList.first['created_at']}, Last item: ${returnsList.last['created_at']}');
        }
        debugPrint('Total returns: ${returnsList.length}');
        
        // Client-side sort to ensure most recent first
        returnsList.sort((a, b) {
          try {
            final aCreated = a['created_at'];
            final bCreated = b['created_at'];
            if (aCreated == null || bCreated == null) return 0;
            final aTime = DateTime.parse(aCreated as String);
            final bTime = DateTime.parse(bCreated as String);
            final timeCompare = bTime.compareTo(aTime); // Descending: newest first
            if (timeCompare != 0) return timeCompare;
            // Secondary sort by id (UUIDs are generated in order)
            final aId = (a['id'] as String?) ?? '';
            final bId = (b['id'] as String?) ?? '';
            return bId.compareTo(aId);
          } catch (e) {
            debugPrint('Error sorting returns: $e');
            return 0;
          }
        });
        
        // Log AFTER sorting
        if (returnsList.isNotEmpty) {
          debugPrint('AFTER sort - First item: ${returnsList.first['created_at']}, Last item: ${returnsList.last['created_at']}');
        }
        debugPrint('=== END RETURNS ORDERING DEBUG ===');
        setState(() {
          _returns = returnsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching returns: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTabType = _tabController.index == 0 ? 'sale' : 'purchase';
    final accentColor = activeTabType == 'sale' ? Colors.blue : Colors.amber;

    final filtered = _returns.where((r) => r['type'] == activeTabType).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.rotateCcw), text: 'Sale Returns'),
            Tab(icon: Icon(LucideIcons.rotateCcw), text: 'Purchase Returns'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReturns,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.rotateCcw, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No $activeTabType returns yet', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.1),
                            child: Icon(LucideIcons.rotateCcw, color: accentColor, size: 20),
                          ),
                          title: Text(
                            '${activeTabType[0].toUpperCase()}${activeTabType.substring(1)} Return',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Ref: #${r['reference_id'] ?? '-'}'),
                          trailing: Text(
                            '৳${r['amount']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
