import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  bool _isLoading = true;
  List<dynamic> _wallets = [];
  RealtimeChannel? _walletsChannel;
  
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _transferAmountController = TextEditingController();
  String? _fromWalletId;
  String? _toWalletId;

  @override
  void initState() {
    super.initState();
    _fetchWallets();
    _setupRealtime();
  }

  @override
  void dispose() {
    _walletsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to wallets changes
    _walletsChannel = supabase
        .channel('wallets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Wallets change detected: ${payload.eventType}');
            if (mounted) {
              _fetchWallets();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Wallets subscription status: $status');
        });
  }

  Future<void> _fetchWallets() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('wallets')
          .select()
          .eq('shop_id', shopId)
          .order('name');
      
      if (mounted) {
        setState(() {
          _wallets = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWallet(BuildContext dialogContext) async {
    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet name is required')));
      return;
    }

    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    if (_wallets.any((w) => w['name'].toString().toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A wallet with this name already exists')));
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final shopProvider = context.read<ShopProvider>();

      await supabase.from('wallets').insert({
        'shop_id': shopId,
        'name': name,
        'balance': balance,
      });

      await shopProvider.logActivity(
        action: 'Add Wallet',
        details: {'message': 'Added wallet: $name with initial balance ৳$balance'},
      );

      _nameController.clear();
      _balanceController.clear();
      // Close the dialog using the dialog's own context
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      await _fetchWallets();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet added!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Error adding wallet: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _transferFunds(BuildContext dialogContext) async {
    final amount = double.tryParse(_transferAmountController.text) ?? 0;
    if (_fromWalletId == null || _toWalletId == null || _fromWalletId == _toWalletId || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid transfer details')));
      return;
    }

    final fromWallet = _wallets.firstWhere((w) => w['id'] == _fromWalletId);
    if (double.parse(fromWallet['balance'].toString()) < amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance in source wallet')));
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final shopProvider = context.read<ShopProvider>();
      final toWallet = _wallets.firstWhere((w) => w['id'] == _toWalletId);

      await supabase.from('wallets').update({'balance': double.parse(fromWallet['balance'].toString()) - amount}).eq('id', _fromWalletId!);
      await supabase.from('wallets').update({'balance': double.parse(toWallet['balance'].toString()) + amount}).eq('id', _toWalletId!);

      await shopProvider.logActivity(
        action: 'Transfer Funds',
        details: {'message': 'Transferred ৳$amount from ${fromWallet['name']} to ${toWallet['name']}'},
      );

      _transferAmountController.clear();
      _fromWalletId = null;
      _toWalletId = null;
      // Close dialog using dialog's own context
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      await _fetchWallets();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer complete!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Error transferring funds: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteWallet(String id) async {
    try {
      final supabase = Supabase.instance.client;
      final shopProvider = context.read<ShopProvider>();
      final wallet = _wallets.firstWhere((w) => w['id'] == id);
      
      await supabase.from('wallets').delete().eq('id', id);
      
      await shopProvider.logActivity(
        action: 'Delete Wallet',
        details: {'message': 'Removed wallet: ${wallet['name']}'},
      );
      
      await _fetchWallets();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet removed')));
    } catch (e) {
      debugPrint('Error deleting wallet: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleDefaultWallet(String id) async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Unset any existing default wallet for this shop
      await supabase.from('wallets').update({'is_default': false}).eq('shop_id', shopId);
      
      // 2. Set this wallet as default
      await supabase.from('wallets').update({'is_default': true}).eq('id', id);
      
      await _fetchWallets();
    } catch (e) {
      debugPrint('Error setting default wallet: $e');
    }
  }

  void _showAddDialog() {
    _nameController.clear();
    _balanceController.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Add Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g. Bkash, Cash, Bank',
                  prefixIcon: const Icon(LucideIcons.wallet, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Initial Balance',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('৳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                _balanceController.clear();
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addWallet(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showTransferDialog() {
    _fromWalletId = null;
    _toWalletId = null;
    _transferAmountController.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Fund Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _fromWalletId,
                    decoration: const InputDecoration(labelText: 'From Wallet', border: OutlineInputBorder()),
                    items: _wallets.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name']))).toList(),
                    onChanged: (v) => setDialogState(() => _fromWalletId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _toWalletId,
                    decoration: const InputDecoration(labelText: 'To Wallet', border: OutlineInputBorder()),
                    items: _wallets.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name']))).toList(),
                    onChanged: (v) => setDialogState(() => _toWalletId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _transferAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('৳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _fromWalletId = null;
                    _toWalletId = null;
                    _transferAmountController.clear();
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _transferFunds(dialogCtx),
                  child: const Text('Transfer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWallets,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _wallets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.wallet, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('No wallets yet', style: TextStyle(color: Colors.grey)),
                        TextButton(onPressed: _showAddDialog, child: const Text('Add Wallet')),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = _wallets[index];
                      final balance = double.parse(wallet['balance'].toString());
                      final isNegative = balance < 0;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isNegative ? Colors.red.withOpacity(0.1) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.wallet, size: 16, color: isNegative ? Colors.red : Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(wallet['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '৳${balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isNegative ? Colors.red : null,
                              fontWeight: isNegative ? FontWeight.bold : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  wallet['is_default'] == true ? LucideIcons.star : LucideIcons.star,
                                  size: 18,
                                  color: wallet['is_default'] == true ? Colors.amber : Colors.grey[300],
                                ),
                                onPressed: () => _toggleDefaultWallet(wallet['id']),
                                tooltip: 'Set as default',
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.grey),
                                onPressed: () => _deleteWallet(wallet['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              onPressed: _showTransferDialog,
              heroTag: 'transfer',
              label: const Text('Transfer'),
              icon: const Icon(LucideIcons.arrowRight),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              onPressed: _showAddDialog,
              heroTag: 'add',
              label: const Text('Add Wallet'),
              icon: const Icon(LucideIcons.plus),
            ),
          ],
        ),
      ),
    );
  }
}
