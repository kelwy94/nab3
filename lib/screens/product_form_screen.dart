import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/product_categories.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/image_upload.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../widgets/smart_image.dart';

/// Photo in the form: either already saved (url/base64) or newly picked.
class _Photo {
  final String? saved;
  final Uint8List? bytes;
  const _Photo.saved(String this.saved) : bytes = null;
  const _Photo.picked(Uint8List this.bytes) : saved = null;
}

/// Add or edit a marketplace product. Fields adapt to the chosen category:
/// supplies get unit/quantity, machinery gets condition and specs and is
/// sold per piece with an optional negotiable price.
class ProductFormScreen extends StatefulWidget {
  final CatalogItem? product;

  /// Preselects a category for a new product (e.g. from "sell your machine").
  final String? initialCategory;

  const ProductFormScreen({super.key, this.product, this.initialCategory});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _maxPhotos = 6;
  static const _customUnit = 'أخرى';

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _customUnitCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController(text: '1');
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Map<String, TextEditingController> _specCtrls = {
    for (final k in kMachinerySpecs.keys) k: TextEditingController(),
  };

  late ProductCategory _category;
  String _unit = '';
  String _condition = kProductConditions.first;
  bool _negotiable = false;
  bool _inStock = true;
  bool _deliveryAvailable = false;
  bool _saving = false;
  final List<_Photo> _photos = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _category = categoryByName(p.category);
      _nameCtrl.text = p.name;
      _priceCtrl.text = _trimNum(p.price);
      if (p.discountPercentage > 0) {
        _discountCtrl.text = _trimNum(p.discountPercentage);
      }
      if (_category.units.contains(p.unit)) {
        _unit = p.unit;
      } else if (p.unit.isNotEmpty) {
        _unit = _customUnit;
        _customUnitCtrl.text = p.unit;
      }
      if (p.quantity > 0) _quantityCtrl.text = _trimNum(p.quantity);
      _minOrderCtrl.text = _trimNum(p.minOrderQuantity);
      _addressCtrl.text = p.address;
      _descCtrl.text = p.description ?? '';
      _condition = kProductConditions.contains(p.condition)
          ? p.condition
          : (isUsedCondition(p.condition) ? 'مستعمل - جيد' : 'جديد');
      _negotiable = p.negotiable;
      _inStock = p.stockStatus;
      _deliveryAvailable = p.deliveryAvailable;
      p.specs.forEach((k, v) => _specCtrls[k]?.text = v);
      _photos.addAll(p.allPhotos.map(_Photo.saved));
    } else {
      _category = categoryByName(widget.initialCategory ?? 'بذور');
      final extra = context.read<AuthProvider>().user?.extraData;
      _addressCtrl.text = [extra?['village'], extra?['district']]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join('، ');
    }
    if (_unit.isEmpty) _unit = _category.units.first;
    if (_category.isMachinery && !_isEdit) _negotiable = true;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _priceCtrl,
      _discountCtrl,
      _customUnitCtrl,
      _quantityCtrl,
      _minOrderCtrl,
      _addressCtrl,
      _descCtrl,
      ..._specCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _selectCategory(ProductCategory c) {
    setState(() {
      _category = c;
      if (!c.units.contains(_unit) && _unit != _customUnit) {
        _unit = c.units.first;
      }
      if (!c.showCondition) _condition = kProductConditions.first;
      if (c.isMachinery) {
        _negotiable = true;
        _deliveryAvailable = false;
      }
    });
  }

  // ---------------------------------------------------------------- photos

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    try {
      final files = await ImagePicker()
          .pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 65);
      for (final f in files.take(remaining)) {
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        setState(() => _photos.add(_Photo.picked(bytes)));
      }
      if (files.length > remaining && mounted) {
        _toast('الحد الأقصى $_maxPhotos صور');
      }
    } catch (e) {
      debugPrint('Pick photos failed: $e');
    }
  }

  // ---------------------------------------------------------------- submit

  void _toast(String msg, {Color? color}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      _toast('أضف صورة واحدة على الأقل للمنتج');
      return;
    }
    final unit = _category.isMachinery
        ? 'قطعة'
        : (_unit == _customUnit ? _customUnitCtrl.text.trim() : _unit);
    if (unit.isEmpty) {
      _toast('اكتب الوحدة');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final isApproved =
          user.role == UserRole.seller || user.role == UserRole.admin;
      final productId = widget.product?.id ??
          'new_${DateTime.now().millisecondsSinceEpoch}';
      final folder = _isEdit ? productId : '${user.id}_$productId';

      final urls = <String>[];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        urls.add(p.saved ??
            await uploadImageOrInline(
                p.bytes!, 'products/$folder/img_${stamp}_$i.jpg'));
      }

      final specs = <String, String>{
        if (_category.isMachinery)
          for (final e in _specCtrls.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      };

      final item = CatalogItem(
        id: productId,
        sellerUserId: user.id,
        name: _nameCtrl.text.trim(),
        category: _category.name,
        unit: unit,
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        stockStatus: _inStock,
        photoUrl: urls.first,
        additionalPhotos: urls.skip(1).toList(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isApproved: isApproved,
        discountPercentage: _category.isMachinery
            ? 0
            : (double.tryParse(_discountCtrl.text.trim()) ?? 0),
        quantity: _category.isMachinery
            ? 1
            : (double.tryParse(_quantityCtrl.text.trim()) ?? 0),
        minOrderQuantity: _category.isMachinery
            ? 1
            : (double.tryParse(_minOrderCtrl.text.trim()) ?? 1),
        address: _addressCtrl.text.trim(),
        condition: _category.showCondition ? _condition : 'جديد',
        deliveryAvailable: _deliveryAvailable,
        negotiable: _negotiable,
        specs: specs,
      );
      await context.read<CatalogProvider>().addOrUpdateProduct(item);
      if (!mounted) return;
      Navigator.pop(context);
      _toast(isApproved
          ? 'تم حفظ المنتج بنجاح'
          : 'تم الإرسال، وهيظهر في السوق بعد مراجعة الإدارة.');
    } catch (e) {
      debugPrint('Save product failed: $e');
      if (mounted) _toast('تعذّر حفظ المنتج، حاول مرة أخرى', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المنتج'),
          content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<CatalogProvider>().deleteProduct(widget.product!.id);
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final c = _category;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabaTheme.background,
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل المنتج' : 'بيعة جديدة'),
          leading: const NabaBackButton(),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _section('نوع المنتج', [_categoryTile()]),
              _section('الصور', [
                Text(
                  c.isMachinery
                      ? 'صوّر المعدة من كل الجهات، والعداد ورقم الموديل لو موجودين.'
                      : 'أول صورة هي الغلاف اللي هيظهر في السوق.',
                  style: const TextStyle(
                      color: NabaTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _photoGrid(),
              ]),
              _section('البيانات الأساسية', [
                TextFormField(
                  controller: _nameCtrl,
                  maxLength: 80,
                  decoration: _input('اسم المنتج',
                      hint: c.nameHint, icon: Icons.label_rounded),
                  validator: (v) =>
                      (v ?? '').trim().length < 3 ? 'اكتب اسم واضح' : null,
                ),
                if (c.showCondition) ...[
                  const SizedBox(height: 8),
                  const Text('الحالة',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _chips(kProductConditions, _condition,
                      (v) => setState(() => _condition = v)),
                ],
              ]),
              if (c.isMachinery)
                _section('مواصفات المعدة', [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: [
                      for (final e in kMachinerySpecs.entries)
                        TextFormField(
                          controller: _specCtrls[e.key],
                          keyboardType: e.key == 'brand' || e.key == 'model'
                              ? TextInputType.text
                              : TextInputType.number,
                          inputFormatters: e.key == 'brand' || e.key == 'model'
                              ? null
                              : [FilteringTextInputFormatter.digitsOnly],
                          decoration: _input(e.value),
                        ),
                    ],
                  ),
                ]),
              _section('السعر', [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        decoration: _input(
                            c.isMachinery ? 'السعر (ج.م)' : 'السعر للوحدة (ج.م)',
                            icon: Icons.payments_rounded),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'اكتب السعر'
                            : null,
                      ),
                    ),
                    if (!c.isMachinery) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _discountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _input('خصم %'),
                          validator: (v) =>
                              (int.tryParse(v ?? '') ?? 0) > 90 ? 'كبير' : null,
                        ),
                      ),
                    ],
                  ],
                ),
                if (c.isMachinery || isUsedCondition(_condition))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _negotiable,
                    activeColor: NabaTheme.primary,
                    title: const Text('السعر قابل للتفاوض'),
                    onChanged: (v) => setState(() => _negotiable = v),
                  ),
              ]),
              if (!c.isMachinery)
                _section('الكمية والوحدة', [
                  const Text('الوحدة',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _chips([...c.units, _customUnit], _unit,
                      (v) => setState(() => _unit = v)),
                  if (_unit == _customUnit) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customUnitCtrl,
                      decoration: _input('اكتب الوحدة', hint: 'مثال: جركن'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _input('الكمية المتاحة'),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                              ? 'مطلوب'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _minOrderCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _input('أقل كمية للطلب'),
                        ),
                      ),
                    ],
                  ),
                ]),
              _section('المكان والتفاصيل', [
                TextFormField(
                  controller: _addressCtrl,
                  decoration: _input('مكان المنتج',
                      hint: 'القرية، المركز', icon: Icons.location_on_rounded),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'اكتب المكان' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 600,
                  decoration: _input('الوصف',
                      hint: c.isMachinery
                          ? 'حالة الموتور، الصيانات اللي اتعملت، سبب البيع...'
                          : 'المواصفات، طريقة الاستخدام، تاريخ الصلاحية...'),
                ),
              ]),
              _section('خيارات', [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _inStock,
                  activeColor: NabaTheme.primary,
                  title: Text(c.isMachinery ? 'متاح للبيع' : 'متوفر في المخزن'),
                  onChanged: (v) => setState(() => _inStock = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _deliveryAvailable,
                  activeColor: NabaTheme.primary,
                  title: Text(c.isMachinery ? 'أقدر أنقلها للمشتري' : 'يتوفر توصيل'),
                  onChanged: (v) => setState(() => _deliveryAvailable = v),
                ),
              ]),
              const SizedBox(height: 8),
              NabaButton(
                text: _saving
                    ? 'جاري الحفظ...'
                    : (_isEdit ? 'حفظ التعديلات' : 'نشر المنتج'),
                onPressed: _saving ? null : _submit,
                icon: Icons.check_circle_rounded,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المنتج'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pieces

  Widget _categoryTile() {
    final c = _category;
    return InkWell(
      onTap: _showCategorySheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NabaTheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NabaTheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: NabaTheme.primary, shape: BoxShape.circle),
              child: Icon(c.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(c.group,
                      style: const TextStyle(
                          color: NabaTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Text('تغيير',
                style: TextStyle(
                    color: NabaTheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('بتبيع إيه؟',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              for (final group in ProductGroups.all) ...[
                const SizedBox(height: 16),
                Text(group,
                    style: const TextStyle(
                        color: NabaTheme.textSecondary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.15,
                  children: [
                    for (final c
                        in kProductCategories.where((c) => c.group == group))
                      _categoryOption(ctx, c),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryOption(BuildContext sheetCtx, ProductCategory c) {
    final selected = c.name == _category.name;
    return Material(
      color: selected ? NabaTheme.primary : NabaTheme.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(sheetCtx);
          _selectCategory(c);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(c.icon,
                  color: selected ? Colors.white : NabaTheme.primary, size: 28),
              const SizedBox(height: 6),
              Text(c.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : NabaTheme.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (var i = 0; i < _photos.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _photos[i].bytes != null
                    ? Image.memory(_photos[i].bytes!, fit: BoxFit.cover)
                    : SmartImage(_photos[i].saved),
                if (i == 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: NabaTheme.primary.withOpacity(0.85),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: const Text('الغلاف',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_photos.length < _maxPhotos)
          InkWell(
            onTap: _pickPhotos,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: NabaTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: NabaTheme.primary.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded,
                      color: NabaTheme.primary),
                  const SizedBox(height: 4),
                  Text('إضافة صور ${_photos.length}/$_maxPhotos',
                      style: const TextStyle(
                          fontSize: 11, color: NabaTheme.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _chips(
          List<String> options, String selected, ValueChanged<String> onTap) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o),
              selected: selected == o,
              showCheckmark: false,
              selectedColor: NabaTheme.primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color:
                    selected == o ? NabaTheme.primary : NabaTheme.textPrimary,
                fontWeight:
                    selected == o ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onTap(o),
            ),
        ],
      );

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  InputDecoration _input(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        fillColor: NabaTheme.background,
        counterText: '',
      );
}
