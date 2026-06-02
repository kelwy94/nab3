import 'package:flutter/material.dart';
import 'package:nab3_gded/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نب3 جديد'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  color: Colors.green.shade700,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.fullName ?? 'مستخدم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getUserTypeLabel(user?.role.toString() ?? ''),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // Menu Items
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMenuCard(
                        context,
                        icon: Icons.person_add,
                        title: 'الملف الشخصي',
                        subtitle: 'عرض وتعديل بيانات الملف الشخصي',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('سيتم إضافة هذه الميزة قريباً'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        icon: Icons.search,
                        title: 'البحث عن مستخدمين',
                        subtitle: 'البحث عن مزارعين وعمال ومستثمرين',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('سيتم إضافة هذه الميزة قريباً'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        icon: Icons.chat,
                        title: 'الرسائل',
                        subtitle: 'تواصل مع المستخدمين الآخرين',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('سيتم إضافة هذه الميزة قريباً'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        icon: Icons.notifications,
                        title: 'الإخطارات',
                        subtitle: 'عرض الإخطارات والتنبيهات',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('سيتم إضافة هذه الميزة قريباً'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        icon: Icons.settings,
                        title: 'الإعدادات',
                        subtitle: 'تخصيص إعدادات التطبيق',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('سيتم إضافة هذه الميزة قريباً'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300, width: 1),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.green.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.shade700,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _getUserTypeLabel(String userType) {
    if (userType.contains('farmer')) return 'مزارع';
    if (userType.contains('worker')) return 'عامل';
    if (userType.contains('equipmentOwner')) return 'صاحب معدة';
    if (userType.contains('investor')) return 'مستثمر';
    if (userType.contains('seller')) return 'صاحب محل';
    if (userType.contains('admin')) return 'مدير';
    return 'مستخدم';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/welcome');
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
