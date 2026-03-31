import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'settings_screen.dart';
import 'asset_management_screen.dart';
import 'market_reports_screen.dart';
import 'edit_profile_screen.dart';
import 'marketplace_screen.dart';
import 'farmer_dashboard.dart' show ProfileScreen;
import 'request_worker_screen.dart';
import 'request_equipment_screen.dart';

class InvestorDashboard extends StatefulWidget {
  const InvestorDashboard({super.key});

  @override
  State<InvestorDashboard> createState() => _InvestorDashboardState();
}

class _InvestorDashboardState extends State<InvestorDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    InvestorHomeTab(),
    InvestorProjectsTab(),
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
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'الرئيسية'),
                _buildNavItem(1, Icons.business_center_rounded, 'مشاريعي'),
                _buildNavItem(2, Icons.shopping_cart_rounded, 'المتجر'),
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
          color: isSelected ? NabaTheme.primary.withOpacity(0.1) : Colors.transparent,
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

class InvestorHomeTab extends StatefulWidget {
  const InvestorHomeTab({super.key});

  @override
  State<InvestorHomeTab> createState() => _InvestorHomeTabState();
}

class _InvestorHomeTabState extends State<InvestorHomeTab> {
  double _totalInvestment = 0.0;
  int _activeAssetsCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchRealStats();
  }

  Future<void> _fetchRealStats() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('payerUserId', isEqualTo: user.id)
          .get();

      double sum = 0.0;
      for (var doc in paymentsQuery.docs) {
        sum += (doc.data()['amount'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          _totalInvestment = sum;
          // Number of distinct investments/payments = active assets for now
          _activeAssetsCount = paymentsQuery.docs.length; 
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching investor stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'بوابة المستثمر',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPortfolioCard(),
              const SizedBox(height: 24),
              const Text('الفرص الاستثمارية الحالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildPendingWellsList(),
              const SizedBox(height: 24),
              const Text('خدمات استراتيجية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionCard(
                    'إدارة الأصول',
                    Icons.account_balance_rounded,
                    Colors.purple,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AssetManagementScreen())),
                  ),
                  const SizedBox(width: 12),
                  _buildActionCard(
                    'تقارير السوق',
                    Icons.analytics_rounded,
                    Colors.orange,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MarketReportsScreen())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NabaTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: NabaTheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: _isLoadingStats
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                const Text('إجمالي القيمة الاستثمارية (تمويلاتك)',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${_totalInvestment.toStringAsFixed(0)} EGP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem(
                        _activeAssetsCount > 0 ? '+12.4%' : '0.0%', 'نمو سنوي',
                        _activeAssetsCount > 0 ? Colors.greenAccent : Colors.grey.shade300),
                    const SizedBox(width: 24),
                    _buildStatItem('$_activeAssetsCount', 'أصول نشطة', Colors.white),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String val, String label, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildPendingWellsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wells')
          .where('status', isEqualTo: WellStatus.pending.toString())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'لا توجد فرص لتمويل الآبار في الوقت الحالي',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final wellName = data['wellName'] ?? 'مشروع بئر';
            final area = data['irrigatedAreaFeddan']?.toString() ?? '0';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildInvestmentChance(
                'تمويل حفر وتجهيز $wellName',
                'يخدم مساحة $area فدان',
                'متاح للتمويل',
                Colors.blue,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInvestmentChance(String title, String loc, String roi, Color color) {
    return NabaCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قريباً: عرض التفاصيل الكاملة للمشروع وإتمام ضخ الأموال.')),
        );
      },
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.trending_up_rounded, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(loc,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(roi,
              style: const TextStyle(
                  color: NabaTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: NabaCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class InvestorProjectsTab extends StatelessWidget {
  const InvestorProjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabaAppBar(title: 'إدارة المشاريع', showBackButton: false),
      backgroundColor: NabaTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'طلبات المشاريع السريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProjectAction(
                    context,
                    title: 'طلب معدات',
                    icon: Icons.agriculture_rounded,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RequestEquipmentScreen())),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProjectAction(
                    context,
                    title: 'طلب عمال',
                    icon: Icons.group_rounded,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RequestWorkerScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'مشاريعك تحت التنفيذ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProjectCard(
              context,
              'مزرعة توشكى (طاقة شمسية)',
              'تمويل بنسبة 40%',
              Icons.solar_power_rounded,
              Colors.orange,
              progress: 0.7,
            ),
            const SizedBox(height: 16),
            _buildProjectCard(
              context,
              'بئر الشروق المشترك',
              'جارِ حفر البئر - عمق 120م',
              Icons.water_drop_rounded,
              Colors.blue,
              progress: 0.4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectAction(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return NabaCard(
      padding: const EdgeInsets.symmetric(vertical: 20),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, String title, String status, IconData icon, Color color, {required double progress}) {
    return NabaCard(
      padding: const EdgeInsets.all(16),
      onTap: () {},
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(status, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
