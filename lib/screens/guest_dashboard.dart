import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../providers/auth_provider.dart';
import 'land/land_market_banner.dart';
import 'marketplace_screen.dart';
import '../utils/guest_utils.dart';

class GuestDashboard extends StatefulWidget {
  const GuestDashboard({super.key});

  @override
  State<GuestDashboard> createState() => _GuestDashboardState();
}

class _GuestDashboardState extends State<GuestDashboard> {
  int _currentIndex = 0;

  void _promptLogin(BuildContext context) {
    GuestUtils.showGuestLoginPrompt(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildGuestHome(),
          _buildGuestMarket(),
          _buildGuestProfile(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'الرئيسية'),
              _buildNavItem(1, Icons.storefront_rounded, 'السوق'),
              _buildNavItem(2, Icons.person_rounded, 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? NabaTheme.primary : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: isSelected ? NabaTheme.primary : Colors.grey,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestHome() {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: AppBar(
        title: const Text('نبع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthProvider>().exitGuestMode(),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('سجّل'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [NabaTheme.primary, NabaTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('مرحباً بك في نبع 👋',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('سجّل الآن للوصول لكل الخدمات الزراعية',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.right),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const LandMarketBanner(),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text('الخدمات المتاحة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildLockedService(
                    'طلب عامل', Icons.handyman_rounded, Colors.orange),
                _buildLockedService('طلب معدة', Icons.agriculture_rounded,
                    Colors.blue.shade700),
                _buildLockedService('استشارة هندسية',
                    Icons.workspace_premium_rounded, Colors.teal),
                _buildLockedService(
                    'شراء منتجات', Icons.shopping_bag_rounded, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<AuthProvider>().exitGuestMode(),
              icon: const Icon(Icons.app_registration_rounded),
              label: const Text('سجّل الآن وابدأ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedService(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _promptLogin(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('سجّل للوصول',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestMarket() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          color: NabaTheme.primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                icon: const Icon(Icons.login, color: Colors.white, size: 16),
                label: const Text('تسجيل',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const Text('سوق نبع 🛒',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Expanded(
          child: MarketplaceScreen(),
        ),
      ],
    );
  }

  Widget _buildGuestProfile() {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: AppBar(
        title:
            const Text('حسابي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: NabaTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    size: 60, color: NabaTheme.primary),
              ),
              const SizedBox(height: 24),
              const Text('أنت تتصفح كزائر',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'سجّل الآن للاستفادة من كل خدمات نبع الزراعية والوصول لجدول الري والطلبات والسوق',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                  icon: const Icon(Icons.app_registration_rounded),
                  label: const Text('إنشاء حساب جديد',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                child: const Text('لديّ حساب بالفعل — تسجيل الدخول',
                    style: TextStyle(color: NabaTheme.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
