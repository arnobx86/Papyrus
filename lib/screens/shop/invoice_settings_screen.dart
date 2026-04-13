import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/shop_provider.dart';
import '../../core/storage_service.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _companyNameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _logoController = TextEditingController();
  final _signatureController = TextEditingController();
  final _authorizedNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _termsController = TextEditingController();
  final _currencySymbolController = TextEditingController(text: '৳');
  final _vatController = TextEditingController(text: '0.0');

  final _purchasePrefixController = TextEditingController(text: 'P-');
  final _purchaseNextNoController = TextEditingController(text: '1');
  final _salePrefixController = TextEditingController(text: 'S-');
  final _saleNextNoController = TextEditingController(text: '1');
  final _returnPrefixController = TextEditingController(text: 'R-');
  final _returnNextNoController = TextEditingController(text: '1');

  bool _isUploadingLogo = false;
  bool _isUploadingSignature = false;

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;

    setState(() {
      if (isLogo) _isUploadingLogo = true;
      else _isUploadingSignature = true;
    });

    try {
      final storage = StorageService(Supabase.instance.client);
      final url = await storage.uploadImage(
        file: File(image.path),
        bucket: 'shop-assets',
        pathPrefix: 'invoices',
      );

      if (url != null) {
        setState(() {
          if (isLogo) _logoController.text = url;
          else _signatureController.text = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) _isUploadingLogo = false;
          else _isUploadingSignature = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().currentShop;
    if (shop != null) {
      _companyNameController.text = shop.name;
      _phoneController.text = shop.phone ?? '';
      _addressController.text = shop.address ?? '';
      
final m = shop.metadata;
      if (m != null) {
        _logoController.text = m['logo_url'] ?? '';
        _signatureController.text = m['signature_url'] ?? '';
        _subtitleController.text = m['subtitle'] ?? '';
        _emailController.text = m['email'] ?? '';
        _authorizedNameController.text = m['authorized_name'] ?? '';
        _designationController.text = m['designation'] ?? '';
        _termsController.text = m['terms'] ?? '';
        _currencySymbolController.text = m['currency'] ?? '৳';
        _vatController.text = m['default_vat']?.toString() ?? '0.0';
        _purchasePrefixController.text = m['purchase_prefix'] ?? 'P-';
        _purchaseNextNoController.text = (m['purchase_next_no'] ?? 1).toString();
        _salePrefixController.text = m['sale_prefix'] ?? 'S-';
        _saleNextNoController.text = (m['sale_next_no'] ?? 1).toString();
        _returnPrefixController.text = m['return_prefix'] ?? 'R-';
        _returnNextNoController.text = (m['return_next_no'] ?? 1).toString();
      }
    }

    // Add listeners for Live Preview
    final controllers = [
      _companyNameController, _subtitleController, _phoneController, 
      _emailController, _addressController, _authorizedNameController, 
      _designationController, _termsController, _currencySymbolController,
      _vatController, _logoController, _signatureController,
      _purchasePrefixController, _salePrefixController, _returnPrefixController
    ];
    for (var c in controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _handleSave() async {
    final shopProvider = context.read<ShopProvider>();
    if (shopProvider.currentShop == null) return;

    try {
      await shopProvider.saveShopSettings(
        name: _companyNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        metadata: {
          'logo_url': _logoController.text.trim(),
          'signature_url': _signatureController.text.trim(),
          'subtitle': _subtitleController.text.trim(),
          'email': _emailController.text.trim(),
          'authorized_name': _authorizedNameController.text.trim(),
          'designation': _designationController.text.trim(),
          'terms': _termsController.text.trim(),
          'currency': _currencySymbolController.text.trim(),
          'default_vat': double.tryParse(_vatController.text) ?? 0.0,
          'purchase_prefix': _purchasePrefixController.text.trim(),
          'purchase_next_no': int.tryParse(_purchaseNextNoController.text) ?? 1,
          'sale_prefix': _salePrefixController.text.trim(),
          'sale_next_no': int.tryParse(_saleNextNoController.text) ?? 1,
          'return_prefix': _returnPrefixController.text.trim(),
          'return_next_no': int.tryParse(_returnNextNoController.text) ?? 1,
        },
      );

      await shopProvider.logActivity(
        action: 'Update Invoice Settings',
        details: {'message': 'Updated company invoice settings and branding'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice settings saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Company Information'),
          _buildImagePicker('Company Logo', _logoController, _isUploadingLogo, true),
          const SizedBox(height: 12),
          _buildField('Company Name *', _companyNameController, icon: LucideIcons.building2),
          const SizedBox(height: 12),
          _buildField('Subtitle', _subtitleController, icon: LucideIcons.type),
          const SizedBox(height: 12),
          _buildField('Phone Number', _phoneController, icon: LucideIcons.phone),
          const SizedBox(height: 12),
          _buildField('Email', _emailController, icon: LucideIcons.mail),
          const SizedBox(height: 12),
          _buildField('Address', _addressController, icon: LucideIcons.mapPin),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Authorized Person'),
          _buildImagePicker('Signature Image', _signatureController, _isUploadingSignature, false),
          const SizedBox(height: 12),
          _buildField('Name', _authorizedNameController, icon: LucideIcons.user),
          const SizedBox(height: 12),
          _buildField('Designation', _designationController, icon: LucideIcons.briefcase),

          const SizedBox(height: 24),
          _buildSectionHeader('Terms & Others'),
          _buildField('Terms and Conditions', _termsController, icon: LucideIcons.fileText, maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildField('Currency Symbol', _currencySymbolController, icon: LucideIcons.coins)),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Default VAT (%)', _vatController, icon: LucideIcons.percent, isNumber: true)),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Invoice Number Settings'),
          _buildPrefixRow('Purchase Invoice', _purchasePrefixController, _purchaseNextNoController, Colors.red),
          const SizedBox(height: 12),
          _buildPrefixRow('Sale Invoice', _salePrefixController, _saleNextNoController, Colors.blue),
          const SizedBox(height: 12),
          _buildPrefixRow('Return Invoice', _returnPrefixController, _returnNextNoController, Colors.purple),
          
          const SizedBox(height: 40),
          _buildSectionHeader('Live Preview'),
          _buildLivePreview(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  static const Color _brandColor = Color(0xFF195243);

  Widget _buildLivePreview() {
    final curr = _currencySymbolController.text.isEmpty ? 'Tk' : _currencySymbolController.text;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Container(
            width: 794,
            height: 1123,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_logoController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Image.network(_logoController.text, height: 60, width: 60, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, size: 60, color: Colors.grey)),
                              ),
                            Text(
                              _companyNameController.text.isEmpty ? 'COMPANY NAME' : _companyNameController.text,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: _brandColor),
                            ),
                            if (_subtitleController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(_subtitleController.text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ),
                            const SizedBox(height: 8),
                            if (_addressController.text.isNotEmpty)
                              Text(_addressController.text, style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)),
                            if (_phoneController.text.isNotEmpty)
                              Text('Phone: ${_phoneController.text}', style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)),
                            if (_emailController.text.isNotEmpty)
                              Text('Email: ${_emailController.text}', style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('INVOICE', style: TextStyle(color: _brandColor, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Text('No: ${_salePrefixController.text}1001', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            Text('Date: ${DateFormat('dd MMM, yyyy').format(DateTime.now())}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Text('SALE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                    
                    // Billing
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('FROM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text(_companyNameController.text.isEmpty ? 'Your Shop Name' : _companyNameController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('TO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          const Text('Sample Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ])),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Table
                    Table(
                      columnWidths: const {0: FixedColumnWidth(40), 1: FlexColumnWidth(5), 2: FixedColumnWidth(60), 3: FlexColumnWidth(2.5), 4: FlexColumnWidth(2.5)},
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: _brandColor),
                          children: [
                            _buildPreviewTableCell('#', isHeader: true, align: TextAlign.center),
                            _buildPreviewTableCell('ITEM ', isHeader: true),
                            _buildPreviewTableCell('QTY', isHeader: true, align: TextAlign.right),
                            _buildPreviewTableCell('UNIT PRICE', isHeader: true, align: TextAlign.right),
                            _buildPreviewTableCell('TOTAL', isHeader: true, align: TextAlign.right),
                          ],
                        ),
                        TableRow(
                          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                          children: [
                            _buildPreviewTableCell('1', align: TextAlign.center),
                            _buildPreviewTableCell('Sample Product Performance Item'),
                            _buildPreviewTableCell('2', align: TextAlign.right),
                            _buildPreviewTableCell('$curr 500.00', align: TextAlign.right),
                            _buildPreviewTableCell('$curr 1,000.00', isBold: true, align: TextAlign.right),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Totals
                    Row(
                      children: [
                        const Spacer(flex: 2),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildPreviewSummaryRow('Subtotal:', '$curr 1,000.00'),
                              if (double.tryParse(_vatController.text) != null && double.parse(_vatController.text) > 0)
                                _buildPreviewSummaryRow('VAT (${_vatController.text}%):', '$curr ${(1000 * double.parse(_vatController.text) / 100).toStringAsFixed(2)}'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _brandColor, width: 2))),
                                child: _buildPreviewSummaryRow('Grand Total:', '$curr ${(1000 + (1000 * (double.tryParse(_vatController.text) ?? 0) / 100)).toStringAsFixed(2)}', isBold: true, fontSize: 16),
                              ),
                              _buildPreviewSummaryRow('Paid:', '$curr ${(1000 + (1000 * (double.tryParse(_vatController.text) ?? 0) / 100)).toStringAsFixed(2)}', color: Colors.green[700]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Footer
                Column(
                  children: [
                    if (_termsController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[200]!)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TERMS & CONDITIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700])),
                              const SizedBox(height: 6),
                              Text(_termsController.text, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment: Cash', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text('Invoiced by: Sample Admin', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandColor)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (_signatureController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Image.network(_signatureController.text, height: 50, width: 120, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 50)),
                              ),
                            Container(
                              width: 150,
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 1))),
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                children: [
                                  Text(_authorizedNameController.text.isEmpty ? 'Authorized Signatory' : _authorizedNameController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  if (_designationController.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(_designationController.text, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Thank you for your business!', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Powered by Papyrus', style: TextStyle(color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTableCell(String text, {bool isHeader = false, bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text, textAlign: align, style: TextStyle(color: isHeader ? Colors.white : Colors.black, fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
    );
  }

  Widget _buildPreviewSummaryRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildImagePicker(String label, TextEditingController controller, bool isUploading, bool isLogo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: isUploading ? null : () => _pickImage(isLogo),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid),
            ),
            child: isUploading 
              ? const Center(child: CircularProgressIndicator())
              : controller.text.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(controller.text, width: double.infinity, height: 120, fit: isLogo ? BoxFit.cover : BoxFit.contain),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.white),
                              onPressed: () => setState(() => controller.clear()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.uploadCloud, size: 32, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      const Text('Tap to upload image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, {required IconData icon, int maxLines = 1, bool isNumber = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildPrefixRow(String label, TextEditingController prefix, TextEditingController nextNo, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: prefix,
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: 'Prefix', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: nextNo,
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: 'Next No.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.receipt, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text('${prefix.text}${nextNo.text.padLeft(2, '0')}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
