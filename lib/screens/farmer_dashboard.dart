import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/well_provider.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/irrigation_calendar.dart';
import '../widgets/naba_widgets.dart';
import 'well_create_screen.dart';
import 'marketplace_screen.dart';
import 'settings_screen.dart';
import 'well_search_screen.dart';
import 'well_details_screen.dart';
import 'help_support_screen.dart';
import 'edit_profile_screen.dart';
import 'job_history_screen.dart';
import 'orders_history_screen.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<WellProvider>(context, listen: false).disableAdminMode();
  }

  static const List<Widget> _screens = [
    FarmerHomeTab(),
    WellManagementScreen(),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.calendar_month_rounded, 'الجدول'),
                _buildNavItem(1, Icons.water_drop_rounded, 'البئر'),
                _buildNavItem(2, Icons.shopping_bag_rounded, 'السوق'),
                _buildNavItem(3, Icons.person_rounded, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: NabaTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            Icon(
              icon,
              color: isSelected ? NabaTheme.primary : Colors.grey,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class FarmerHomeTab extends StatelessWidget {
  const FarmerHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wellProvider = Provider.of<WellProvider>(context);
    final wells = wellProvider.myWells;

    if (wellProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wells.isEmpty) {
      if (wellProvider.hasPendingCreation) {
        return Scaffold(
          appBar: const NabaAppBar(title: 'الرئيسية', showBackButton: false),
          backgroundColor: NabaTheme.background,
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text('طلب إنشاء البئر قيد المراجعة',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                  SizedBox(height: 8),
                  Text('طلبك قيد المراجعة والاعتماد من الإدارة المركزية. سيتم تفعيل جدولك فور الموافقة.',
                      textAlign: TextAlign.center, style: TextStyle(color: NabaTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }

      if (wellProvider.hasPendingJoin) {
        return Scaffold(
          appBar: const NabaAppBar(title: 'الرئيسية', showBackButton: false),
          backgroundColor: NabaTheme.background,
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_bottom_rounded, size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text('طلب الانضمام قيد المراجعة',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                  SizedBox(height: 8),
                  Text('طلب انضمامك للبئر قيد المراجعة. سيظهر لك الجدول الخاص بالبئر هنا بعد الموافقة.',
                      textAlign: TextAlign.center, style: TextStyle(color: NabaTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: const NabaAppBar(title: 'الرئيسية', showBackButton: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text('لا يوجد جدول ري',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                  'هل تريد تسجيل بئر او التسجيل في بئر ؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              _buildSpecialCard(
                context,
                title: 'تسجيل بئر جديد',
                desc: 'قم بإنشاء بئر جديد لتكون مديراً له',
                icon: Icons.add_circle_rounded,
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WellCreateScreen())),
              ),
              const SizedBox(height: 16),
              _buildSpecialCard(
                context,
                title: 'التسجيل في بئر',
                desc: 'ابحث عن آبار منطقتك وانضم لبئر قائم',
                icon: Icons.search_rounded,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WellSearchScreen()));
                },
              ),
            ],
          ),
        ),
      );
    }

    return const IrrigationCalendar();
  }

  Widget _buildSpecialCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return NabaCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class WellManagementScreen extends StatelessWidget {
  const WellManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wellProvider = Provider.of<WellProvider>(context);
    final wells = wellProvider.myWells;

    return Scaffold(
      appBar: const NabaAppBar(title: 'إدارة البئر', showBackButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (wells.isNotEmpty) ...[
              const Text('آباري المسجلة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...wells.map((well) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildWellCard(context, well),
                  )),
              const Divider(height: 48),
            ],
            _buildSpecialCard(
              context,
              title: 'بدء بئر جديد',
              desc: 'كن مديراً للبئر وتحكم في الجدول والمشاركين بكل سهولة',
              icon: Icons.add_circle_rounded,
              color: Colors.teal,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WellCreateScreen())),
            ),
            const SizedBox(height: 20),
            _buildSpecialCard(
              context,
              title: 'الانضمام لبئر',
              desc: 'ابحث عن آبار منطقتك وارسل طلب انضمام لمالك البئر',
              icon: Icons.search_rounded,
              color: Colors.blue,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WellSearchScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellCard(BuildContext context, Well well) {
    return NabaCard(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => WellDetailsScreen(well: well)));
      },
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NabaTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.water_drop_rounded,
                color: NabaTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(well.wellName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  'العمق: ${well.depthMeters}م | المساحة: ${well.irrigatedAreaFeddan} فدان',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSpecialCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return NabaCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage(AuthProvider auth) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() => _isUploading = true);
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        await auth.updateProfileImage(base64Image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الصورة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user!;
    return Scaffold(
      appBar: NabaAppBar(
        title: 'حسابي - المطوّر',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'avatar',
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: user.profileImageBase64 != null
                          ? MemoryImage(base64Decode(user.profileImageBase64!))
                          : null,
                      child: user.profileImageBase64 == null
                          ? const Icon(Icons.person_rounded, size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: NabaTheme.primary,
                    child: IconButton(
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.camera_alt_rounded,
                              size: 18, color: Colors.white),
                      onPressed: _isUploading
                          ? null
                          : () => _pickAndUploadImage(auth),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(user.fullName,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(user.phone,
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
            if (user.extraData != null &&
                user.extraData!['landArea'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: NabaTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'المساحة: ${user.extraData!['landArea']} فدان',
                  style: const TextStyle(
                      color: NabaTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildProfileItem(
                context, Icons.person_outline_rounded, 'تعديل البيانات الشخصية',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            }),
            _buildProfileItem(context, Icons.work_history_rounded, 'سجل الطلبات السابقة',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JobHistoryScreen()));
            }),
            _buildProfileItem(context, Icons.local_shipping_rounded, 'تتبع مشترياتي (المتجر)',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrdersHistoryScreen()));
            }),
            _buildProfileItem(context, Icons.history_rounded, 'تاريخ الري',
                onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا يوجد عمليات ري سابقة لعرضها.')),
              );
            }),
            _buildProfileItem(context, Icons.account_balance_wallet_outlined,
                'المحفظة المالية', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('رصيدك الحالي: 0 ج.م')),
              );
            }),
            _buildProfileItem(
                context, Icons.help_outline_rounded, 'المساعدة والدعم',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
            }),
            const SizedBox(height: 24),
            NabaButton(
              text: 'تسجيل الخروج',
              isPrimary: false,
              icon: Icons.logout_rounded,
              onPressed: () => auth.logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String label,
      {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NabaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, color: NabaTheme.primary),
            const SizedBox(width: 16),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قريباً', textAlign: TextAlign.right),
        content: Text('ميزة $feature قيد التطوير وستتوفر في التحديث القادم.',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
