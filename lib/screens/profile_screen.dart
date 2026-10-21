import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'invite_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('خطأ: $e'),
                                      backgroundColor: Colors.red));
                            }
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

  bool get isTab => widget.isTab;

  @override
  Widget build(BuildContext context) {
    // Listen to changes in auth provider so if they update image, it refreshes
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold();
    }

    ImageProvider? avatar;
    if (user.profileImageUrl != null) {
      avatar = NetworkImage(user.profileImageUrl!);
    } else if (user.profileImageBase64 != null) {
      avatar =
          MemoryImage(const Base64Decoder().convert(user.profileImageBase64!));
    }

    final extra = user.extraData ?? {};

    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header Segment
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 40),
              decoration: BoxDecoration(
                color: NabaTheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: avatar,
                          child: avatar == null
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phone,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildInfoCard(
                    icon: Icons.badge_rounded,
                    title: 'الدور في التطبيق',
                    value: _getRoleNameLocalized(user.role.name),
                  ),
                  if (user.role.name == 'engineer' ||
                      user.role.name == 'worker') ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.work_history_rounded,
                      title: 'التخصص والخبرة',
                      value: user.role.name == 'worker'
                          ? '${((extra['workerSpecializations'] as List?) ?? []).join('، ').isNotEmpty ? (extra['workerSpecializations'] as List).join('، ') : (extra['specialization'] ?? 'غير محدد')} (${extra['experienceYears'] ?? 0} سنوات)'
                          : '${extra['specialization'] ?? 'غير محدد'} (${extra['experienceYears'] ?? 0} سنوات)',
                    ),
                  ],
                  if (extra['aboutMe'] != null &&
                      extra['aboutMe'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.info_outline_rounded,
                      title: 'نبذة عني',
                      value: extra['aboutMe'],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Actions
                  _buildActionCard(
                    icon: Icons.edit_document,
                    title: 'تعديل البيانات الأساسية والصورة',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()));
                    },
                  ),
                  if (user.role == UserRole.worker) ...[
                    const SizedBox(height: 12),
                    _buildActionCard(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'طلب إضافة تخصص جديد',
                      color: Colors.teal,
                      onTap: _showRequestSpecializationDialog,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.card_giftcard_rounded,
                    title: 'ادعي أصحابك واكسب',
                    color: NabaTheme.primary,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InviteScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.lock_rounded,
                    title: 'تغيير كلمة المرور',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen()));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    color: Colors.red,
                    onTap: () {
                      auth.logout();
                      Navigator.pop(context); // close profile screen
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          ],
        ),
      ),
    );

    if (isTab) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const NabaAppBar(title: 'الصفحة الشخصية', showBackButton: true),
      body: body,
    );
  }

  String _getRoleNameLocalized(String role) {
    switch (role) {
      case 'farmer':
        return 'مزارع';
      case 'engineer':
        return 'استشاري / مهندس زراعي';
      case 'equipmentOwner':
        return 'صاحب معدة/جرار';
      case 'worker':
        return 'عامل زراعي وفني';
      case 'seller':
        return 'تاجر / صاحب محل';
      case 'deliveryWorker':
        return 'عامل توصيل';
      default:
        return 'مستخدم';
    }
  }

  Widget _buildInfoCard(
      {required IconData icon, required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NabaTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: NabaTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      {required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
