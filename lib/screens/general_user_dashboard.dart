import 'package:flutter/material.dart';

import '../theme.dart';
import 'farmer_dashboard.dart' show ProfileScreen;
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
                _buildNavItem(1, Icons.person_rounded, 'حسابي', imageAsset: 'assets/images/icons/profile.png'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NabaTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: NabaTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            imageAsset != null
                ? Image.asset(imageAsset, width: 28, height: 28)
                : Icon(
                    icon,
                    color: isSelected ? NabaTheme.primary : Colors.grey,
                    size: 28,
                  ),
          ],
        ),
      ),
    );
  }
}
