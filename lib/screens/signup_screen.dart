import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class SignupScreen extends StatefulWidget {
  final UserRole role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _emailController;
  late TextEditingController _nationalIdController;
  late TextEditingController _addressController;

  // Role specific controllers
  late TextEditingController _extra1Controller;
  late TextEditingController _extra2Controller;
  late TextEditingController _extra3Controller;
  late TextEditingController _extra4Controller;

  bool _isLoading = false;
  Uint8List? _profileImageBytes;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  final ImagePicker _picker = ImagePicker();

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
          _profileImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickIdImage(bool isFront) async {
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
          if (isFront) {
            _idFrontBytes = bytes;
          } else {
            _idBackBytes = bytes;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking ID image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _emailController = TextEditingController();
    _nationalIdController = TextEditingController();
    _addressController = TextEditingController();
    _extra1Controller = TextEditingController();
    _extra2Controller = TextEditingController();
    _extra3Controller = TextEditingController();
    _extra4Controller = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _extra1Controller.dispose();
    _extra2Controller.dispose();
    _extra3Controller.dispose();
    _extra4Controller.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);

        Map<String, dynamic> extraData = {
          'email': _emailController.text,
          'password': _passwordController.text,
        };
        if (widget.role == UserRole.farmer) {
          extraData.addAll({
            'landArea': _extra1Controller.text,
            'crops': _extra2Controller.text,
            'irrigationType': _extra3Controller.text,
          });
        } else if (widget.role == UserRole.seller) {
          extraData.addAll({
            'shopName': _extra1Controller.text,
            'commercialReg': _extra2Controller.text,
            'category': _extra3Controller.text,
          });
        } else if (widget.role == UserRole.equipmentOwner) {
          extraData.addAll({
            'equipmentName': _extra1Controller.text,
            'model': _extra2Controller.text,
            'equipmentType': _extra3Controller.text,
            'hourlyRate': _extra4Controller.text,
          });
        } else if (widget.role == UserRole.investor) {
          extraData.addAll({
            'companyName': _extra1Controller.text,
            'investmentPreference': _extra2Controller.text,
            'targetInvestment': _extra3Controller.text,
          });
        }

        if (_idFrontBytes != null) {
          extraData['nationalIdFrontBase64'] = base64Encode(_idFrontBytes!);
        }
        if (_idBackBytes != null) {
          extraData['nationalIdBackBase64'] = base64Encode(_idBackBytes!);
        }

        String? base64Image;
        if (_profileImageBytes != null) {
          base64Image = base64Encode(_profileImageBytes!);
        }

        final newUser = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          role: widget.role,
          fullName: _nameController.text,
          phone: _phoneController.text,
          nationalIdHash: _nationalIdController.text,
          address: _addressController.text,
          createdAt: DateTime.now(),
          extraData: extraData,
          profileImageBase64: base64Image,
        );

        await auth.signup(newUser, _passwordController.text);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
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
      appBar: const NabaAppBar(title: 'إنشاء حساب جديد'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Hero(
                  tag: 'logo',
                  child: Text(
                    'نبع',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: NabaTheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'التسجيل كـ ${_getRoleName(widget.role)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Profile Photo Placeholder
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : null,
                        child: _profileImageBytes == null
                            ? Icon(Icons.person_rounded,
                                size: 50, color: Colors.grey.shade400)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: NabaTheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt_rounded,
                                size: 18, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('صورة الملف الشخصي',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 32),

                _buildFieldLabel('الاسم الرباعي'),
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(hintText: 'الاسم كما في البطاقة'),
                  validator: (v) => v!.isEmpty ? 'مطلب' : null,
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('رقم الهاتف'),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: '01xxxxxxxxx'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.length < 11 ? 'رقم غير صحيح' : null,
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('كلمة المرور'),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(hintText: '********'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'كلمة المرور ضعيفة' : null,
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('البريد الإلكتروني (اختياري)'),
                TextFormField(
                  controller: _emailController,
                  decoration:
                      const InputDecoration(hintText: 'example@mail.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('الرقم القومي (14 رقم)'),
                TextFormField(
                  controller: _nationalIdController,
                  decoration: const InputDecoration(hintText: '2xxxxxxxxxxxxx'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v!.length != 14 ? 'الرقم القومي غير صحيح' : null,
                ),
                const SizedBox(height: 24),

                // ID Photos
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadCard(
                        'ظهر البطاقة',
                        Icons.badge_outlined,
                        imageBytes: _idBackBytes,
                        onTap: () => _pickIdImage(false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildUploadCard(
                        'وجه البطاقة',
                        Icons.badge_rounded,
                        imageBytes: _idFrontBytes,
                        onTap: () => _pickIdImage(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _buildFieldLabel('العنوان بالتفصيل'),
                TextFormField(
                  controller: _addressController,
                  decoration:
                      const InputDecoration(hintText: 'المركز، القرية، الشارع'),
                ),
                const SizedBox(height: 16),

                _buildLocationPicker(),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                Text(
                  'بيانات مخصصة لـ ${_getRoleName(widget.role)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: NabaTheme.primary,
                      fontSize: 18),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),

                ..._buildRoleSpecificFields(),

                const SizedBox(height: 48),

                NabaButton(
                  text: _isLoading ? 'جاري التحميل...' : 'إتمام التسجيل',
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading ? null : Icons.check_circle_rounded,
                ),
                const SizedBox(height: 32),
                const Text(
                  'بالتسجيل أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard(String label, IconData icon,
      {Uint8List? imageBytes, VoidCallback? onTap}) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        image: imageBytes != null
            ? DecorationImage(
                image: MemoryImage(imageBytes),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3), BlendMode.darken))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(imageBytes != null ? Icons.check_circle_rounded : icon,
                color: imageBytes != null ? Colors.white : NabaTheme.primary,
                size: 32),
            const SizedBox(height: 8),
            Text(imageBytes != null ? 'تم الرفع' : label,
                style: TextStyle(
                    fontSize: 12,
                    color: imageBytes != null ? Colors.white : Colors.grey,
                    fontWeight: imageBytes != null
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'تحديد الموقع على الخريطة',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.blue),
        ],
      ),
    );
  }

  List<Widget> _buildRoleSpecificFields() {
    switch (widget.role) {
      case UserRole.farmer:
        return [
          _buildFieldLabel('مساحة الأرض (فدان)'),
          TextFormField(
            controller: _extra1Controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('المحاصيل الحالية'),
          TextFormField(
            controller: _extra2Controller,
            decoration: const InputDecoration(hintText: 'قمح، شعير، إلخ'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('نوع الري'),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(),
            items: ['غمر', 'تنقيط', 'رش', 'أخرى']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => _extra3Controller.text = v ?? '',
          ),
        ];
      case UserRole.seller:
        return [
          _buildFieldLabel('اسم المحل / النشاط'),
          TextFormField(
            controller: _extra1Controller,
            decoration:
                const InputDecoration(hintText: 'مثلاً: مؤسسة النيل للبذور'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('رقم السجل التجاري'),
          TextFormField(
            controller: _extra2Controller,
            decoration: const InputDecoration(hintText: '1234567'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('التصنيف الرئيسي'),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(),
            items: ['بذور وأسمدة', 'معدات ري', 'أدوات زراعية', 'أخرى']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => _extra3Controller.text = v ?? '',
          ),
        ];
      case UserRole.equipmentOwner:
        return [
          _buildFieldLabel('اسم المعدة'),
          TextFormField(
            controller: _extra1Controller,
            decoration:
                const InputDecoration(hintText: 'مثلاً: جرار نيوهولاند'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('سنة الصنع'),
          TextFormField(
            controller: _extra2Controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '2023'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('نوع المعدة'),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(),
            items: ['جرار', 'حفار', 'ماكينة رش', 'ماكينة ري', 'أخرى']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => _extra3Controller.text = v ?? '',
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('سعر التأجير بالساعة (بالجنيه)'),
          TextFormField(
            controller: _extra4Controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0.00'),
          ),
        ];
      case UserRole.investor:
        return [
          _buildFieldLabel('اسم الشركة أو المؤسسة (اختياري)'),
          TextFormField(
            controller: _extra1Controller,
            decoration: const InputDecoration(hintText: 'مثلاً: شركة النور التنموية'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('طبيعة الاستثمار المفضلة'),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(),
            items: ['تمويل آبار', 'استصلاح أراضي', 'شراكة محاصيل', 'معدات وتقنيات']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => _extra2Controller.text = v ?? '',
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('حجم الاستثمار المستهدف (اختياري)'),
          TextFormField(
            controller: _extra3Controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '500,000'),
          ),
        ];
      case UserRole.admin:
        return [];
      default:
        return [];
    }
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

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return 'مزارع';
      case UserRole.worker:
        return 'عامل';
      case UserRole.investor:
        return 'مستثمر';
      case UserRole.seller:
        return 'تاجر';
      case UserRole.equipmentOwner:
        return 'صاحب معدات';
      case UserRole.admin:
        return 'مسؤول';
    }
  }
}
