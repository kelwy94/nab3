import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class SignupScreen extends StatefulWidget {
  final UserRole role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // -- Step 1: Personal Info --
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nationalIdController = TextEditingController();

  Uint8List? _profileImageBytes;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  final ImagePicker _picker = ImagePicker();

  // -- Step 2: Location --
  String? _selectedGovernorate;
  String? _selectedDistrict;
  String? _selectedVillage;
  final _addressController = TextEditingController();
  LatLng? _selectedLocation;

  // -- Step 3: Role Specifics --
  // Worker
  final Set<String> _selectedWorkerSpecializations = {};
  String? _workerType; // 'عامل' or 'فني'

  // Engineer
  String? _selectedEngineerSpecialization;
  final Set<String> _selectedEngineerFieldWork = {};
  final _experienceYearsController = TextEditingController();
  final _aboutMeController = TextEditingController();
  Uint8List? _certificateBytes;

  // Equipment Owner
  String? _selectedEquipmentType;
  final _equipmentModelController = TextEditingController();
  final _equipmentRateController = TextEditingController();
  String _pricingUnit = 'ساعة';
  final Set<String> _selectedAttachments = {};

  // Farmer
  final _landAreaController = TextEditingController();
  final _cropsController = TextEditingController();
  final _irrigationTypeController = TextEditingController();

  // Delivery / Seller extra controllers
  final _extra1Controller = TextEditingController(); // ShopName, Delivery Model
  final _extra2Controller = TextEditingController(); // CommReg, Avg Price
  String? _selectedCategory; // category for seller / delivery
  String? _selectedVehicleType;

  // Data Lookups
  final List<String> _governorates = ['الوادي الجديد'];
  final List<String> _districts = [
    'الفرافرة',
    'الداخلة',
    'بلاط',
    'الخارجة',
    'باريس'
  ];

  final List<String> _farafraVillages = [
    'مدينة الفرافرة',
    'النهضة',
    'اللواء صبيح',
    'عثمان بن عفان',
    'ابوبكر الصديق',
    'الرواد',
    'خالد بن الوليد',
    'ابو هريرة',
    'ابو منقار'
  ];
  final List<String> _dakhlaVillages = [
    'مدينة موط',
    'غرب الموهوب',
    'الموهوب',
    'القصر',
    'عزب القصر',
    'بدخلو',
    'الراشدة',
    'الدهوس',
    'الهنداو'
  ];

  final List<String> _technicianSpecializations = [
    'فني نخيل',
    'فني تركيب طاقة شمسية',
  ];

  final List<String> _engineerSpecializations = [
    'مهندس زراعي',
    'مهندس ميكانيكا',
    'مهندس ري',
    'مهندس كهرباء',
  ];

  final Map<String, List<String>> _engineerFieldWorkMap = {
    'مهندس زراعي': [
      'نخيل',
      'أعلاف ومحاصيل حقلية',
      'مكافحة آفات وأمراض',
      'بساتين وفاكهة',
      'صوب وزراعة محمية'
    ],
    'مهندس ميكانيكا': [
      'صيانة معدات ثقيلة (لوادر، حفارات)',
      'صيانة جرارات زراعية',
      'صيانة محركات الديزل',
      'ميكانيكا محطات ضخ'
    ],
    'مهندس ري': [
      'تصميم شبكات تنقيط/رش',
      'تركيب وصيانة بيفوتات',
      'حفر وإدارة آبار المياه',
      'صيانة طلمبات ومضخات غاطسة'
    ],
    'مهندس كهرباء': [
      'تركيب وصيانة محطات طاقة شمسية',
      'تصميم وصيانة لوحات تحكم (كنترول)',
      'صيانة مولدات كهربائية',
      'شبكات التوصيل للآبار'
    ],
  };

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _experienceYearsController.dispose();
    _aboutMeController.dispose();
    _equipmentModelController.dispose();
    _equipmentRateController.dispose();
    _landAreaController.dispose();
    _cropsController.dispose();
    _irrigationTypeController.dispose();
    _extra1Controller.dispose();
    _extra2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile,
      {bool isFrontId = false, bool isCertificate = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (isProfile)
            _profileImageBytes = bytes;
          else if (isCertificate)
            _certificateBytes = bytes;
          else if (isFrontId)
            _idFrontBytes = bytes;
          else
            _idBackBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  String _getRoleTitle() {
    switch (widget.role) {
      case UserRole.farmer:
        return 'تسجيل كمزارع';
      case UserRole.worker:
        return 'تسجيل كعامل';
      case UserRole.engineer:
        return 'تسجيل كمهندس/استشاري';
      case UserRole.equipmentOwner:
        return 'تسجيل كصاحب معدة';
      case UserRole.seller:
        return 'تسجيل كتاجر/מورد';
      case UserRole.deliveryWorker:
        return 'تسجيل كمسؤول توصيل';
      default:
        return 'إنشاء حساب جديد';
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate step 1 manually or via GlobalKey if fields are inside
      if (_nameController.text.isEmpty ||
          _phoneController.text.length != 11 ||
          _passwordController.text.isEmpty ||
          _nationalIdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'يرجى تعبئة كافة الحقول في هذه الصفحة بشكل صحيح. تأكد من أن رقم الجوال 11 رقم.'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
      setState(() => _currentStep--);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idFrontBytes == null || _idBackBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('صور البطاقة (الوجهين) مطلوبة للتحقق من هويتك'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      Map<String, dynamic> extraData = {
        'governorate': _selectedGovernorate,
        'district': _selectedDistrict,
        'village': _selectedVillage,
        'location': _selectedLocation != null
            ? {
                'lat': _selectedLocation!.latitude,
                'lng': _selectedLocation!.longitude
              }
            : {'lat': 30.0444, 'lng': 31.2357},
      };

      if (widget.role == UserRole.farmer) {
        extraData.addAll({
          'landArea': _landAreaController.text,
          'crops': _cropsController.text,
          'irrigationType': _irrigationTypeController.text,
        });
      } else if (widget.role == UserRole.worker) {
        extraData.addAll({
          'workerType': _workerType,
          'workerSpecializations': _selectedWorkerSpecializations.toList(),
        });
      } else if (widget.role == UserRole.engineer) {
        extraData.addAll({
          'specialization': _selectedEngineerSpecialization,
          'fieldWorkTypes': _selectedEngineerFieldWork.toList(),
          'experienceYears': int.tryParse(_experienceYearsController.text) ?? 0,
          'aboutMe': _aboutMeController.text,
        });
        if (_certificateBytes != null) {
          extraData['certificateImageBase64'] =
              base64Encode(_certificateBytes!);
        }
      } else if (widget.role == UserRole.equipmentOwner) {
        extraData.addAll({
          'equipmentType': _selectedEquipmentType,
          'equipmentName': _selectedEquipmentType,
          'model': _equipmentModelController.text,
          'hourlyRate': _equipmentRateController.text,
          'priceUnit': _pricingUnit,
          if (_selectedEquipmentType == 'جرار')
            'attachments': _selectedAttachments.toList(),
        });
      } else if (widget.role == UserRole.seller) {
        extraData.addAll({
          'shopName': _extra1Controller.text,
          'commercialReg': _extra2Controller.text,
          'category': _selectedCategory,
        });
      } else if (widget.role == UserRole.deliveryWorker) {
        extraData.addAll({
          'deliveryCategory': _selectedCategory,
          'vehicleType': _selectedVehicleType,
          'model': _extra1Controller.text,
          'averageDeliveryPrice': double.tryParse(_extra2Controller.text) ?? 50,
        });
      }

      final nationalIdHash = _nationalIdController.text; // Simple store for now

      final newUser = User(
        id: '',
        role: widget.role,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        nationalIdHash: nationalIdHash,
        address: _addressController.text.trim(),
        createdAt: DateTime.now(),
        profileImageBase64: _profileImageBytes != null
            ? base64Encode(_profileImageBytes!)
            : null,
        extraData: extraData,
      );

      // We should ideally upload ID images here or store base64 in extraData for verification
      extraData['idFrontBase64'] = base64Encode(_idFrontBytes!);
      extraData['idBackBase64'] = base64Encode(_idBackBytes!);

      await auth.signup(newUser, _passwordController.text);
      if (mounted)
        Navigator.pop(context); // Pop back to login or continue to home
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل التسجيل: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: NabaTheme.primary),
        title: Text(_getRoleTitle(),
            style: const TextStyle(
                color: NabaTheme.primary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? NabaTheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).reversed.toList(), // RTL
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: _previousStep,
                child: const Text('السابق',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              )
            else
              const SizedBox(width: 60), // Spacer

            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NabaTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_currentStep == 2 ? 'تأكيد وحفظ' : 'التالي',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('المعلومات الشخصية',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: NabaTheme.primary)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _pickImage(true),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _profileImageBytes != null
                  ? MemoryImage(_profileImageBytes!)
                  : null,
              child: _profileImageBytes == null
                  ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text('صورة شخصية (اختياري)',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildTextField(
              _nameController, 'الاسم بالكامل', Icons.person_outline),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            validator: (v) => (v == null || v.length != 11)
                ? 'رقم الموبايل يجب أن يتكون من 11 رقم'
                : null,
            decoration: _inputDecoration('رقم الموبايل', Icons.phone_android)
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),
          _buildTextField(_nationalIdController, 'الرقم القومي (14 رقم)',
              Icons.credit_card_rounded,
              keyboardType: TextInputType.number, maxLength: 14),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            validator: (v) =>
                (v == null || v.length < 6) ? 'كلمة المرور قصيرة' : null,
            decoration: _inputDecoration('كلمة المرور', Icons.lock_outline),
          ),
          const SizedBox(height: 32),
          const Text('صور البطاقة الشخصية (مطلوب للتوثيق)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildIdUploadButton(true, 'الوجه الأمامي'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildIdUploadButton(false, 'الوجه الخلفي'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildIdUploadButton(bool isFront, String label) {
    final hasImage = isFront ? _idFrontBytes != null : _idBackBytes != null;
    return GestureDetector(
      onTap: () => _pickImage(false, isFrontId: isFront),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: hasImage ? Colors.green.shade50 : Colors.grey.shade100,
          border:
              Border.all(color: hasImage ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(isFront ? _idFrontBytes! : _idBackBytes!,
                    fit: BoxFit.cover))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Center(
              child: Text('العنوان والنطاق الجغرافي',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NabaTheme.primary))),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: _inputDecoration('المحافظة', Icons.map_rounded),
            value: _selectedGovernorate,
            items: _governorates
                .map((e) => DropdownMenuItem(
                    value: e, child: Text(e, textDirection: TextDirection.rtl)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGovernorate = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: _inputDecoration(
                'المركز / المنطقة', Icons.location_city_rounded),
            value: _selectedDistrict,
            items: _districts
                .map((e) => DropdownMenuItem(
                    value: e, child: Text(e, textDirection: TextDirection.rtl)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedDistrict = v;
              _selectedVillage = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedDistrict == 'الفرافرة' || _selectedDistrict == 'الداخلة')
            DropdownButtonFormField<String>(
              decoration:
                  _inputDecoration('القرية', Icons.location_on_outlined),
              value: _selectedVillage,
              items: (_selectedDistrict == 'الفرافرة'
                      ? _farafraVillages
                      : _dakhlaVillages)
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVillage = v),
            )
          else
            _buildTextField(_addressController, 'القرية / العنوان التفصيلي',
                Icons.home_work_outlined),
          const SizedBox(height: 32),
          const Text('خطوة إضافية لتسهيل الوصول إليك:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: Text(_selectedLocation == null
                  ? 'تحديد الموقع تلقائياً عبر GPS'
                  : 'تم تحديد الموقع بنجاح'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color: _selectedLocation == null
                        ? NabaTheme.primary
                        : Colors.green),
                foregroundColor: _selectedLocation == null
                    ? NabaTheme.primary
                    : Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final loc = await Navigator.push<LatLng>(context,
                    MaterialPageRoute(builder: (_) => const MapPickerScreen()));
                if (loc != null) setState(() => _selectedLocation = loc);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(
              child: Text(
                  'التفاصيل المهنية (${_getRoleTitle().split(' ').last})',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NabaTheme.primary))),
          const SizedBox(height: 24),
          if (widget.role == UserRole.farmer) ...[
            _buildTextField(_landAreaController, 'المساحة المزروعة (بالفدان)',
                Icons.landscape_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildTextField(
                _cropsController, 'أهم المحاصيل', Icons.grass_rounded),
            const SizedBox(height: 16),
            _buildTextField(_irrigationTypeController,
                'طريقة الري المتبعة (غمر / تنقيط)', Icons.water_drop_outlined),
          ] else if (widget.role == UserRole.worker) ...[
            DropdownButtonFormField<String>(
              decoration: _inputDecoration('التخصص', Icons.engineering_rounded),
              value: _workerType,
              items: ['عامل', 'فني']
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() {
                _workerType = v;
                _selectedWorkerSpecializations.clear();
              }),
            ),
            if (_workerType == 'عامل') ...[
              const SizedBox(height: 16),
              const Text('اختر مجالات تخصصك (يمكنك اختيار أكثر من تخصص):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: kWorkerSpecializations
                      .map((spec) => CheckboxListTile(
                            title: Text(spec, textDirection: TextDirection.rtl),
                            value:
                                _selectedWorkerSpecializations.contains(spec),
                            activeColor: NabaTheme.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true)
                                  _selectedWorkerSpecializations.add(spec);
                                else
                                  _selectedWorkerSpecializations.remove(spec);
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
            ] else if (_workerType == 'فني') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    'التخصص الفني', Icons.build_circle_outlined),
                value: _selectedWorkerSpecializations.isNotEmpty
                    ? _selectedWorkerSpecializations.first
                    : null,
                items: _technicianSpecializations
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, textDirection: TextDirection.rtl)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedWorkerSpecializations.clear();
                  if (v != null) _selectedWorkerSpecializations.add(v);
                }),
              ),
            ]
          ] else if (widget.role == UserRole.engineer) ...[
            DropdownButtonFormField<String>(
              decoration:
                  _inputDecoration('التخصص الهندسي', Icons.engineering_rounded),
              value: _selectedEngineerSpecialization,
              items: _engineerSpecializations
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedEngineerSpecialization = v;
                _selectedEngineerFieldWork.clear();
              }),
            ),
            if (_selectedEngineerSpecialization != null) ...[
              const SizedBox(height: 16),
              const Text('طبيعة العمل (يمكن اختيار أكثر من تخصص):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: (_engineerFieldWorkMap[
                              _selectedEngineerSpecialization] ??
                          [])
                      .map((work) => CheckboxListTile(
                            title: Text(work, textDirection: TextDirection.rtl),
                            value: _selectedEngineerFieldWork.contains(work),
                            activeColor: NabaTheme.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true)
                                  _selectedEngineerFieldWork.add(work);
                                else
                                  _selectedEngineerFieldWork.remove(work);
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(_experienceYearsController, 'سنوات الخبرة',
                Icons.timer_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildTextField(_aboutMeController, 'نبذة عنك (اختياري)',
                Icons.article_outlined),
          ] else if (widget.role == UserRole.equipmentOwner) ...[
            DropdownButtonFormField<String>(
              decoration: _inputDecoration(
                  'نوع المعدة', Icons.precision_manufacturing_rounded),
              value: _selectedEquipmentType,
              items: [
                'جرار',
                'سيارة نقل',
                'حفار',
                'مولد كهرباء',
                'طلمبة مياه',
                'معدة أخرى'
              ]
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedEquipmentType = v),
            ),
            const SizedBox(height: 16),
            _buildTextField(_equipmentModelController, 'الموديل / سنة الصنع',
                Icons.calendar_today_rounded),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(_equipmentRateController, 'السعر',
                        Icons.monetization_on_outlined,
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: _inputDecoration('الوحدة', Icons.speed_rounded),
                    value: _pricingUnit,
                    items: ['ساعة', 'فدان', 'يوم']
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, textDirection: TextDirection.rtl)))
                        .toList(),
                    onChanged: (v) => setState(() => _pricingUnit = v!),
                  ),
                ),
              ],
            ),
            if (_selectedEquipmentType == 'جرار') ...[
              const SizedBox(height: 24),
              const Text('الملحقات المتاحة (يمكن اختيار أكثر من ملحق):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children:
                    ['مقطورة', 'محراث', 'قصابية', 'مكبس قش', 'دراسة', 'عزاقة']
                        .map((att) => FilterChip(
                              label: Text(att),
                              selected: _selectedAttachments.contains(att),
                              selectedColor: NabaTheme.primary.withOpacity(0.2),
                              checkmarkColor: NabaTheme.primary,
                              onSelected: (val) => setState(() => val
                                  ? _selectedAttachments.add(att)
                                  : _selectedAttachments.remove(att)),
                            ))
                        .toList(),
              ),
            ]
          ] else if (widget.role == UserRole.seller) ...[
            _buildTextField(
                _extra1Controller, 'اسم المتجر / الشركة', Icons.store_rounded),
            const SizedBox(height: 16),
            _buildTextField(_extra2Controller, 'رقم السجل التجاري (اختياري)',
                Icons.receipt_long_rounded),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration:
                  _inputDecoration('نوع المنتجات', Icons.category_rounded),
              value: _selectedCategory,
              items: ['بذور', 'أسمدة', 'مبيدات', 'معدات صغيرة']
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
          ] else if (widget.role == UserRole.deliveryWorker) ...[
            DropdownButtonFormField<String>(
              decoration:
                  _inputDecoration('تخصص النقل', Icons.local_shipping_rounded),
              value: _selectedCategory,
              items: ['محاصيل', 'معدات فك وتركيب', 'أسمدة ومبيدات', 'أخرى']
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration:
                  _inputDecoration('نوع المركبة', Icons.fire_truck_rounded),
              value: _selectedVehicleType,
              items: [
                'موتوسيكل',
                'سكوتر',
                'توكتوك',
                'تروسيكل',
                'سيارة نقل صغير (دبابة)',
                'سيارة نقل كبير (جامبو)',
                'جرار بمقطورة'
              ]
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, textDirection: TextDirection.rtl)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVehicleType = v),
            ),
            const SizedBox(height: 16),
            _buildTextField(
                _extra1Controller, 'الموديل', Icons.directions_car_rounded),
          ]
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: (v) => (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null,
      decoration: _inputDecoration(label, icon).copyWith(counterText: ''),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: NabaTheme.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
