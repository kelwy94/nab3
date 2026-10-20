
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/delivery_data.dart';
import '../../models/land_listing.dart';
import '../../providers/auth_provider.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import '../../widgets/land_widgets.dart';
import '../map_picker_screen.dart';

/// Photo in the form: either already saved (url/base64) or newly picked.
class _FormPhoto {
  final String? saved;
  final Uint8List? bytes;
  const _FormPhoto.saved(String this.saved) : bytes = null;
  const _FormPhoto.picked(Uint8List this.bytes) : saved = null;
}

/// Three-step form to list a land for sale, or edit an existing listing.
/// Every submission goes to admin review before it appears in the market.
class LandFormScreen extends StatefulWidget {
  final LandListing? existing;
  const LandFormScreen({super.key, this.existing});

  @override
  State<LandFormScreen> createState() => _LandFormScreenState();
}

class _LandFormScreenState extends State<LandFormScreen> {
  static const _steps = ['المكان', 'التفاصيل', 'الصور والأوراق'];
  int _step = 0;
  bool _saving = false;

  final _stepKeys = List.generate(3, (_) => GlobalKey<FormState>());
  final _titleCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _feddanCtrl = TextEditingController();
  final _qiratCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _district;
  String? _village;
  LatLng? _location;
  bool _negotiable = true;
  String _water = 'well';
  String _legal = 'preliminary';
  String _soil = 'sandy';
  final Set<String> _features = {};
  final List<_FormPhoto> _photos = [];
  final List<_FormPhoto> _docs = [];
  bool _docsLoaded = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _district = kDistricts.contains(e.district) ? e.district : null;
      final villages = kVillagesByDistrict[_district] ?? const [];
      if (villages.contains(e.village)) {
        _village = e.village;
      } else {
        _villageCtrl.text = e.village;
      }
      if (e.hasLocation) _location = LatLng(e.lat!, e.lng!);
      final whole = e.areaFeddan.floor();
      _feddanCtrl.text = whole > 0 ? '$whole' : '';
      final qirat = ((e.areaFeddan - whole) * 24).round();
      _qiratCtrl.text = qirat > 0 ? '$qirat' : '';
      _priceCtrl.text = e.price.toStringAsFixed(0);
      _negotiable = e.negotiable;
      _water = e.waterSource;
      _legal = e.legalStatus;
      _soil = e.soilType;
      _features.addAll(e.features);
      _descCtrl.text = e.description;
      _photos.addAll(e.photos.map(_FormPhoto.saved));
      _docsLoaded = false;
      LandService.ownershipDocs(e.id).then((docs) {
        if (!mounted) return;
        setState(() {
          _docs.addAll(docs.map(_FormPhoto.saved));
          _docsLoaded = true;
        });
      }).catchError((_) {
        if (mounted) setState(() => _docsLoaded = true);
      });
    } else {
      final userDistrict =
          context.read<AuthProvider>().user?.extraData?['district'] as String?;
      if (kDistricts.contains(userDistrict)) _district = userDistrict;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _villageCtrl,
      _feddanCtrl,
      _qiratCtrl,
      _priceCtrl,
      _descCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _area {
    final f = double.tryParse(_feddanCtrl.text.trim()) ?? 0;
    final q = double.tryParse(_qiratCtrl.text.trim()) ?? 0;
    return f + q / 24;
  }

  double get _price =>
      double.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0;

  String get _villageValue =>
      _village ?? _villageCtrl.text.trim();

  // ----------------------------------------------------------------- flow

  void _next() {
    if (!(_stepKeys[_step].currentState?.validate() ?? true)) return;
    if (_step == 0 && _district == null) {
      _toast('اختار المركز');
      return;
    }
    if (_step == 1 && _area <= 0) {
      _toast('اكتب مساحة الأرض');
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      _toast('أضف صورة واحدة على الأقل للأرض');
      return;
    }
    if (!_docsLoaded) {
      _toast('لحظة، جاري تحميل الأوراق...');
      return;
    }
    final user = context.read<AuthProvider>().user!;
    setState(() => _saving = true);
    try {
      final folder = widget.existing?.id ??
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
      final photos = await _upload(_photos, 'land_listings/$folder/photo');
      if (LandService.inlineBytes(photos) > 850 * 1024) {
        throw const _TooLarge();
      }
      final docs = await _upload(_docs, 'land_docs/${user.id}/$folder/doc');

      final listing = LandListing(
        id: widget.existing?.id ?? '',
        ownerId: user.id,
        ownerName: user.fullName,
        title: _titleCtrl.text.trim(),
        governorate: getGovernorateForDistrict(_district!) ?? '',
        district: _district!,
        village: _villageValue,
        lat: _location?.latitude,
        lng: _location?.longitude,
        areaFeddan: _area,
        price: _price,
        negotiable: _negotiable,
        waterSource: _water,
        legalStatus: _legal,
        soilType: _soil,
        features: _features.toList(),
        description: _descCtrl.text.trim(),
        photos: photos,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await LandService.saveListing(listing,
          existingId: widget.existing?.id, ownershipDocs: docs);
      if (!mounted) return;
      await _showSubmitted();
      if (mounted) Navigator.pop(context);
    } on _TooLarge {
      _toast('حجم الصور كبير. قلّل عدد الصور وحاول مرة أخرى',
          color: Colors.orange.shade800);
    } catch (e) {
      debugPrint('Land submit failed: $e');
      _toast('تعذّر حفظ الإعلان، حاول مرة أخرى', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<String>> _upload(List<_FormPhoto> items, String prefix) async {
    final out = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final p = items[i];
      out.add(p.saved ??
          await LandService.uploadImage(p.bytes!, '${prefix}_${stamp}_$i.jpg'));
    }
    return out;
  }

  Future<void> _showSubmitted() => showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 64),
            title: Text(_isEdit ? 'تم حفظ التعديلات' : 'تم إرسال إعلانك'),
            content: const Text(
              'الإدارة هتراجع البيانات والأوراق، وهيظهر الإعلان في سوق الأراضي بعد الموافقة. هيوصلك إشعار أول ما يتنشر.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: NabaTheme.primary,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('تمام'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickPhotos() async {
    final remaining = LandService.maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final files = await ImagePicker()
        .pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 60);
    for (final f in files.take(remaining)) {
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(_FormPhoto.picked(bytes)));
    }
    if (files.length > remaining) {
      _toast('الحد الأقصى ${LandService.maxPhotos} صور');
    }
  }

  Future<void> _pickDoc(ImageSource source) async {
    final f = await ImagePicker().pickImage(
        source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (mounted) setState(() => _docs.add(_FormPhoto.picked(bytes)));
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
          builder: (_) => MapPickerScreen(initialLocation: _location)),
    );
    if (picked != null) setState(() => _location = picked);
  }

  // --------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: _step == 0 && !_saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_saving) _back();
        },
        child: Scaffold(
          backgroundColor: NabaTheme.background,
          appBar: AppBar(
            title: Text(_isEdit ? 'تعديل إعلان الأرض' : 'اعرض أرضك للبيع'),
          ),
          body: Column(
            children: [
              _progressHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Form(
                      key: _stepKeys[_step],
                      child: switch (_step) {
                        0 => _placeStep(),
                        1 => _detailsStep(),
                        _ => _photosStep(),
                      },
                    ),
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? NabaTheme.primary
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: i < _step
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: i <= _step
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_steps[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            i == _step ? FontWeight.bold : FontWeight.normal,
                        color: i <= _step
                            ? NabaTheme.primary
                            : NabaTheme.textSecondary,
                      )),
                ],
              ),
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: i < _step ? NabaTheme.primary : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4)),
      ]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _back,
                  child: const Text('رجوع'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NabaTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step < 2
                            ? 'التالي'
                            : (_isEdit ? 'حفظ وإرسال للمراجعة' : 'نشر الإعلان'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- steps

  Widget _placeStep() {
    final villages = kVillagesByDistrict[_district] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card('عنوان الإعلان', [
          TextFormField(
            controller: _titleCtrl,
            maxLength: 80,
            decoration: _input('مثال: أرض 10 فدان على الطريق الرئيسي',
                icon: Icons.title_rounded),
            validator: (v) => (v == null || v.trim().length < 5)
                ? 'اكتب عنوان واضح (5 حروف على الأقل)'
                : null,
          ),
        ]),
        _card('مكان الأرض', [
          DropdownButtonFormField<String>(
            value: _district,
            decoration: _input('المركز', icon: Icons.location_city_rounded),
            items: kDistricts
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() {
              _district = v;
              _village = null;
            }),
          ),
          const SizedBox(height: 12),
          if (villages.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _village,
              decoration: _input('القرية', icon: Icons.holiday_village_rounded),
              items: villages
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _village = v),
              validator: (v) => v == null ? 'اختار القرية' : null,
            )
          else
            TextFormField(
              controller: _villageCtrl,
              decoration: _input('القرية أو المنطقة',
                  icon: Icons.holiday_village_rounded),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم المنطقة' : null,
            ),
        ]),
        _card('الموقع على الخريطة', [
          InkWell(
            onTap: _pickLocation,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _location != null
                    ? Colors.green.withOpacity(0.06)
                    : NabaTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _location != null
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _location != null
                        ? Icons.where_to_vote_rounded
                        : Icons.add_location_alt_rounded,
                    color: _location != null ? Colors.green : NabaTheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _location != null
                                ? 'تم تحديد الموقع'
                                : 'حدد مكان الأرض (اختياري)',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _location != null
                              ? 'اضغط لتغيير الموقع'
                              : 'الإعلانات اللي عليها موقع بتجيب اهتمام أكتر',
                          style: const TextStyle(
                              fontSize: 12, color: NabaTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_location != null)
                    IconButton(
                      onPressed: () => setState(() => _location = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _detailsStep() {
    final area = _area;
    final price = _price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card('المساحة', [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _feddanCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: _input('فدان', icon: Icons.straighten_rounded),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _qiratCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: _input('قيراط'),
                  validator: (v) {
                    final q = int.tryParse(v ?? '') ?? 0;
                    return q > 23 ? 'أقل من 24' : null;
                  },
                ),
              ),
            ],
          ),
          if (area > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('إجمالي المساحة: ${formatLandArea(area)}',
                  style: const TextStyle(color: NabaTheme.primary)),
            ),
        ]),
        _card('السعر', [
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: _input('السعر الإجمالي بالجنيه',
                icon: Icons.payments_rounded),
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                ? 'اكتب السعر'
                : null,
          ),
          if (price > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                area > 0
                    ? '${formatLandPrice(price)} • ${formatLandPrice(price / area)} للفدان'
                    : formatLandPrice(price),
                style: const TextStyle(
                    color: NabaTheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _negotiable,
            activeColor: NabaTheme.primary,
            title: const Text('السعر قابل للتفاوض'),
            onChanged: (v) => setState(() => _negotiable = v),
          ),
        ]),
        _card('مصدر المياه', [
          _choices(LandOptions.waterSources, _water,
              (v) => setState(() => _water = v),
              icons: kWaterIcons),
        ]),
        _card('الوضع القانوني', [
          _choices(LandOptions.legalStatuses, _legal,
              (v) => setState(() => _legal = v)),
        ]),
        _card('نوع التربة', [
          _choices(LandOptions.soilTypes, _soil,
              (v) => setState(() => _soil = v)),
        ]),
        _card('المميزات', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in LandOptions.features.entries)
                FilterChip(
                  avatar: Icon(kLandFeatureIcons[e.key], size: 18),
                  label: Text(e.value),
                  selected: _features.contains(e.key),
                  selectedColor: NabaTheme.primary.withOpacity(0.15),
                  checkmarkColor: NabaTheme.primary,
                  showCheckmark: false,
                  onSelected: (sel) => setState(() =>
                      sel ? _features.add(e.key) : _features.remove(e.key)),
                ),
            ],
          ),
        ]),
        _card('وصف إضافي', [
          TextFormField(
            controller: _descCtrl,
            maxLines: 4,
            maxLength: 600,
            decoration: _input(
                'مثال: الأرض مستصلحة، قريبة من الطريق، بها 3 صوب...'),
          ),
        ]),
      ],
    );
  }

  Widget _photosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card('صور الأرض', [
          const Text(
            'أول صورة هي الغلاف. صوّر الأرض في النهار ومن أكتر من زاوية.',
            style: TextStyle(color: NabaTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _imageGrid(
            _photos,
            max: LandService.maxPhotos,
            onAdd: _pickPhotos,
            addLabel: 'إضافة صور',
            coverFirst: true,
          ),
        ]),
        _card('أوراق الملكية (سرية)', [
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'محدش هيشوفها غيرك وإدارة نبع، وبتستخدم بس للتأكد إن الأرض بتاعتك.',
                  style:
                      TextStyle(color: NabaTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_docsLoaded)
            const Center(child: CircularProgressIndicator())
          else
            _imageGrid(
              _docs,
              max: LandService.maxOwnershipDocs,
              onAdd: () => _showDocSourceSheet(),
              addLabel: 'صورة العقد',
            ),
        ]),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NabaTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.fact_check_rounded, color: NabaTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'كل الإعلانات بتتراجع من الإدارة قبل النشر علشان السوق يفضل موثوق.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDocSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('تصوير بالكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pickDoc(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickDoc(ImageSource.gallery);
              },
            ),
          ]),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- pieces

  Widget _imageGrid(
    List<_FormPhoto> items, {
    required int max,
    required VoidCallback onAdd,
    required String addLabel,
    bool coverFirst = false,
  }) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (var i = 0; i < items.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                items[i].bytes != null
                    ? Image.memory(items[i].bytes!, fit: BoxFit.cover)
                    : LandImage(items[i].saved),
                if (coverFirst && i == 0)
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
                    onTap: () => setState(() => items.removeAt(i)),
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
        if (items.length < max)
          InkWell(
            onTap: onAdd,
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
                  Text(addLabel,
                      style: const TextStyle(
                          fontSize: 11, color: NabaTheme.primary)),
                  Text('${items.length}/$max',
                      style: const TextStyle(
                          fontSize: 10, color: NabaTheme.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _choices(Map<String, String> options, String selected,
      ValueChanged<String> onSelect,
      {Map<String, IconData>? icons}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            avatar: icons?[e.key] != null
                ? Icon(icons![e.key], size: 18,
                    color: selected == e.key
                        ? NabaTheme.primary
                        : NabaTheme.textSecondary)
                : null,
            label: Text(e.value),
            selected: selected == e.key,
            showCheckmark: false,
            selectedColor: NabaTheme.primary.withOpacity(0.15),
            labelStyle: TextStyle(
              color: selected == e.key
                  ? NabaTheme.primary
                  : NabaTheme.textPrimary,
              fontWeight:
                  selected == e.key ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => onSelect(e.key),
          ),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  InputDecoration _input(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        fillColor: NabaTheme.background,
        counterText: '',
      );
}

class _TooLarge implements Exception {
  const _TooLarge();
}
