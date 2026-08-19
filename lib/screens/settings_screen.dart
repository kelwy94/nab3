import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.locale.languageCode == 'ar';
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(title: loc?.settings ?? 'الإعدادات'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSettingsSection('تفضيلات التطبيق', [
              _buildSettingsItem(
                Icons.language_rounded, 
                loc?.language ?? 'اللغة', 
                isArabic ? 'العربية' : 'English',
                onTap: () {
                  localeProvider.setLocale(Locale(isArabic ? 'en' : 'ar'));
                }
              ),
              _buildSettingsItem(
                  Icons.notifications_active_outlined, loc?.notifications ?? 'الإشعارات', 'مفعلة'),
              _buildSettingsItem(Icons.dark_mode_outlined, loc?.theme ?? 'المظهر', 'فاتح'),
            ]),
            const SizedBox(height: 32),
            _buildSettingsSection('الأمن والحساب', [
              _buildSettingsItem(
                  Icons.lock_outline_rounded, loc?.changePassword ?? 'تغيير كلمة المرور', '', onTap: () => _showChangePasswordDialog(context)),
              _buildSettingsItem(
                  Icons.verified_user_outlined, 'توثيق الحساب', 'غير موثق'),
              _buildSettingsItem(
                  Icons.delete_forever_outlined, 'حذف الحساب', '',
                  color: Colors.red),
            ]),
            const SizedBox(height: 32),
            _buildSettingsSection('عن نبع', [
              _buildSettingsItem(Icons.info_outline_rounded, 'من نحن', ''),
              _buildSettingsItem(
                  Icons.description_outlined, 'الشروطة والأحكام', ''),
              _buildSettingsItem(
                  Icons.star_outline_rounded, 'تقييم التطبيق', '',
                  onTap: () => _showRateAppDialog(context)),
            ]),
            const SizedBox(height: 48),
            NabaButton(
              text: loc?.logout ?? 'تسجيل الخروج',
              isPrimary: false,
              icon: Icons.logout_rounded,
              onPressed: () => authProvider.logout(),
            ),
            const SizedBox(height: 24),
            const Text('الإصدار 1.0.4 (5)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمتا المرور غير متطابقتين')));
                  return;
                }
                try {
                  final user = auth.FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != null) {
                    final cred = auth.EmailAuthProvider.credential(email: user.email!, password: oldPasswordCtrl.text);
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPasswordCtrl.text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح'), backgroundColor: Colors.green));
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRateAppDialog(BuildContext context) async {
    int rating = 5;
    final feedbackCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تقييم التطبيق'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ما تقييمك لتجربة استخدام تطبيق نبع؟', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'أخبرنا برأيك أو أي اقتراحات للتطوير...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: NabaTheme.primary),
                  onPressed: () async {
                    try {
                      final user = Provider.of<AuthProvider>(context, listen: false).user;
                      await FirebaseFirestore.instance.collection('app_ratings').add({
                        'userId': user?.id ?? 'unknown',
                        'userName': user?.fullName ?? 'unknown',
                        'rating': rating,
                        'feedback': feedbackCtrl.text,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('شكراً لتقييمك!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('إرسال', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 12),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: NabaTheme.primary)),
        ),
        ...items,
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String label, String value,
      {Color? color, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NabaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap ?? () {},
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, color: color ?? NabaTheme.primary),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const Spacer(),
            if (value.isNotEmpty)
              Text(value,
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
