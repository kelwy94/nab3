import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();

  static void showRoleSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
              'اختر نوع حسابك',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NabaTheme.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'حدد صفتك لتخصيص التطبيق لتلبية احتياجاتك',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildHorizontalRoleCard(
              context,
              title: 'مستخدم عادي / مشتري وبائع',
              subtitle: 'سوق نبع المفتوح (بيع واشتري بضغطة زر)',
              icon: Icons.shopping_bag_rounded,
              imageAsset: 'assets/images/roles/general.png',
              color: NabaTheme.primary,
              role: UserRole.generalUser,
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'أو سجل كصاحب نشاط مهني:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _buildRoleCard(
                    context,
                    title: 'مزارع',
                    icon: Icons.grass_rounded,
                    imageAsset: 'assets/images/roles/farmer.png',
                    color: Colors.green,
                    role: UserRole.farmer,
                  ),
                  _buildRoleCard(
                    context,
                    title: 'مهندس استشاري',
                    icon: Icons.workspace_premium_rounded,
                    imageAsset: 'assets/images/roles/engineer.png',
                    color: Colors.teal,
                    role: UserRole.engineer,
                  ),
                  _buildRoleCard(
                    context,
                    title: 'عامل زراعي / فني',
                    icon: Icons.handyman_rounded,
                    imageAsset: 'assets/images/roles/worker.png',
                    color: Colors.amber.shade700,
                    role: UserRole.worker,
                  ),
                  _buildRoleCard(
                    context,
                    title: 'صاحب معدات',
                    icon: Icons.agriculture_rounded,
                    imageAsset: 'assets/images/roles/tractor.png',
                    color: Colors.orange.shade800,
                    role: UserRole.equipmentOwner,
                  ),
                  _buildRoleCard(
                    context,
                    title: 'صاحب محل',
                    icon: Icons.storefront_rounded,
                    imageAsset: 'assets/images/roles/store.png',
                    color: Colors.indigo,
                    role: UserRole.seller,
                  ),
                  _buildRoleCard(
                    context,
                    title: 'عامل توصيل',
                    icon: Icons.local_shipping_rounded,
                    imageAsset: 'assets/images/roles/delivery.png',
                    color: Colors.red.shade400,
                    role: UserRole.deliveryWorker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? imageAsset,
    required Color color,
    required UserRole role,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      elevation: 2,
      shadowColor: color.withOpacity(0.15),
      child: InkWell(
        onTap: () async {
          if (role == UserRole.admin) {
            await Provider.of<AuthProvider>(context, listen: false)
                .loginAsAdmin();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SignupScreen(role: role)),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: imageAsset != null
                    ? Image.asset(imageAsset, width: 36, height: 36)
                    : Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHorizontalRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    String? imageAsset,
    required Color color,
    required UserRole role,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.5), width: 2),
      ),
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SignupScreen(role: role)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: imageAsset != null
                    ? Image.asset(imageAsset, width: 40, height: 40)
                    : Icon(icon, color: color, size: 40),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: NabaTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _adminPinController = TextEditingController();

  @override
  void dispose() {
    _adminPinController.dispose();
    super.dispose();
  }

  void _showAdminPinDialog() {
    _adminPinController.clear();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('دخول الإدارة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _adminPinController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'أدخل الرقم السري',
              prefixIcon: const Icon(Icons.lock_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_adminPinController.text == '12321') {
                  Navigator.pop(ctx);
                  await Provider.of<AuthProvider>(context, listen: false)
                      .loginAsAdmin();
                } else {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الرقم السري غير صحيح'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }

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

          // Hidden Admin Button - top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: _showAdminPinDialog,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: Colors.white.withOpacity(0.15),
                  size: 18,
                ),
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
                      const SizedBox(height: 24),
                      NabaButton(
                        text: 'إنشاء حساب جديد',
                        onPressed: () =>
                            OnboardingScreen.showRoleSelection(context),
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
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Provider.of<AuthProvider>(context, listen: false)
                              .enterGuestMode();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.visibility_rounded,
                                color: Colors.grey, size: 16),
                            SizedBox(width: 6),
                            Text('تصفّح كزائر (بدون تسجيل)',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
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
}
