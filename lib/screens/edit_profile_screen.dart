import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _specCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _aboutCtrl;

  bool _isLoading = false;
  ImageProvider? _currentAvatar;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user!;
    _nameCtrl = TextEditingController(text: user.fullName);
    _phoneCtrl = TextEditingController(text: user.phone);
    final extra = user.extraData ?? {};
    _specCtrl =
        TextEditingController(text: extra['specialization']?.toString() ?? '');
    _expCtrl =
        TextEditingController(text: extra['experienceYears']?.toString() ?? '');
    _aboutCtrl =
        TextEditingController(text: extra['aboutMe']?.toString() ?? '');

    if (user.profileImageUrl != null) {
      _currentAvatar = NetworkImage(user.profileImageUrl!);
    } else if (user.profileImageBase64 != null) {
      _currentAvatar =
          MemoryImage(const Base64Decoder().convert(user.profileImageBase64!));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specCtrl.dispose();
    _expCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = await pickedFile.readAsBytes();

        final ext = pickedFile.name.split('.').last.toLowerCase();
        final finalExt =
            (ext == 'jpg' || ext == 'png' || ext == 'jpeg') ? ext : 'jpg';

        await Provider.of<AuthProvider>(context, listen: false)
            .uploadProfileImageToStorage(bytes, finalExt);

        setState(() {
          _currentAvatar = MemoryImage(bytes); // temporary instant feedback
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث الصورة بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('خطأ في رفع الصورة: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user!;

      // Update core profile
      await auth.updateProfile(_nameCtrl.text, _phoneCtrl.text, user.address);

      // Update extra data if engineer/worker
      if (user.role.name == 'engineer' || user.role.name == 'worker') {
        final newExtra = Map<String, dynamic>.from(user.extraData ?? {});
        if (user.role.name == 'engineer') {
          newExtra['specialization'] = _specCtrl.text;
        }
        newExtra['experienceYears'] = int.tryParse(_expCtrl.text) ?? 0;
        newExtra['aboutMe'] = _aboutCtrl.text;

        await auth.updateUserStatus(user.id, {'extraData': newExtra});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم تحديث البيانات بنجاح'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRequestSpecializationDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user!;
    final List<String> currentSpecs =
        List<String>.from(user.extraData?['workerSpecializations'] ?? []);

    final availableSpecs =
        kWorkerSpecializations.where((s) => !currentSpecs.contains(s)).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedSpec =
            availableSpecs.isNotEmpty ? availableSpecs.first : null;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('طلب تخصص إضافي'),
                content: availableSpecs.isEmpty
                    ? const Text('تمت إضافة جميع التخصصات المتاحة بالفعل.')
                    : DropdownButtonFormField<String>(
                        value: selectedSpec,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: availableSpecs.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedSpec = val);
                        },
                      ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  if (availableSpecs.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: NabaTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (selectedSpec != null) {
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            final newExtra =
                                Map<String, dynamic>.from(user.extraData ?? {});
                            newExtra['pendingSpecialization'] = selectedSpec;
                            await auth.updateUserStatus(
                                user.id, {'extraData': newExtra});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'تم إرسال الطلب للإدارة بنجاح، سيتم تفعيله بعد الموافقة'),
                                      backgroundColor: Colors.green));
                              Navigator.pop(context); // العودة للشاشة السابقة
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('خطأ: $e'),
                                      backgroundColor: Colors.red));
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        }
                      },
                      child: const Text('إرسال'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const Scaffold();

    final isProfessional =
        user.role.name == 'engineer' || user.role.name == 'worker';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const NabaAppBar(title: 'تعديل البيانات', showBackButton: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: _currentAvatar,
                              child: _currentAvatar == null
                                  ? const Icon(Icons.person,
                                      size: 60, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: NabaTheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3)),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                            labelText: 'الاسم بالكامل',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        validator: (v) =>
                            v!.isEmpty ? 'مطلوب إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: InputDecoration(
                            labelText: 'رقم الجوال',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        validator: (v) =>
                            v!.isEmpty ? 'مطلوب إدخال رقم الجوال' : null,
                      ),

                      if (user.role.name == 'engineer') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _specCtrl,
                          decoration: InputDecoration(
                              labelText: 'التخصص',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          validator: (v) => v!.isEmpty ? 'التخصص مطلوب' : null,
                        ),
                      ],
                      if (user.role.name == 'worker') ...[
                        const SizedBox(height: 20),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          title: const Text('طَلَب تخصص إضافي/جديد',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text(
                              'يمكنك اقتراح تخصص جديد ليتم اعتماده من الإدارة.',
                              style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.add_circle,
                              color: NabaTheme.primary),
                          onTap: _showRequestSpecializationDialog,
                        ),
                        if (user.extraData?['pendingSpecialization'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'جاري مراجعة طلبك للتخصص: ${user.extraData!['pendingSpecialization']}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                      if (isProfessional) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _expCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'سنوات الخبرة',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _aboutCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: 'نبذة شخصية / إضافية',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                      const SizedBox(height: 40),
                      NabaButton(text: 'حفظ التغييرات', onPressed: _saveProfile)
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
