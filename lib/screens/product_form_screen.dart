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
import 'package:firebase_storage/firebase_storage.dart';

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
  late TextEditingController _discountController;
  late TextEditingController _unitController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _addressController;
  late TextEditingController _minOrderController;

  String _selectedCategory = 'بذور';
  String _selectedCondition = 'جديد';
  bool _inStock = true;
  bool _deliveryAvailable = false;
  bool _isLoading = false;

  Uint8List? _mainImageBytes;
  final List<Uint8List> _additionalImageBytes = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'بذور', 'أسمدة', 'مبيدات', 'معدات ري', 'أدوات زراعية',
    'معدات وآلات زراعية', 'شتلات ونباتات', 'تربة وخامات',
    'أعلاف وتغذية حيوانية', 'منتجات عضوية', 'أدوات ري بالتنقيط',
    'أدوات يدوية زراعية', 'منتجات حيوانية', 'أجهزة وقياس',
    'خدمات زراعية', 'مواد تعبئة وتغليف', 'أخرى',
  ];

  final List<String> _conditions = ['جديد', 'مستعمل - ممتاز', 'مستعمل - جيد', 'مستعمل'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _discountController = TextEditingController(
        text: (p?.discountPercentage != null && p!.discountPercentage > 0)
            ? p.discountPercentage.toStringAsFixed(0) : '');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _quantityController = TextEditingController(
        text: p?.quantity != null && p!.quantity > 0 ? p.quantity.toStringAsFixed(0) : '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _minOrderController = TextEditingController(
        text: p?.minOrderQuantity != null ? p!.minOrderQuantity.toStringAsFixed(0) : '1');
    _selectedCategory = p?.category ?? 'بذور';
    _selectedCondition = p?.condition ?? 'جديد';
    _inStock = p?.stockStatus ?? true;
    _deliveryAvailable = p?.deliveryAvailable ?? false;
    if (p?.photoUrl != null && p!.photoUrl!.isNotEmpty) {
      try { _mainImageBytes = base64Decode(p.photoUrl!); } catch (_) {}
    }
    if (p?.additionalPhotos != null) {
      for (final photo in p!.additionalPhotos) {
        try { _additionalImageBytes.add(base64Decode(photo)); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickMainImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) setState(() async => _mainImageBytes = await file.readAsBytes());
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _pickAdditionalImage() async {
    if (_additionalImageBytes.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى 5 صور إضافية')));
      return;
    }
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _additionalImageBytes.add(bytes));
      }
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<String> _uploadImage(Uint8List bytes, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      // Fallback to base64 if Firebase Storage fails/is unconfigured temporarily
      return base64Encode(bytes);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if main image exists (either loaded from product or newly picked)
    final hasMainImage = _mainImageBytes != null || (widget.product != null && widget.product!.photoUrl != null && widget.product!.photoUrl!.isNotEmpty);
    if (!hasMainImage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إضافة صورة رئيسية للمنتج')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final bool isApproved = user.role == UserRole.seller || user.role == UserRole.admin;
      final productId = widget.product?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
      
      // Upload Main Image
      String? mainImageUrl = widget.product?.photoUrl;
      if (_mainImageBytes != null) {
        final path = 'products/$productId/main_${DateTime.now().millisecondsSinceEpoch}.jpg';
        mainImageUrl = await _uploadImage(_mainImageBytes!, path);
      }

      // Upload Additional Images
      List<String> additionalUrls = widget.product?.additionalPhotos ?? [];
      if (_additionalImageBytes.isNotEmpty) {
        List<String> uploadedUrls = [];
        for (int i = 0; i < _additionalImageBytes.length; i++) {
          final path = 'products/$productId/add_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final url = await _uploadImage(_additionalImageBytes[i], path);
          uploadedUrls.add(url);
        }
        // In this simple flow, we append or replace. For simplicity, we just use the new ones if we picked them.
        // If we want to append, we can do additionalUrls.addAll(uploadedUrls). Let's just use uploaded if not empty.
        additionalUrls = uploadedUrls;
      }

      final item = CatalogItem(
        id: productId,
        sellerUserId: user.id,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        unit: _unitController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0.0,
        stockStatus: _inStock,
        photoUrl: mainImageUrl,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        isApproved: isApproved,
        discountPercentage: double.tryParse(_discountController.text) ?? 0.0,
        additionalPhotos: additionalUrls,
        quantity: double.tryParse(_quantityController.text) ?? 0.0,
        address: _addressController.text.trim(),
        condition: _selectedCondition,
        minOrderQuantity: double.tryParse(_minOrderController.text) ?? 1.0,
        deliveryAvailable: _deliveryAvailable,
      );
      await context.read<CatalogProvider>().addOrUpdateProduct(item);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isApproved ? 'تم حفظ المنتج بنجاح.' : 'تم الإرسال، سيظهر بعد مراجعة الإدارة.'),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _label(String text, {bool req = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      if (req) const Text('* ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: NabaTheme.textPrimary)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ─── Custom Header ─────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EBE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF265B33), size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('السوق', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF265B33),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('بيعة جديدة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Colors.grey.shade100),

              // ─── Scrollable Form ────────────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [

                      // Main Image
                      _label('الصورة الرئيسية للمنتج', req: true),
                      GestureDetector(
                        onTap: _pickMainImage,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: _mainImageBytes == null ? Colors.red.shade200 : NabaTheme.primary,
                                width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _mainImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(_mainImageBytes!, fit: BoxFit.cover, width: double.infinity),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text('اضغط لإضافة صورة رئيسية', style: TextStyle(color: Colors.grey.shade500)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Additional Images
                      _label('صور إضافية (حتى 5 صور)'),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._additionalImageBytes.asMap().entries.map((entry) => Stack(
                              children: [
                                Container(
                                  width: 85, height: 85,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.memory(entry.value, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 2, left: 10,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _additionalImageBytes.removeAt(entry.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                            if (_additionalImageBytes.length < 5)
                              GestureDetector(
                                onTap: _pickAdditionalImage,
                                child: Container(
                                  width: 85, height: 85,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, color: NabaTheme.primary, size: 30),
                                      Text('إضافة\n(${_additionalImageBytes.length}/5)',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10, color: NabaTheme.primary)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name
                      _label('اسم المنتج', req: true),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(hintText: 'مثال: قمح محلي'),
                        validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      _label('الفئة', req: true),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v!),
                        decoration: const InputDecoration(),
                      ),
                      const SizedBox(height: 16),

                      // Condition
                      _label('حالة المنتج'),
                      DropdownButtonFormField<String>(
                        value: _selectedCondition,
                        isExpanded: true,
                        items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCondition = v!),
                        decoration: const InputDecoration(),
                      ),
                      const SizedBox(height: 16),

                      // Price + Discount
                      Row(
                        children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('السعر (ج.م)', req: true),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: '0.00'),
                                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                              ),
                            ],
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('نسبة الخصم (%)'),
                              TextFormField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'مثال: 10'),
                              ),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Unit + Quantity
                      Row(
                        children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('الوحدة', req: true),
                              TextFormField(
                                controller: _unitController,
                                decoration: const InputDecoration(hintText: 'كجم، عبوة...'),
                                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                              ),
                            ],
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('الكمية المتاحة', req: true),
                              TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'مثال: 100'),
                                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                              ),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Min Order
                      _label('أقل كمية للطلب'),
                      TextFormField(
                        controller: _minOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'مثال: 5'),
                      ),
                      const SizedBox(height: 16),

                      // Address
                      _label('عنوان / موقع المنتج', req: true),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(hintText: 'مثال: القاهرة، التبين'),
                        validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _label('وصف ومواصفات المنتج'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'وصف المنتج، مواصفاته واستخداماته'),
                      ),
                      const SizedBox(height: 16),

                      // Toggles
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('متوفر في المخزن'),
                              value: _inStock,
                              onChanged: (v) => setState(() => _inStock = v),
                              activeColor: NabaTheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('يتوفر توصيل'),
                              subtitle: const Text('هل تقدم خدمة توصيل للمنتج؟'),
                              value: _deliveryAvailable,
                              onChanged: (v) => setState(() => _deliveryAvailable = v),
                              activeColor: NabaTheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit
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
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              await context.read<CatalogProvider>().deleteProduct(widget.product!.id);
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف المنتج'),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
