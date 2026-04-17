import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/shop_provider.dart';
import '../../core/data_refresh_notifier.dart';

class PersonLedgerScreen extends StatefulWidget {
  final String personId;
  final String personName;

  const PersonLedgerScreen({super.key, required this.personId, required this.personName});

  @override
  State<PersonLedgerScreen> createState() => _PersonLedgerScreenState();
}

class _PersonLedgerScreenState extends State<PersonLedgerScreen> {
  bool _isLoading = true;
  List<dynamic> _entries = [];
  Map<String, dynamic>? _personDetails;
  RealtimeChannel? _ledgerChannel;
  List<dynamic> _wallets = [];

  late DataRefreshNotifier _refreshNotifier;

  @override
  void initState() {
    super.initState();
    _fetchLedger();
    _setupRealtime();
    _refreshNotifier = context.read<DataRefreshNotifier>();
    _refreshNotifier.addListener(_onDataRefresh);
  }

  void _onDataRefresh() {
    if (_refreshNotifier.shouldRefreshAny({DataChannel.ledger, DataChannel.transactions, DataChannel.wallets})) {
      _fetchLedger();
    }
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onDataRefresh);
    _ledgerChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to ledger entries changes for this shop with stable channel name
    _ledgerChannel = supabase
        .channel('person_ledger_${widget.personId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ledger_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Person ledger change detected: ${payload.eventType}');
            // Check if this change is for our specific person
            final record = payload.newRecord ?? payload.oldRecord;
            if (record != null && record['party_id'] == widget.personId) {
              debugPrint('Change is for this person, refreshing...');
              if (mounted) {
                _fetchLedger(); // Refresh data when ledger entries change for this person
              }
            } else {
              debugPrint('Change is for a different person, ignoring...');
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Person ledger subscription status: $status');
          if (error != null) debugPrint('Person ledger subscription error: $error');
        });
  }

  Future<void> _fetchLedger() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch person details
      final personResponse = await supabase
          .from('parties')
          .select()
          .eq('shop_id', shopId)
          .eq('id', widget.personId)
          .single();
      
      // Fetch ledger entries
      final ledgerResponse = await supabase
          .from('ledger_entries')
          .select()
          .eq('shop_id', shopId)
          .eq('party_id', widget.personId)
          .order('created_at', ascending: false);
      
      // Fetch wallets for selection
      final walletResponse = await supabase
          .from('wallets')
          .select()
          .eq('shop_id', shopId)
          .order('name');
      
      if (mounted) {
        final entriesList = ledgerResponse as List;
        // Log BEFORE sorting
        debugPrint('=== LEDGER ENTRIES ORDERING DEBUG ===');
        if (entriesList.isNotEmpty) {
          debugPrint('BEFORE sort - First item: ${entriesList.first['created_at']}, Last item: ${entriesList.last['created_at']}');
        }
        debugPrint('Total ledger entries: ${entriesList.length}');
        
        // Client-side sort to ensure most recent first
        entriesList.sort((a, b) {
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
            debugPrint('Error sorting ledger entries: $e');
            return 0;
          }
        });
        
        // Log AFTER sorting
        if (entriesList.isNotEmpty) {
          debugPrint('AFTER sort - First item: ${entriesList.first['created_at']}, Last item: ${entriesList.last['created_at']}');
        }
        debugPrint('=== END LEDGER ENTRIES ORDERING DEBUG ===');
        setState(() {
          _personDetails = personResponse as Map<String, dynamic>;
          _entries = entriesList;
          _wallets = walletResponse as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Calculate unified balance using net balance logic
  /// Net Balance = Total Receivable - Total Payable
  /// If Net > 0 → Due (I owe / I need to pay)
  /// If Net < 0 → Loan (person owes me / I will receive)
  /// Never both Due and Loan at the same time
  (double netBalance, double dueAmount, double loanAmount, double payableTotal, double receivableTotal, double paymentTotal, double receivedTotal) _calculateUnifiedBalances() {
    // Calculate total payable (due entries - money I owe)
    final payableEntries = _entries
        .where((e) => e['type'] == 'due' && (e['notes'] == null || !(e['notes'] as String).toLowerCase().contains('payment:')))
        .toList();
    final payableTotal = payableEntries.fold(0.0, (s, e) => s + (double.tryParse(e['amount'].toString()) ?? 0));
    
    // Calculate total receivable (loan entries - money I will receive)
    final receivableEntries = _entries
        .where((e) => e['type'] == 'loan' && (e['notes'] == null || !(e['notes'] as String).toLowerCase().contains('received:')))
        .toList();
    final receivableTotal = receivableEntries.fold(0.0, (s, e) => s + (double.tryParse(e['amount'].toString()) ?? 0));
    
    // Calculate total payments made (payment entries)
    final paymentEntries = _entries
        .where((e) => e['type'] == 'due' && e['notes'] != null && (e['notes'] as String).toLowerCase().contains('payment:'))
        .toList();
    final paymentTotal = paymentEntries.fold(0.0, (s, e) => s + (double.tryParse(e['amount'].toString()) ?? 0));
    
    // Calculate total received (received entries)
    final receivedEntries = _entries
        .where((e) => e['type'] == 'loan' && e['notes'] != null && (e['notes'] as String).toLowerCase().contains('received:'))
        .toList();
    final receivedTotal = receivedEntries.fold(0.0, (s, e) => s + (double.tryParse(e['amount'].toString()) ?? 0));
    
    // Net Balance = (Payable + Received) - (Receivable + Payment)
    // Positive = Due (I need to pay), Negative = Loan (I will receive)
    final netBalance = (payableTotal + receivedTotal) - (receivableTotal + paymentTotal);
    
    // Unified balance: either Due OR Loan, never both
    final dueAmount = netBalance > 0 ? netBalance : 0.0;
    final loanAmount = netBalance < 0 ? netBalance.abs() : 0.0;
    
    return (netBalance, dueAmount, loanAmount, payableTotal, receivableTotal, paymentTotal, receivedTotal);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate unified net balance
    final (netBalance, dueAmount, loanAmount, payableTotal, receivableTotal, paymentTotal, receivedTotal) = _calculateUnifiedBalances();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreVertical),
            onPressed: () => _showPersonMenu(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLedger,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Person Info Card
                  if (_personDetails != null) _buildPersonInfoCard(),
                  
                  // Summary Card
                  _buildSummaryCard(netBalance, dueAmount, loanAmount),
                  
                  // Transaction History Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Transaction History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${_entries.length} entries', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  // Transaction List
                  _buildTransactionList(),
                ],
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(),
        label: const Text('Add Transaction'),
        icon: const Icon(LucideIcons.plus),
      ),
    );
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSaving = false;
    // Single selection: 'payable', 'receivable', 'payment', 'received'
    String transactionType = 'payable';
    String? selectedWalletId;
    DateTime selectedDate = DateTime.now();
    
    // Calculate unified net balance
    final (netBalance, dueAmount, loanAmount, payableTotal, receivableTotal, paymentTotal, receivedTotal) = _calculateUnifiedBalances();
    final currentDueBalance = dueAmount;
    final currentLoanBalance = loanAmount;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            // Find selected wallet balance
            Map<String, dynamic>? selectedWallet;
            if (selectedWalletId != null) {
              try {
                selectedWallet = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
              } catch (e) {
                selectedWallet = null;
              }
            } else if (_wallets.isNotEmpty) {
              selectedWallet = _wallets[0];
              selectedWalletId = selectedWallet!['id'] as String?;
            }
            
            final walletBalance = selectedWallet != null ? (double.tryParse(selectedWallet['balance'].toString()) ?? 0) : 0.0;
            final amount = double.tryParse(amountController.text) ?? 0.0;
            // Bulletproof validation: Payment > Wallet OR Payment > Payable
            // Payment reduces Due, so it should not exceed the current Due balance
            final isWalletInsufficient = transactionType == 'payment' && walletBalance < amount;
            final isPaymentExceedsDue = transactionType == 'payment' && currentDueBalance > 0 && amount > currentDueBalance;
            final isPaymentBlocked = transactionType == 'payment' && (isWalletInsufficient || isPaymentExceedsDue);
            // Received increases Due, so no limit validation needed
            final isReceivedBlocked = false;

            return Container(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                    child: Text(
                      'Add Transaction',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF195243),
                      ),
                    ),
                  ),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Transaction Type Selection - 4 options in 2x2 grid
                          const Text(
                            'Transaction Type',
                            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                          ),
                          const SizedBox(height: 6),
                          _buildFourSegmentedButtons(
                            setDialogState,
                            transactionType,
                            (type) {
                              setDialogState(() {
                                transactionType = type;
                                amountController.clear();
                                // Auto-fill amount for payment (reduces Due)
                                if (type == 'payment' && currentDueBalance > 0) {
                                  amountController.text = currentDueBalance.toStringAsFixed(2);
                                }
                                // No auto-fill for received (increases Due, no limit)
                              });
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Amount Input
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 28, color: Color(0xFF195243)),
                              decoration: const InputDecoration(
                                hintText: '৳ 0.00',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          
                          // Wallet Balance Display
                          if (transactionType == 'payment' || transactionType == 'received') ...[
                            Text(
                              isPaymentBlocked
                                  ? (isWalletInsufficient ? 'Insufficient Wallet: ৳${walletBalance.toStringAsFixed(0)}' : 'Exceeds Due: ৳${currentDueBalance.toStringAsFixed(0)}')
                                  : 'Wallet Balance: ৳${walletBalance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isPaymentBlocked ? const Color(0xFFd32f2f) : const Color(0xFF2e7d32),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Date Selector
                          const Text(
                            'Date',
                            style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                          ),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.calendar, size: 16, color: const Color(0xFF195243)),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('dd MMM, yyyy').format(selectedDate),
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Wallet Selection (for Payment/Received)
                          if (transactionType == 'payment' || transactionType == 'received') ...[
                            const Text(
                              'Select Wallet',
                              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedWalletId ?? (_wallets.isNotEmpty ? _wallets[0]['id'] as String : null),
                                  isExpanded: true,
                                  items: _wallets.map((wallet) {
                                    return DropdownMenuItem<String>(
                                      value: wallet['id'] as String,
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.wallet, size: 14, color: const Color(0xFF195243)),
                                          const SizedBox(width: 8),
                                          Text(wallet['name'] as String, style: const TextStyle(fontSize: 13)),
                                          const Spacer(),
                                          Text(
                                            '৳${(wallet['balance'] as num).toStringAsFixed(0)}',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedWalletId = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Note Field
                          const Text(
                            'Note (Optional)',
                            style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: noteController,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Write something...',
                              hintStyle: const TextStyle(fontSize: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF195243), width: 1),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  // Footer Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFeeeeee),
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (isSaving || isPaymentBlocked || isReceivedBlocked) ? null : () async {
                              final amount = double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              
                              // Validate wallet selection for Payment and Received transactions
                              if ((transactionType == 'payment' || transactionType == 'received') && selectedWalletId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a wallet'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              setDialogState(() => isSaving = true);
                              try {
                                final shopId = context.read<ShopProvider>().currentShop?.id;
                                final supabase = Supabase.instance.client;
                                
                                // Map transaction types to database types
                                String dbTransactionType;
                                String notesPrefix = '';
                                String title;
                                Color primaryColor;
                                
                                switch (transactionType) {
                                  case 'payable':
                                    dbTransactionType = 'due';
                                    title = 'Amount Payable';
                                    primaryColor = Colors.red;
                                    break;
                                  case 'receivable':
                                    dbTransactionType = 'loan';
                                    title = 'Amount Receivable';
                                    primaryColor = Colors.green;
                                    break;
                                  case 'payment':
                                    dbTransactionType = 'due';
                                    notesPrefix = 'Payment: ';
                                    title = 'Due Payment';
                                    primaryColor = Colors.orange;
                                    break;
                                  case 'received':
                                    dbTransactionType = 'loan';
                                    notesPrefix = 'Received: ';
                                    title = 'Loan Received';
                                    primaryColor = Colors.teal;
                                    break;
                                  default:
                                    dbTransactionType = 'due';
                                    title = 'Transaction';
                                    primaryColor = Colors.grey;
                                }
                                
                                // Add prefix to notes for payment and received transactions
                                final finalNotes = (notesPrefix.isNotEmpty)
                                    ? '$notesPrefix${noteController.text.trim().isEmpty ? '' : noteController.text.trim()}'
                                    : (noteController.text.trim().isEmpty ? null : noteController.text.trim());
                                
                                await supabase.from('ledger_entries').insert({
                                  'shop_id': shopId,
                                  'party_id': widget.personId,
                                  'party_name': widget.personName,
                                  'type': dbTransactionType,
                                  'amount': amount,
                                  'notes': finalNotes,
                                  'created_at': selectedDate.toIso8601String(),
                                });

                                // Create transaction record for Payment and Received only
                                // Wallet balance is handled by database trigger (bulletproof: wallet can NEVER go negative)
                                if (transactionType == 'payment' && selectedWalletId != null) {
                                  await supabase.from('transactions').insert({
                                    'shop_id': shopId,
                                    'wallet_id': selectedWalletId,
                                    'type': 'expense',
                                    'amount': amount,
                                    'category': 'Payment',
                                    'note': 'To ${widget.personName}${finalNotes != null ? ': $finalNotes' : ''}',
                                  });
                                } else if (transactionType == 'received' && selectedWalletId != null) {
                                  await supabase.from('transactions').insert({
                                    'shop_id': shopId,
                                    'wallet_id': selectedWalletId,
                                    'type': 'income',
                                    'amount': amount,
                                    'category': 'Received',
                                    'note': 'From ${widget.personName}${finalNotes != null ? ': $finalNotes' : ''}',
                                  });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _fetchLedger();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$title added successfully!'),
                                      backgroundColor: primaryColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted) setDialogState(() => isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF195243),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFourSegmentedButtons(
    StateSetter setDialogState,
    String transactionType,
    Function(String) onTypeSelected,
  ) {
    final types = [
      {'type': 'payable', 'label': 'Payable', 'color': const Color(0xFFd32f2f)},
      {'type': 'receivable', 'label': 'Receivable', 'color': const Color(0xFF2e7d32)},
      {'type': 'payment', 'label': 'Payment', 'color': Colors.orange},
      {'type': 'received', 'label': 'Received', 'color': Colors.teal},
    ];

    return Column(
      children: [
        // First row: Payable and Receivable
        Row(
          children: types.take(2).map((t) {
            final isActive = transactionType == t['type'];
            final color = t['color'] as Color;
            return Expanded(
              child: Material(
                color: isActive ? color.withOpacity(0.1) : const Color(0xFFf1f3f2),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onTypeSelected(t['type'] as String),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: isActive ? color : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Second row: Payment and Received
        Row(
          children: types.skip(2).map((t) {
            final isActive = transactionType == t['type'];
            final color = t['color'] as Color;
            return Expanded(
              child: Material(
                color: isActive ? color.withOpacity(0.1) : const Color(0xFFf1f3f2),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onTypeSelected(t['type'] as String),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: isActive ? color : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPersonInfoCard() {
    final address = _personDetails!['address'] ?? 'No address';
    final phone = _personDetails!['phone'] ?? 'No phone';
    final createdAt = _personDetails!['created_at'] != null
      ? DateFormat('dd MMM, yyyy').format(DateTime.parse(_personDetails!['created_at']))
      : 'Unknown date';
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Person Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow(LucideIcons.mapPin, 'Address', address),
            const SizedBox(height: 8),
            _buildInfoRow(LucideIcons.phone, 'Phone', phone, isPhone: true),
            const SizedBox(height: 8),
            _buildInfoRow(LucideIcons.calendar, 'Created', createdAt),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isPhone = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              if (isPhone && value != 'No phone')
                GestureDetector(
                  onTap: () => _callPhone(value),
                  child: Text(value, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                )
              else
                Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double netBalance, double dueAmount, double loanAmount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          // Unified Balance Display - either Due OR Loan, never both
          if (netBalance > 0)
            _buildSummaryItem('Due (Payable)', '৳${dueAmount.toStringAsFixed(0)}', Colors.red)
          else if (netBalance < 0)
            _buildSummaryItem('Loan (Receivable)', '৳${loanAmount.toStringAsFixed(0)}', Colors.green)
          else
            _buildSummaryItem('Balance', 'Settled', Colors.grey),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: netBalance == 0 ? Colors.grey.shade50 : (netBalance > 0 ? Colors.red.shade50 : Colors.green.shade50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: netBalance == 0 ? Colors.grey.shade100 : (netBalance > 0 ? Colors.red.shade100 : Colors.green.shade100)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Balance', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      netBalance == 0 ? '৳0' : '৳${netBalance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: netBalance == 0 ? Colors.grey : (netBalance > 0 ? Colors.red : Colors.green),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  netBalance > 0
                    ? 'You need to pay ৳${netBalance.toStringAsFixed(0)} to this person'
                    : netBalance < 0
                      ? 'You will receive ৳${netBalance.abs().toStringAsFixed(0)} from this person'
                      : 'All settled with this person',
                  style: TextStyle(
                    color: netBalance == 0 ? Colors.grey.shade700 : (netBalance > 0 ? Colors.red.shade700 : Colors.green.shade700),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_entries.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(LucideIcons.fileText, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No transactions yet', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Add your first transaction using the + button', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
      ),
    );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final e = _entries[index];
        final type = e['type'] as String;
        final notes = e['notes'] as String?;
        final isDue = type == 'due' && (notes == null || !notes.toLowerCase().contains('payment:'));
        final isLoan = type == 'loan' && (notes == null || !notes.toLowerCase().contains('received:'));
        final isPayment = type == 'due' && notes != null && notes.toLowerCase().contains('payment:');
        final isReceived = type == 'loan' && notes != null && notes.toLowerCase().contains('received:');
        final createdAt = DateTime.parse(e['created_at']);
        final dateStr = DateFormat('dd MMM, yyyy').format(createdAt);
        final timeStr = DateFormat('hh:mm a').format(createdAt);

        // Determine display based on type
        String title;
        Color color;
        String sign;
        IconData icon;
        String displayAmount;
        
        if (isPayment) {
          title = 'Payment';
          color = Colors.orange;
          sign = '-';
          icon = LucideIcons.arrowDownLeft;
          displayAmount = '-${e['amount']}';
        } else if (isReceived) {
          title = 'Received';
          color = Colors.green;
          sign = '+';
          icon = LucideIcons.arrowUpRight;
          displayAmount = '+${e['amount']}';
        } else if (isDue) {
          title = 'Due';
          color = Colors.red;
          sign = '-';
          icon = LucideIcons.fileText;
          displayAmount = '-${e['amount']}';
        } else { // isLoan
          title = 'Loan';
          color = Colors.green;
          sign = '+';
          icon = LucideIcons.fileText;
          displayAmount = '+${e['amount']}';
        }
        
        // Extract the actual note text (remove the prefix)
        String displayNote = '';
        if (notes != null) {
          if (notes.toLowerCase().contains('payment:')) {
            displayNote = notes.substring(8).trim();
          } else if (notes.toLowerCase().contains('received:')) {
            displayNote = notes.substring(9).trim();
          } else {
            displayNote = notes;
          }
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: ListTile(
            onTap: () {
              if (e['reference_type'] != null && e['reference_id'] != null) {
                context.push('/invoice/${e['reference_type']}/${e['reference_id']}');
              }
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('$dateStr • $timeStr • ${displayNote.isEmpty ? (e['reference_type'] ?? "Direct") : displayNote}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${sign}৳${e['amount']}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 8),
                // Only show menu for direct transactions (not from purchases/sales)
                if (e['reference_type'] == null)
                  PopupMenuButton<String>(
                    icon: Icon(LucideIcons.moreVertical, size: 16, color: Colors.grey),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (value) => _handleTransactionMenu(value, e),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }

  void _showPersonMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.edit),
            title: const Text('Edit Person'),
            onTap: () {
              Navigator.pop(context);
              _editPerson();
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.trash, color: Colors.red),
            title: const Text('Delete Person', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deletePerson();
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.x),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _editPerson() {
    // TODO: Implement edit person functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit person functionality coming soon')),
    );
  }

  void _deletePerson() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: const Text('Are you sure you want to delete this person? This will also delete all their transactions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement delete person functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete person functionality coming soon')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleTransactionMenu(String value, Map<String, dynamic> transaction) {
    // Check if this is a reference transaction (from purchase/sale)
    if (transaction['reference_type'] != null) {
      final refType = transaction['reference_type'] == 'purchase' ? 'Purchase' : 'Sale';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot edit/delete $refType transactions. Please edit/delete the $refType directly.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (value == 'edit') {
      _editTransaction(transaction);
    } else if (value == 'delete') {
      _deleteTransaction(transaction);
    }
  }

  void _editTransaction(Map<String, dynamic> transaction) {
    final amountController = TextEditingController(text: transaction['amount'].toString());
    final noteController = TextEditingController(text: transaction['notes']?.toString() ?? '');
    bool isSaving = false;
    
    // Map database types to UI types
    final dbType = transaction['type'] as String;
    String transactionType;
    String transactionLabel;
    
    switch (dbType) {
      case 'due':
        transactionType = 'payable';
        transactionLabel = 'Amount Payable';
        break;
      case 'loan':
        transactionType = 'receivable';
        transactionLabel = 'Amount Receivable';
        break;
      case 'payment':
        transactionType = 'payment';
        transactionLabel = 'Payment Amount';
        break;
      case 'received':
        transactionType = 'received';
        transactionLabel = 'Received Amount';
        break;
      default:
        transactionType = dbType;
        transactionLabel = 'Transaction';
    }
    
    String? selectedWalletId;
    DateTime selectedDate = DateTime.parse(transaction['created_at']);
    
    // Calculate unified net balance
    final (netBalance, dueAmount, loanAmount, payableTotal, receivableTotal, paymentTotal, receivedTotal) = _calculateUnifiedBalances();
    final currentDueBalance = dueAmount;
    final currentLoanBalance = loanAmount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Find selected wallet balance
          Map<String, dynamic>? selectedWallet;
          if (selectedWalletId != null) {
            try {
              selectedWallet = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
            } catch (e) {
              selectedWallet = null;
            }
          } else if (_wallets.isNotEmpty) {
            selectedWallet = _wallets[0];
          }
          
          final walletBalance = selectedWallet != null ? (double.tryParse(selectedWallet['balance'].toString()) ?? 0) : 0.0;
          final amount = double.tryParse(amountController.text) ?? 0.0;
          // Bulletproof validation: Payment > Wallet OR Payment > Payable
          // Payment reduces Due, so it should not exceed the current Due balance
          final isWalletInsufficient = transactionType == 'payment' && walletBalance < amount;
          final isPaymentExceedsDue = transactionType == 'payment' && currentDueBalance > 0 && amount > currentDueBalance;
          final isPaymentBlocked = transactionType == 'payment' && (isWalletInsufficient || isPaymentExceedsDue);
          // Received increases Due, so no limit validation needed
          final isReceivedBlocked = false;

          return AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Transaction Type Toggle - 4 options
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // First row: Payable and Receivable
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Payable'),
                              selected: transactionType == 'payable',
                              onSelected: (selected) {
                                setDialogState(() {
                                  transactionType = 'payable';
                                  transactionLabel = 'Amount Payable';
                                });
                              },
                              selectedColor: Colors.red.shade100,
                              labelStyle: TextStyle(
                                color: transactionType == 'payable' ? Colors.red : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Receivable'),
                              selected: transactionType == 'receivable',
                              onSelected: (selected) {
                                setDialogState(() {
                                  transactionType = 'receivable';
                                  transactionLabel = 'Amount Receivable';
                                });
                              },
                              selectedColor: Colors.green.shade100,
                              labelStyle: TextStyle(
                                color: transactionType == 'receivable' ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Second row: Payment and Received
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Payment'),
                              selected: transactionType == 'payment',
                              onSelected: (selected) {
                                setDialogState(() {
                                  transactionType = 'payment';
                                  transactionLabel = 'Payment Amount';
                                  // Auto-detect Due Payment: if person has due balance, suggest paying it
                                  if (currentDueBalance > 0) {
                                    amountController.text = currentDueBalance.toStringAsFixed(2);
                                    transactionLabel = 'Due Payment';
                                  }
                                });
                              },
                              selectedColor: Colors.orange.shade100,
                              labelStyle: TextStyle(
                                color: transactionType == 'payment' ? Colors.orange : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Received'),
                              selected: transactionType == 'received',
                              onSelected: (selected) {
                                setDialogState(() {
                                  transactionType = 'received';
                                  transactionLabel = 'Received Amount';
                                  // No auto-fill for received (increases Due, no limit)
                                });
                              },
                              selectedColor: Colors.teal.shade100,
                              labelStyle: TextStyle(
                                color: transactionType == 'received' ? Colors.teal : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: transactionLabel,
                    prefixText: '৳',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      transactionType == 'payable' ? LucideIcons.arrowDownLeft :
                      transactionType == 'receivable' ? LucideIcons.arrowUpRight :
                      transactionType == 'payment' ? LucideIcons.arrowUpLeft :
                      LucideIcons.arrowDownRight,
                      color: transactionType == 'payable' ? Colors.red :
                            transactionType == 'receivable' ? Colors.green :
                            transactionType == 'payment' ? Colors.orange :
                            Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Date selector
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.calendar),
                    ),
                    child: Text(
                      DateFormat('dd MMM, yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Wallet selection for Payment and Received transactions
                if (transactionType == 'payment' || transactionType == 'received') ...[
                  DropdownButtonFormField<String>(
                    value: selectedWalletId,
                    decoration: const InputDecoration(
                      labelText: 'Select Wallet',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.wallet),
                    ),
                    items: _wallets.map((wallet) {
                      return DropdownMenuItem<String>(
                        value: wallet['id'] as String,
                        child: Row(
                          children: [
                            const Icon(LucideIcons.wallet, size: 16),
                            const SizedBox(width: 8),
                            Text(wallet['name'] as String),
                            const SizedBox(width: 8),
                            Text(
                              '(৳${(wallet['balance'] as num).toStringAsFixed(2)})',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedWalletId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.fileText),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  transactionType == 'payable'
                    ? 'This is money you owe to this person (Payable)'
                    : transactionType == 'receivable'
                      ? 'This is money you will receive from this person (Receivable)'
                      : transactionType == 'payment'
                        ? 'This is a payment to this person (Money goes OUT of wallet, reduces Due)'
                        : 'This is money received from this person (Money comes IN to wallet, increases Due)',
                  style: TextStyle(
                    color: transactionType == 'payable' ? Colors.red.shade700 :
                          transactionType == 'receivable' ? Colors.green.shade700 :
                          transactionType == 'payment' ? Colors.orange.shade700 :
                          Colors.teal.shade700,
                    fontSize: 12,
                  ),
                ),
                // Wallet low balance warning for Payment transactions
                if (isPaymentBlocked) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertCircle, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Insufficient Wallet Balance. Available: ৳${walletBalance.toStringAsFixed(2)}, Required: ৳${amount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Show due balance hint for Payment transactions
                if (currentDueBalance > 0 && transactionType == 'payment' && !isPaymentBlocked) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Due Balance: ৳${currentDueBalance.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.amber.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isSaving || isPaymentBlocked || isReceivedBlocked) ? null : () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                // Validate wallet selection for Payment and Received transactions
                if ((transactionType == 'payment' || transactionType == 'received') && selectedWalletId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a wallet'), backgroundColor: Colors.red),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  final shopId = context.read<ShopProvider>().currentShop?.id;
                  if (shopId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shop not found'), backgroundColor: Colors.red),
                    );
                    setDialogState(() => isSaving = false);
                    return;
                  }
                  final supabase = Supabase.instance.client;
                  
                  // Map new transaction types to database types
                  String dbTransactionType;
                  switch (transactionType) {
                    case 'payable':
                      dbTransactionType = 'due';
                      break;
                    case 'receivable':
                      dbTransactionType = 'loan';
                      break;
                    case 'payment':
                      dbTransactionType = 'payment';
                      break;
                    case 'received':
                      dbTransactionType = 'received';
                      break;
                    default:
                      dbTransactionType = transactionType;
                  }
                  
                  // Update ledger entry
                  final finalNotes = (transactionLabel == 'Due Payment' || transactionLabel == 'Loan Received')
                      ? '$transactionLabel${noteController.text.trim().isEmpty ? '' : ': ${noteController.text.trim()}'}'
                      : (noteController.text.trim().isEmpty ? null : noteController.text.trim());
                  
                  await supabase.from('ledger_entries').update({
                    'type': dbTransactionType,
                    'amount': amount,
                    'notes': finalNotes,
                    'created_at': selectedDate.toIso8601String(),
                  }).eq('id', transaction['id']);

                  // Handle AyBay sync - delete old transaction and create new one
                  // Find and delete old AyBay transaction
                  final oldTxResponse = await supabase
                      .from('transactions')
                      .select()
                      .eq('shop_id', shopId)
                      .ilike('note', '%${widget.personName}%')
                      .order('created_at', ascending: false)
                      .limit(1);
                  
                  if (oldTxResponse.isNotEmpty) {
                    final oldTx = oldTxResponse[0];
                    // Delete old transaction (wallet balance reversal handled by trigger)
                    await supabase.from('transactions').delete().eq('id', oldTx['id']);
                  }
                  
                  // Create new AyBay transaction - only for Payment and Received
                  if (transactionType == 'payment' && selectedWalletId != null) {
                    // Payment - this is expense from wallet (money goes OUT)
                    await supabase.from('transactions').insert({
                      'shop_id': shopId,
                      'wallet_id': selectedWalletId,
                      'type': 'expense',
                      'amount': amount,
                      'category': transactionLabel == 'Due Payment' ? 'Due Payment' : 'Payment',
                      'note': 'To ${widget.personName}${finalNotes != null ? ': $finalNotes' : ''}',
                    });
                    // Wallet balance decrement handled by database trigger
                  } else if (transactionType == 'received' && selectedWalletId != null) {
                    // Received - this is income to wallet (money comes IN)
                    await supabase.from('transactions').insert({
                      'shop_id': shopId,
                      'wallet_id': selectedWalletId,
                      'type': 'income',
                      'amount': amount,
                      'category': transactionLabel == 'Loan Received' ? 'Loan Received' : 'Received',
                      'note': 'From ${widget.personName}${finalNotes != null ? ': $finalNotes' : ''}',
                    });
                    // Wallet balance increment handled by database trigger
                  }
                  // Note: Payable and Receivable transactions don't sync with AyBay

                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchLedger();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isSaving = false);
                }
              },
              child: Text(isSaving ? 'Saving...' : 'Update Transaction'),
            ),
          ],
        );
      },
    ),
  );
   }

  void _deleteTransaction(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final shopId = context.read<ShopProvider>().currentShop?.id;
                if (shopId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop not found'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final supabase = Supabase.instance.client;
                
                // Find and delete corresponding AyBay transaction (wallet balance reversal handled by trigger)
                final txResponse = await supabase
                    .from('transactions')
                    .select()
                    .eq('shop_id', shopId)
                    .ilike('note', '%${widget.personName}%')
                    .order('created_at', ascending: false)
                    .limit(1);
                
                if (txResponse.isNotEmpty) {
                  final tx = txResponse[0];
                  // Delete AyBay transaction (trigger will reverse wallet balance)
                  await supabase.from('transactions').delete().eq('id', tx['id']);
                }
                
                // Delete ledger entry
                await supabase.from('ledger_entries').delete().eq('id', transaction['id']);
                
                if (context.mounted) {
                  // Force refresh to ensure instant update
                  await _fetchLedger();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction deleted successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _callPhone(String phone) {
    // TODO: Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phone (simulated)')),
    );
  }
}
