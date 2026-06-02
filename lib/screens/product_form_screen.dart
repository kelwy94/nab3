import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/catalog_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class ProductFormScreen extends StatefulWidget {
  final CatalogItem? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  String _selectedCategory = 'بذور وأسمدة';
  bool _inStock = true;
  bool _isLoading = false;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'بذور وأسمدة',
    'معدات ري',
    'أدوات زراعية',
    'مبيدات',
    'أخرى'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController =
        TextEditingController(text: widget.product?.price.toString() ?? '');
    _unitController = TextEditingController(text: widget.product?.unit ?? '');
    _selectedCategory = widget.product?.category ?? 'بذور وأسمدة';
    _inStock = widget.product?.stockStatus ?? true;
    if (widget.product?.photoUrl != null) {
      try {
        _imageBytes = base64Decode(widget.product!.photoUrl!);
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final sellerId = context.read<AuthProvider>().user!.id;
        String? base64Image;
        if (_imageBytes != null) {
          base64Image = base64Encode(_imageBytes!);
        }

        final item = CatalogItem(
          id: widget.product?.id ??
              'new_${DateTime.now().millisecondsSinceEpoch}',
          sellerUserId: sellerId,
          name: _nameController.text,
          category: _selectedCategory,
          unit: _unitController.text,
          price: double.parse(_priceController.text),
          stockStatus: _inStock,
          photoUrl: base64Image,
        );

        await context.read<CatalogProvider>().addOrUpdateProduct(item);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      image: _imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _imageBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text('أضف صورة',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildFieldLabel('اسم المنتج'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'مثلاً: قمح محلي'),
                validator: (v) => v!.isEmpty ? 'مطلب' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('الفئة'),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildFieldLabel('السعر (ج.م)'),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0.00'),
                          validator: (v) => v!.isEmpty ? 'مطلب' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildFieldLabel('الوحدة'),
                        TextFormField(
                          controller: _unitController,
                          decoration:
                              const InputDecoration(hintText: 'كجم، عبوة، إلخ'),
                          validator: (v) => v!.isEmpty ? 'مطلب' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('متوفر في المخزن',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                value: _inStock,
                activeThumbColor: NabaTheme.primary,
                onChanged: (v) => setState(() => _inStock = v),
              ),
              const SizedBox(height: 32),
              NabaButton(
                text: _isLoading ? 'جاري الحفظ...' : 'حفظ المنتج',
                onPressed: _isLoading ? null : _submit,
                icon: Icons.save_rounded,
              ),
              if (widget.product != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف المنتج'),
                        content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('إلغاء')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (mounted) {
                        await context
                            .read<CatalogProvider>()
                            .deleteProduct(widget.product!.id);
                      }
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('حذف المنتج من المتجر'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4),
      child: Text(
        label,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: NabaTheme.textPrimary),
        textAlign: TextAlign.right,
      ),
    );
  }
}
