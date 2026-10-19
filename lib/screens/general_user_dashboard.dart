import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/naba_top_header.dart';
import 'farmer_dashboard.dart' show ProfileScreen;
import 'land/land_market_screen.dart';
import 'marketplace_screen.dart';

class GeneralUserDashboard extends StatefulWidget {
  const GeneralUserDashboard({super.key});

  @override
  State<GeneralUserDashboard> createState() => _GeneralUserDashboardState();
}

class _GeneralUserDashboardState extends State<GeneralUserDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    MarketplaceScreen(),
    LandMarketScreen(embedded: true),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.shopping_bag_rounded, 'السوق', imageAsset: 'assets/images/icons/market_v2.png'),
                _buildNavItem(1, Icons.terrain_rounded, 'الأراضي'),
                _buildNavItem(2, Icons.person_rounded, 'حسابي', imageAsset: 'assets/images/icons/profile.png'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {String? imageAsset}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? NabaTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            imageAsset != null
                ? Image.asset(
                    imageAsset,
                    width: 24,
                    height: 24,
                  )
                : Icon(
                    icon,
                    color: isSelected ? NabaTheme.primary : Colors.grey.shade400,
                    size: 24,
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NabaTheme.primary : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
