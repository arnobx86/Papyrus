import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/shop_provider.dart';
import '../../core/storage_service.dart';

class AddPersonScreen extends StatefulWidget {
  final String initialType;
  final dynamic editPerson;

  const AddPersonScreen({
    super.key,
    this.initialType = 'customer',
    this.editPerson,
  });

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  late String _type;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (widget.editPerson != null) {
      _type = widget.editPerson['type'] ?? widget.initialType;
      _nameController.text = widget.editPerson['name'] ?? '';
      _phoneController.text = widget.editPerson['phone'] ?? '';
      _emailController.text = widget.editPerson['email'] ?? '';
      _addressController.text = widget.editPerson['address'] ?? '';
      _imageUrlController.text = widget.editPerson['image_url'] ?? '';
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
        pathPrefix: 'parties',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
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
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'address': _addressController.text.isEmpty ? null : _addressController.text,
        'image_url': _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
        'type': _type,
      };

      if (widget.editPerson != null) {
        await supabase.from('parties').update(payload).eq('id', widget.editPerson['id']);
        await shopProvider.logActivity(
          action: 'Update Party',
          details: {'message': 'Updated ${_type}: $name'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_type[0].toUpperCase()}${_type.substring(1)} updated!')),
          );
        }
      } else {
        await supabase.from('parties').insert(payload);
        await shopProvider.logActivity(
          action: 'Add Party',
          details: {'message': 'Added new ${_type}: $name'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_type[0].toUpperCase()}${_type.substring(1)} added!')),
          );
        }
      }

      if (mounted) context.pop(true);
    } catch (e) {
      debugPrint('Error saving person: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = _type == 'customer';
    final accentColor = isCustomer ? Colors.teal : Colors.amber;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editPerson != null
              ? 'Edit ${_type[0].toUpperCase()}${_type.substring(1)}'
              : 'New ${_type[0].toUpperCase()}${_type.substring(1)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
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
          // Type Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'customer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isCustomer ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isCustomer
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.user, size: 16, color: isCustomer ? Colors.teal : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Customer',
                            style: TextStyle(
                              color: isCustomer ? Colors.teal : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'supplier'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isCustomer ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !isCustomer
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.users, size: 16, color: !isCustomer ? Colors.amber : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Supplier',
                            style: TextStyle(
                              color: !isCustomer ? Colors.amber : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildImagePicker(accentColor),
          const SizedBox(height: 16),
          _buildTextField('Name', _nameController, icon: LucideIcons.user, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('Phone Number', _phoneController, icon: LucideIcons.phone, isPhone: true),
          const SizedBox(height: 16),
          _buildTextField('Email', _emailController, icon: LucideIcons.mail, isEmail: true),
          const SizedBox(height: 16),
          _buildTextField('Address', _addressController, icon: LucideIcons.mapPin, maxLines: 2),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImagePicker(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_type[0].toUpperCase()}${_type.substring(1)} Image', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isUploading ? null : _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.2)),
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
                      Icon(LucideIcons.image, size: 40, color: accentColor),
                      const SizedBox(height: 8),
                      Text('Tap to upload ${_type} image', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    required IconData icon,
    bool isRequired = false,
    bool isPhone = false,
    bool isEmail = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        hintText: isRequired ? 'Enter $label' : null,
      ),
    );
  }
}
