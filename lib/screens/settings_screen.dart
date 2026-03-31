import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'الإعدادات'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSettingsSection('تفضيلات التطبيق', [
              _buildSettingsItem(Icons.language_rounded, 'اللغة', 'العربية'),
              _buildSettingsItem(
                  Icons.notifications_active_outlined, 'الإشعارات', 'مفعلة'),
              _buildSettingsItem(Icons.dark_mode_outlined, 'المظهر', 'فاتح'),
            ]),
            const SizedBox(height: 32),
            _buildSettingsSection('الأمن والحساب', [
              _buildSettingsItem(
                  Icons.lock_outline_rounded, 'تغيير كلمة المرور', ''),
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
                  Icons.star_outline_rounded, 'تقييم التطبيق', ''),
            ]),
            const SizedBox(height: 48),
            NabaButton(
              text: 'تسجيل الخروج',
              isPrimary: false,
              icon: Icons.logout_rounded,
              onPressed: () => auth.logout(),
            ),
            const SizedBox(height: 24),
            const Text('الإصدار 1.0.0 (389)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
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
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NabaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () {},
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
