import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  final _categoryController = TextEditingController();
  String _selectedCategoryType = 'expense'; // 'income' or 'expense'
  RealtimeChannel? _categoriesChannel;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _setupRealtime();
  }

  @override
  void dispose() {
    _categoriesChannel?.unsubscribe();
    _categoryController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to categories changes
    _categoriesChannel = supabase
        .channel('categories')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'categories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            debugPrint('Categories change detected: ${payload.eventType}');
            if (mounted) {
              _fetchCategories();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Categories subscription status: $status');
        });
  }

  Future<void> _fetchCategories() async {
    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('categories')
          .select()
          .eq('shop_id', shopId)
          .order('name');
      
      if (mounted) {
        setState(() {
          _categories = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      
      // If table doesn't exist, return empty list
      final errorStr = e.toString();
      if (errorStr.contains("Could not find the table 'public.categories'") ||
          errorStr.contains('PGRST205')) {
        debugPrint('Categories table not found, returning empty list');
        if (mounted) {
          setState(() {
            _categories = [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;

    final shopId = context.read<ShopProvider>().currentShop?.id;
    if (shopId == null) {
      debugPrint('No shop ID found, cannot add category');
      return;
    }

    // Check for duplicate (case-insensitive)
    if (_categories.any((c) => c['name'].toString().toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists')),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      debugPrint('Attempting to insert category: name=$name, shop_id=$shopId, type=$_selectedCategoryType');
      
      final response = await supabase.from('categories').insert({
        'shop_id': shopId,
        'name': name,
        'type': _selectedCategoryType,
      }).select();
      
      debugPrint('Category insert response: $response');
      
      _categoryController.clear();
      if (mounted) Navigator.pop(context);
      await _fetchCategories();
      
      // Log category creation
      if (mounted) {
        context.read<ShopProvider>().logActivity(
          action: 'Add Category',
          entityType: 'category',
          entityId: name, // Using name as secondary ID since it's unique enough for display
          details: {
            'name': name,
            'type': _selectedCategoryType,
            'message': 'Added new category: $name ($_selectedCategoryType)'
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category added')));
      }
    } catch (e) {
      debugPrint('Error adding category: $e');
      
      // Check if the error is because the table doesn't exist
      final errorStr = e.toString();
      if (errorStr.contains("Could not find the table 'public.categories'") ||
          errorStr.contains('PGRST205')) {
        debugPrint('Categories table not found, attempting to create it...');
        try {
          await _createCategoriesTable();
          // If _createCategoriesTable returns without throwing, table was created
          // Retry the insert after creating the table
          await _retryAddCategory(name, shopId);
        } catch (createError) {
          debugPrint('Failed to create table: $createError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot add category - database table missing. Please run migrations.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add category: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _createCategoriesTable() async {
    debugPrint('Categories table does not exist and cannot be created automatically');
    throw Exception('Categories table does not exist. Please run migrations.');
  }

  Future<void> _retryAddCategory(String name, String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint('Retrying category insert after table creation...');
      
      final response = await supabase.from('categories').insert({
        'shop_id': shopId,
        'name': name,
        'type': _selectedCategoryType,
      }).select();
      
      debugPrint('Category insert retry response: $response');
      
      _categoryController.clear();
      if (mounted) Navigator.pop(context);
      await _fetchCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category added (table created)')));
      }
    } catch (e) {
      debugPrint('Error in retry adding category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category even after table creation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('categories').delete().eq('id', id);
      
      // Log category deletion
      if (mounted) {
        final cat = _categories.firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Unknown'});
        context.read<ShopProvider>().logActivity(
          action: 'Delete Category',
          entityType: 'category',
          entityId: id,
          details: {
            'name': cat['name'],
            'message': 'Deleted category: ${cat['name']}'
          },
        );
      }

      _fetchCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category removed')));
      }
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _categoryController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'e.g. Food, Transport, Rent',
                      prefixIcon: Icon(LucideIcons.layoutGrid, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryType,
                    items: const [
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategoryType = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(LucideIcons.type, size: 20),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _categoryController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _addCategory,
                  child: const Text('Add'),
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
        title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCategories,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.layoutGrid, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('No categories yet', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: _showAddDialog,
                          child: const Text('Add Category'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
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
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.layoutGrid, size: 16, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.grey),
                            onPressed: () => _deleteCategory(cat['id']),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Category'),
      ),
    );
  }
}
