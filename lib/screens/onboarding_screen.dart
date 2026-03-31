import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [NabaTheme.primary, NabaTheme.primaryLight],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),
                const Hero(
                  tag: 'logo',
                  child: Text(
                    'نبع',
                    style: TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Text(
                  'Naba\' Irrigation',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),

                // Bottom Section Card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  decoration: const BoxDecoration(
                    color: NabaTheme.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'مرحباً بك في نبع',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: NabaTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'نظم ريك، وظف عمالك، وابقَ على اتصال دائماً',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 48),
                      NabaButton(
                        text: 'إنشاء حساب جديد',
                        onPressed: () => _showRoleSelection(context),
                        icon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(height: 16),
                      NabaButton(
                        text: 'تسجيل الدخول',
                        isPrimary: false,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                        icon: Icons.login_rounded,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: NabaTheme.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'اختر نوع الحساب',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildRoleCard(
                    context,
                    title: 'مزارع',
                    subtitle: 'مشارك في بئر أو مسؤول بئر',
                    icon: Icons.agriculture_rounded,
                    role: UserRole.farmer,
                  ),
                  const SizedBox(height: 12),
                  _buildRoleCard(
                    context,
                    title: 'عامل زراعي',
                    subtitle: 'مختص ري، تقليم، أو معدات',
                    icon: Icons.engineering_rounded,
                    role: UserRole.worker,
                  ),
                  const SizedBox(height: 12),
                  _buildRoleCard(
                    context,
                    title: 'مستثمر زراعي',
                    subtitle: 'أصحاب المزارع الكبرى والشركات',
                    icon: Icons.business_rounded,
                    role: UserRole.investor,
                  ),
                  const SizedBox(height: 12),
                  _buildRoleCard(
                    context,
                    title: 'بائع مستلزمات',
                    subtitle: 'تاجر بذور، أسمدة، أو معدات',
                    icon: Icons.store_rounded,
                    role: UserRole.seller,
                  ),
                  const SizedBox(height: 12),
                  _buildRoleCard(
                    context,
                    title: 'صاحب معدات',
                    subtitle: 'جرارات، ماكينات ري، إلخ',
                    icon: Icons.minor_crash_rounded,
                    role: UserRole.equipmentOwner,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  _buildRoleCard(
                    context,
                    title: 'لوحة التحكم',
                    subtitle: 'خاص بمسؤولي النظام',
                    icon: Icons.admin_panel_settings_rounded,
                    role: UserRole.admin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required UserRole role,
  }) {
    return NabaCard(
      onTap: () async {
        if (role == UserRole.admin) {
          await Provider.of<AuthProvider>(context, listen: false)
              .loginAsAdmin();
          if (!context.mounted) return;
          Navigator.of(context).pop(); // Close bottom sheet
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SignupScreen(role: role)),
          );
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NabaTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: NabaTheme.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}
