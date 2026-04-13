import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/shop_provider.dart';
import '../../core/storage_service.dart';

class AddProductScreen extends StatefulWidget {
  final dynamic editProduct;
  const AddProductScreen({super.key, this.editProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');
  final _imageUrlController = TextEditingController();
  
  String _selectedUnit = 'pcs';
  bool _isSaving = false;
  bool _isUploading = false;
  final List<String> _units = ['pcs', 'kg', 'gm', 'litre', 'ml', 'dozen', 'box', 'pack'];

  @override
  void initState() {
    super.initState();
    if (widget.editProduct != null) {
      _nameController.text = widget.editProduct['name'] ?? '';
      _skuController.text = widget.editProduct['sku'] ?? '';
      _purchasePriceController.text = (widget.editProduct['purchase_price'] ?? widget.editProduct['cost_price'])?.toString() ?? '';
      _minStockController.text = widget.editProduct['min_stock']?.toString() ?? '5';
      _selectedUnit = widget.editProduct['unit'] ?? 'pcs';
      _imageUrlController.text = widget.editProduct['image_url'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final storage = StorageService(Supabase.instance.client);
      final url = await storage.uploadImage(
        file: File(image.path),
        bucket: 'shop-assets',
        pathPrefix: 'products',
      );

      if (url != null) {
        setState(() => _imageUrlController.text = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product name is required')));
      return;
    }

    final shopProvider = context.read<ShopProvider>();
    final shopId = shopProvider.currentShop?.id;
    if (shopId == null) return;

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final payload = {
        'shop_id': shopId,
        'name': name,
        'sku': _skuController.text.isEmpty ? null : _skuController.text,
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'cost_price': double.tryParse(_purchasePriceController.text) ?? 0, // Fallback for legacy columns
        'unit': _selectedUnit,
        'min_stock': double.tryParse(_minStockController.text) ?? 5,
        'image_url': _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
      };

      if (widget.editProduct != null) {
        await supabase.from('products').update(payload).eq('id', widget.editProduct['id']);
        await shopProvider.logActivity(
          action: 'Update Product',
          details: {'message': 'Updated product: $name'},
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated!'), backgroundColor: Colors.green));
      } else {
        await supabase.from('products').insert(payload);
        await shopProvider.logActivity(
          action: 'Add Product',
          details: {'message': 'Added new product: $name'},
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added!'), backgroundColor: Colors.green));
      }

      if (mounted) context.pop(true);
    } catch (e) {
      debugPrint('Error saving product: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editProduct != null ? 'Edit Product' : 'New Product', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildImagePicker(),
          const SizedBox(height: 24),
          _buildTextField('Product Name', _nameController, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('SKU (Optional)', _skuController, icon: LucideIcons.qrCode),
          const SizedBox(height: 16),
          _buildTextField('Purchase Price', _purchasePriceController, icon: LucideIcons.tag, isNumber: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUnit,
                          isExpanded: true,
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => _selectedUnit = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Min Stock Alert', _minStockController, isNumber: true, icon: LucideIcons.alertTriangle),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stock will start from 0. Stock will increase if you purchase. Selling price is set during sale.',
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isUploading ? null : _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: _isUploading 
              ? const Center(child: CircularProgressIndicator())
              : _imageUrlController.text.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_imageUrlController.text, width: double.infinity, height: 160, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.white),
                            onPressed: () => setState(() => _imageUrlController.clear()),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.image, size: 40, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      const Text('Tap to upload product image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, bool isNumber = false, IconData? icon, bool isEnabled = true}) {
    return TextField(
      controller: controller,
      enabled: isEnabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: const OutlineInputBorder(),
        hintText: isRequired ? 'Enter $label' : null,
      ),
    );
  }
}
