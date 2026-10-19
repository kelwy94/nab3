import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/well_provider.dart';
import '../theme.dart';
import '../widgets/naba_top_header.dart';
import '../widgets/irrigation_calendar.dart';
import '../widgets/naba_widgets.dart';
import '../widgets/sell_crop_card.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'job_details_screen.dart';
import 'job_history_screen.dart';
import 'marketplace_screen.dart';
import 'orders_history_screen.dart';
import 'product_form_screen.dart';
import 'request_worker_screen.dart';
import 'request_equipment_screen.dart';
import 'consultation_market_screen.dart';
import 'farmer_consultations_screen.dart';
import 'settings_screen.dart';
import 'land/land_market_banner.dart';
import 'wallet_screen.dart';
import 'well_create_screen.dart';
import 'well_details_screen.dart';
import 'well_search_screen.dart';

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
    LandPlotsTab(),
    WellManagementScreen(),
    MarketplaceScreen(),
    FarmerConsultationsScreen(),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.calendar_month_rounded, 'الجدول', imageAsset: 'assets/images/icons/schedule.png'),
                _buildNavItem(1, Icons.landscape_rounded, 'الأراضي', imageAsset: 'assets/images/icons/lands_v2.png'),
                _buildNavItem(2, Icons.water_drop_rounded, 'البئر', imageAsset: 'assets/images/icons/well.png'),
                _buildNavItem(3, Icons.shopping_bag_rounded, 'السوق', imageAsset: 'assets/images/icons/market_v2.png'),
                _buildNavItem(
                    4, Icons.assignment_turned_in_rounded, 'استشاراتي', imageAsset: 'assets/images/icons/consultations.png'),
                _buildNavItem(5, Icons.person_rounded, 'حسابي', imageAsset: 'assets/images/icons/profile.png'),
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

class FarmerHomeTab extends StatelessWidget {
  const FarmerHomeTab({super.key});

  static const List<Color> plotColors = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
  ];

  DateTime? _getNextIrrigationDate(Well well, String? userId, int plotIndex, {DateTime? dynamicStartDate}) {
    final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
    final start = dynamicStartDate ?? well.nextIrrigationDate;
    
    if (start != null) {
      final startDateUtc = DateTime.utc(start.year, start.month, start.day);
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      
      for (int i = 0; i <= freq * 2; i++) {
        final checkDate = today.add(Duration(days: i));
        if (checkDate.isBefore(startDateUtc)) continue;
        final diff = checkDate.difference(startDateUtc).inDays;
        if (diff % freq == 0) return checkDate;
      }
      return startDateUtc;
    }

    final userHash = userId?.hashCode.abs() ?? 0;
    final dayOffset = (userHash + plotIndex * 7) % freq;
    
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final baseDate = DateTime.utc(2024, 1, 1);

    for (int i = 0; i <= freq; i++) {
      final checkDate = today.add(Duration(days: i));
      final diff = checkDate.difference(baseDate).inDays;
      if (diff % freq == dayOffset) {
        return checkDate;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.user?.id;

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use StreamBuilder directly from Firestore for owned wells
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wells')
          .where('adminUserId', isEqualTo: userId)
          .snapshots(),
      builder: (context, ownedSnap) {
        // Also listen for membership wells
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('well_members')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, memberSnap) {
            if (ownedSnap.connectionState == ConnectionState.waiting &&
                memberSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Parse owned wells
            List<Well> approvedWells = [];
            bool hasPendingCreation = false;
            bool hasPendingJoin = false;

            if (ownedSnap.hasData) {
              for (var doc in ownedSnap.data!.docs) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  final statusStr = data['status']?.toString() ?? '';
                  if (statusStr.contains('approved')) {
                    approvedWells.add(_parseWellDoc(doc));
                  } else if (statusStr.contains('pending')) {
                    hasPendingCreation = true;
                  }
                } catch (e) {
                  debugPrint('Error parsing owned well: $e');
                }
              }
            }

            // Check membership status
            List<String> approvedMemberWellIds = [];
            if (memberSnap.hasData) {
              for (var doc in memberSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['status'] == 'approved') {
                  approvedMemberWellIds.add(data['wellId']);
                } else if (data['status'] == 'pending') {
                  hasPendingJoin = true;
                }
              }
            }

            // If we have member well IDs, fetch them
            if (approvedMemberWellIds.isNotEmpty) {
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('wells')
                    .where(FieldPath.documentId,
                        whereIn: approvedMemberWellIds.take(10).toList())
                    .get(),
                builder: (context, memberWellSnap) {
                  if (memberWellSnap.hasData) {
                    for (var doc in memberWellSnap.data!.docs) {
                      try {
                        final parsed = _parseWellDoc(doc);
                        if (!approvedWells.any((w) => w.id == parsed.id)) {
                          approvedWells.add(parsed);
                        }
                      } catch (e) {
                        debugPrint('Error parsing member well: $e');
                      }
                    }
                  }
                  return _buildHomeContent(context, approvedWells,
                      hasPendingCreation, hasPendingJoin, auth);
                },
              );
            }

            return _buildHomeContent(context, approvedWells, hasPendingCreation,
                hasPendingJoin, auth);
          },
        );
      },
    );
  }

  Well _parseWellDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Well(
      id: doc.id,
      adminUserId: data['adminUserId'] ?? '',
      wellName: data['wellName'] ?? '',
      location: Map<String, double>.from((data['location'] ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble()))),
      depthMeters: (data['depthMeters'] ?? 0.0).toDouble(),
      irrigatedAreaFeddan: (data['irrigatedAreaFeddan'] ?? 0.0).toDouble(),
      waterOutput: WaterOutput.values.firstWhere(
        (e) =>
            e.toString() == data['waterOutput'] ||
            e.toString().split('.').last == (data['waterOutput'] ?? ''),
        orElse: () => WaterOutput.medium,
      ),
      participantCount: data['participantCount'] ?? 1,
      flowRateM3PerHour: data['flowRateM3PerHour']?.toDouble(),
      fairnessRule: FairnessRule.values.firstWhere(
        (e) =>
            e.toString() == data['fairnessRule'] ||
            e.toString().split('.').last == (data['fairnessRule'] ?? ''),
        orElse: () => FairnessRule.proportional,
      ),
      allowedDays: List<String>.from(data['allowedDays'] ?? []),
      allowedHours: Map<String, String>.from((data['allowedHours'] ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString()))),
      slotDuration: data['slotDuration'] ?? 0,
      hoursPerPerson: (data['hoursPerPerson'] ?? 1.0).toDouble(),
      irrigationFrequencyDays: data['irrigationFrequencyDays'] ?? 1,
      status: WellStatus.values.firstWhere(
        (e) =>
            e.toString() == data['status'] ||
            e.toString().split('.').last == (data['status'] ?? ''),
        orElse: () => WellStatus.approved,
      ),
      pendingEdits: data['pendingEdits'] != null
          ? Map<String, dynamic>.from(data['pendingEdits'])
          : null,
    );
  }

  Widget _buildHomeContent(BuildContext context, List<Well> wells,
      bool hasPendingCreation, bool hasPendingJoin, AuthProvider auth) {
    if (wells.isEmpty) {
      if (hasPendingCreation) {
        return const Scaffold(
          appBar: PreferredSize(preferredSize: const Size.fromHeight(80), child: SafeArea(child: NabaTopHeader(title: 'الرئيسية'))),
          backgroundColor: NabaTheme.background,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty_rounded,
                      size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text('طلب إنشاء البئر قيد المراجعة',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                  SizedBox(height: 8),
                  Text(
                      'طلبك قيد المراجعة والاعتماد من الإدارة المركزية. سيتم تفعيل جدولك فور الموافقة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NabaTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }

      if (hasPendingJoin) {
        return const Scaffold(
          appBar: PreferredSize(preferredSize: const Size.fromHeight(80), child: SafeArea(child: NabaTopHeader(title: 'الرئيسية'))),
          backgroundColor: NabaTheme.background,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_bottom_rounded,
                      size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text('طلب الانضمام قيد المراجعة',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  SizedBox(height: 8),
                  Text(
                      'طلب انضمامك للبئر قيد المراجعة. سيظهر لك الجدول الخاص بالبئر هنا بعد الموافقة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NabaTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: PreferredSize(preferredSize: const Size.fromHeight(80), child: SafeArea(child: NabaTopHeader(title: 'الرئيسية'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.water_drop_outlined,
                  size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text('لا يوجد جدول ري',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('هل تريد تسجيل بئر او التسجيل في بئر ؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              _buildSpecialCard(
                context,
                title: 'تسجيل بئر جديد',
                desc: 'قم بإنشاء بئر جديد لتكون مديراً له',
                icon: Icons.add_circle_rounded,
                color: Colors.teal,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WellCreateScreen())),
              ),
              const SizedBox(height: 16),
              _buildSpecialCard(
                context,
                title: 'التسجيل في بئر',
                desc: 'ابحث عن آبار منطقتك وانضم لبئر قائم',
                icon: Icons.search_rounded,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WellSearchScreen()));
                },
              ),
              const SizedBox(height: 32),
              _buildQuickActionsAndTracking(context, auth),
            ],
          ),
        ),
      );
    }

    // Has wells - show calendar with next irrigation date banner using land plots
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: NabaTopHeader(
            title: 'جدول الري',
            trailing: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('well_members')
            .where('userId', isEqualTo: auth.user?.id)
            .where('wellId', isEqualTo: wells.first.id)
            .snapshots(),
        builder: (context, memberSnapshot) {
          final memberDoc = memberSnapshot.data?.docs.isNotEmpty == true
              ? memberSnapshot.data!.docs.first
              : null;
          final manualSchedule = memberDoc != null
              ? (memberDoc.data() as Map<String, dynamic>)['manualSchedule']
              : null;
          
          final dynamicStartDate = (memberDoc != null &&
                  (memberDoc.data() as Map<String, dynamic>)
                      .containsKey('nextIrrigationDate'))
              ? ((memberDoc.data() as Map<String, dynamic>)['nextIrrigationDate']
                      as Timestamp)
                  .toDate()
              : wells.isNotEmpty ? wells.first.nextIrrigationDate : null;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('land_plots')
                .where('ownerId', isEqualTo: auth.user?.id)
                .where('status', isEqualTo: 'approved')
                .snapshots(),
            builder: (context, plotSnapshot) {
              final plotDocs = plotSnapshot.data?.docs ?? [];

              // Find the soonest next irrigation across all plots
              List<Map<String, dynamic>> nextDates = [];

              if (wells.first.fairnessRule == FairnessRule.manual &&
                  manualSchedule != null) {
                final dayOffset = manualSchedule['dayOffset'] as int;
                final freq = wells.first.irrigationFrequencyDays > 0
                    ? wells.first.irrigationFrequencyDays
                    : 1;

                final now = DateTime.now();
                final today = DateTime.utc(now.year, now.month, now.day);
                final baseDate = DateTime.utc(2024, 1, 1);

                DateTime? nextDate;
                for (int i = 0; i <= freq; i++) {
                  final checkDate = today.add(Duration(days: i));
                  final diff = checkDate.difference(baseDate).inDays;
                  if (diff % freq == dayOffset) {
                    nextDate = checkDate;
                    break;
                  }
                }

                if (nextDate != null) {
                  nextDates.add({
                    'date': nextDate,
                    'name': 'موعدك (يدوي)',
                    'color': NabaTheme.primary,
                  });
                }
              } else if (plotDocs.isEmpty) {
                // No plots - use default
                final nextDate =
                    _getNextIrrigationDate(wells.first, auth.user?.id, 0, dynamicStartDate: dynamicStartDate);
                if (nextDate != null) {
                  nextDates.add({
                    'date': nextDate,
                    'name': wells.first.wellName,
                    'color': NabaTheme.primary,
                  });
                }
              } else {
                for (int i = 0; i < plotDocs.length; i++) {
                  final data = plotDocs[i].data() as Map<String, dynamic>;
                  final nextDate =
                      _getNextIrrigationDate(wells.first, auth.user?.id, i, dynamicStartDate: dynamicStartDate);
                  if (nextDate != null) {
                    nextDates.add({
                      'date': nextDate,
                      'name': data['name'] ?? 'قطعة ${i + 1}',
                      'color': plotColors[i % plotColors.length],
                    });
                  }
                }
              }

              // Sort by nearest date
              nextDates.sort((a, b) =>
                  (a['date'] as DateTime).compareTo(b['date'] as DateTime));

              return SingleChildScrollView(
                  child: Column(
                children: [
                  // Banners for each plot's next irrigation
                  if (nextDates.isNotEmpty)
                    ...nextDates.take(3).map((info) {
                      final nextDate = info['date'] as DateTime;
                      final plotName = info['name'] as String;
                      final plotColor = info['color'] as Color;
                      final isToday = nextDate.year == DateTime.now().year &&
                          nextDate.month == DateTime.now().month &&
                          nextDate.day == DateTime.now().day;

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [plotColor, plotColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: plotColor.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(
                              isToday
                                  ? Icons.water_drop_rounded
                                  : Icons.calendar_today_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isToday
                                    ? '🌊 ري $plotName اليوم!'
                                    : '📅 ري $plotName - يوم ${nextDate.day}/${nextDate.month}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  _buildQuickActionsAndTracking(context, auth),
                  const SizedBox(height: 16),
                  // Calendar
                  IrrigationCalendar(
                    well: wells.isNotEmpty ? wells.first : null,
                  ),
                ],
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsAndTracking(
      BuildContext context, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const SellCropCard(),
        const SizedBox(height: 8),
// Quick Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'طلب معدة',
                  icon: Icons.agriculture_rounded,
                  imageAsset: 'assets/images/icons/tractor.png',
                  color: Colors.orange.shade700,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RequestEquipmentScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'طلب عامل',
                  icon: Icons.engineering_rounded,
                  imageAsset: 'assets/images/icons/worker.png',
                  color: Colors.blue.shade700,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RequestWorkerScreen())),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'بيع أو شراء',
                  icon: Icons.store_rounded,
                  imageAsset: 'assets/images/icons/trade.png',
                  color: Colors.teal.shade500,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('السوق', textAlign: TextAlign.right),
                        content: const Text(
                          'هل تريد بيع منتج أم تصفح السوق للشراء؟',
                          textAlign: TextAlign.right,
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // شراء
                              // Just close dialog if they want to buy, they can click the market tab
                              // Or push MarketplaceScreen directly
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen()));
                            },
                            child: const Text('شراء', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // بيع
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            child: const Text('بيع', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'استشارات هندسية',
                  icon: Icons.workspace_premium_rounded,
                  imageAsset: 'assets/images/icons/consultations.png',
                  color: Colors.teal.shade500,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConsultationMarketScreen())),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LandMarketBanner(),
        ),
        const SizedBox(height: 8),
// Active Tracking Section
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('requesterUserId', isEqualTo: auth.user?.id)
              .where('status', whereIn: [
            JobStatus.accepted.toString(),
            JobStatus.inProgress.toString(),
            JobStatus.completed.toString(),
            JobStatus.paid.toString()
          ]).snapshots(),
          builder: (context, jobSnap) {
            final jobDocs = jobSnap.data?.docs ?? [];
            if (jobDocs.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'تتبع الطلبات الجارية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // RTL
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: jobDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          jobDocs[index].data() as Map<String, dynamic>;
                      final status = data['status'] ?? '';
                      final type = data['serviceType'] ?? '';

                      Color statusColor = Colors.orange;
                      if (status.contains('inProgress')) {
                        statusColor = NabaTheme.primary;
                      }
                      if (status.contains('completed')) {
                        statusColor = Colors.green;
                      }
                      if (status.contains('paid')) statusColor = Colors.teal;

                      return GestureDetector(
                        onTap: () {
                          final job = Job(
                            id: jobDocs[index].id,
                            requesterUserId: data['requesterUserId'],
                            assignedUserId: data['assignedUserId'],
                            type: data['type'] ?? 'worker',
                            serviceType: data['serviceType'] ?? '',
                            location: const {'lat': 0.0, 'lng': 0.0},
                            startTime:
                                (data['startTime'] as Timestamp).toDate(),
                            endTime: (data['endTime'] as Timestamp).toDate(),
                            status: JobStatus.values.firstWhere(
                                (e) => e.toString() == status,
                                orElse: () => JobStatus.requested),
                            price: (data['price'] as num?)?.toDouble(),
                            notes: data['notes'] ?? '',
                            address: data['address'],
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => JobDetailsScreen(job: job)),
                          );
                        },
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.track_changes_rounded,
                                  color: statusColor, size: 24),
                              const SizedBox(height: 6),
                              Text(
                                type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                _getStatusLabel(status),
                                style:
                                    TextStyle(color: statusColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    if (status.contains('accepted')) return 'تم القبول';
    if (status.contains('inProgress')) return 'جاري التنفيذ';
    if (status.contains('completed')) return 'انتهى - ادفع';
    if (status.contains('paid')) return 'تم الدفع - قيم';
    return 'قيد المراجعة';
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? imageAsset,
    required Color color,
    required VoidCallback onTap,
  }) {
    return NabaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: imageAsset != null ? null : LinearGradient(
                colors: [color.withOpacity(0.7), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              color: imageAsset != null ? Colors.white : null,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: imageAsset != null
                ? Image.asset(imageAsset, width: 36, height: 36)
                : Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

// -=-=-=-=-=- Land Plots Tab -=-=-=-=-=-
class LandPlotsTab extends StatelessWidget {
  const LandPlotsTab({super.key});

  static const List<Color> plotColors = [
    Color(0xFF2E7D32), // أخضر غامق
    Color(0xFF1565C0), // أزرق
    Color(0xFFE65100), // برتقالي
    Color(0xFF6A1B9A), // بنفسجي
    Color(0xFFC62828), // أحمر
    Color(0xFF00838F), // تركواز
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: NabaTopHeader(
            title: 'قطع الأراضي',
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              onPressed: () => _showAddPlotDialog(context),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('land_plots')
            .where('ownerId', isEqualTo: user?.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.landscape_rounded,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('لم تضف أي قطع أراضي بعد',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                        'أضف قطع أراضيك لتحصل على حصة مياه منفصلة لكل قطعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 24),
                    NabaButton(
                      text: 'إضافة قطعة أرض',
                      onPressed: () => _showAddPlotDialog(context),
                      icon: Icons.add_circle_rounded,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Legend card
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: NabaCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('دليل الألوان في جدول الري',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: List.generate(docs.length, (i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            final plotName = data['name'] ?? 'قطعة ${i + 1}';
                            final color = plotColors[i % plotColors.length];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(plotName,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: color,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = docs[index - 1].data() as Map<String, dynamic>;
              final docId = docs[index - 1].id;
              final plotName = data['name'] ?? 'قطعة $index';
              final area = data['area'] ?? 0.0;
              final wellName = data['wellName'] ?? 'غير محدد';
              final crops = data['crops'] ?? '';
              final status = data['status'] ?? 'pending';
              final color = plotColors[(index - 1) % plotColors.length];
              final isPending = status == 'pending';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  opacity: isPending ? 0.7 : 1.0,
                  child: NabaCard(
                    padding: const EdgeInsets.all(16),
                    border: Border(
                      right: BorderSide(color: color, width: 4),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.landscape_rounded,
                              color: color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(plotName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: color)),
                              const SizedBox(height: 4),
                              Text('المساحة: $area فدان • البئر: $wellName',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                              if (isPending)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('⏳ قيد المراجعة',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              if (crops.isNotEmpty)
                                Text('المحاصيل: $crops',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 20),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('land_plots')
                                .doc(docId)
                                .delete();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddPlotDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cropsCtrl = TextEditingController();
    final customWellCtrl = TextEditingController();

    // Fetch all wells
    final wellSnap = await FirebaseFirestore.instance.collection('wells').get();
    final allWellsNames = wellSnap.docs
        .map((doc) => (doc.data()['wellName'] ?? '') as String)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    String? selectedWell;
    if (allWellsNames.isNotEmpty) {
      selectedWell = allWellsNames.first;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: NabaTheme.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('إضافة قطعة أرض',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                      'كل قطعة أرض ليها حصة مياه منفصلة ولون مختلف في جدول الري',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const Text('اسم القطعة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(hintText: 'مثلاً: الأرض الشرقية'),
                  ),
                  const SizedBox(height: 20),
                  const Text('المساحة (فدان)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: areaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '2.5'),
                  ),
                  const SizedBox(height: 20),
                  const Text('البئر المرتبط',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWell,
                    items: [
                      ...allWellsNames.map((name) =>
                          DropdownMenuItem(value: name, child: Text(name))),
                      const DropdownMenuItem(
                          value: 'أخرى', child: Text('أخرى (إدخال يدوي)')),
                    ],
                    onChanged: (v) => setModalState(() => selectedWell = v),
                    decoration: const InputDecoration(hintText: 'اختر البئر'),
                  ),
                  if (selectedWell == 'أخرى') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customWellCtrl,
                      decoration:
                          const InputDecoration(hintText: 'اكتب اسم البئر هنا'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('المحاصيل (اختياري)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cropsCtrl,
                    decoration:
                        const InputDecoration(hintText: 'قمح، ذرة، إلخ'),
                  ),
                  const SizedBox(height: 32),
                  NabaButton(
                    text: 'حفظ القطعة',
                    icon: Icons.save_rounded,
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || areaCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('يرجى ملء الاسم والمساحة')),
                        );
                        return;
                      }

                      final finalWellName = (selectedWell == 'أخرى')
                          ? customWellCtrl.text.trim()
                          : (selectedWell ?? '');
                      if (finalWellName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('يرجى تحديد أو كتابة اسم البئر')),
                        );
                        return;
                      }

                      final user =
                          Provider.of<AuthProvider>(context, listen: false)
                              .user;
                      await FirebaseFirestore.instance
                          .collection('land_plots')
                          .add({
                        'ownerId': user?.id,
                        'ownerName': user?.fullName,
                        'name': nameCtrl.text,
                        'area': double.tryParse(areaCtrl.text) ?? 0,
                        'wellName': finalWellName,
                        'crops': cropsCtrl.text,
                        'status': 'pending',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'تم إرسال طلب إضافة قطعة الأرض للإدارة!')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WellManagementScreen extends StatelessWidget {
  const WellManagementScreen({super.key});

  Well _parseWellDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Well(
      id: doc.id,
      adminUserId: data['adminUserId'] ?? '',
      wellName: data['wellName'] ?? '',
      location: Map<String, double>.from((data['location'] ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble()))),
      depthMeters: (data['depthMeters'] ?? 0.0).toDouble(),
      irrigatedAreaFeddan: (data['irrigatedAreaFeddan'] ?? 0.0).toDouble(),
      waterOutput: WaterOutput.values.firstWhere(
        (e) =>
            e.toString() == data['waterOutput'] ||
            e.toString().split('.').last == (data['waterOutput'] ?? ''),
        orElse: () => WaterOutput.medium,
      ),
      participantCount: data['participantCount'] ?? 1,
      flowRateM3PerHour: data['flowRateM3PerHour']?.toDouble(),
      fairnessRule: FairnessRule.values.firstWhere(
        (e) =>
            e.toString() == data['fairnessRule'] ||
            e.toString().split('.').last == (data['fairnessRule'] ?? ''),
        orElse: () => FairnessRule.proportional,
      ),
      allowedDays: List<String>.from(data['allowedDays'] ?? []),
      allowedHours: Map<String, String>.from((data['allowedHours'] ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString()))),
      slotDuration: data['slotDuration'] ?? 0,
      hoursPerPerson: (data['hoursPerPerson'] ?? 1.0).toDouble(),
      irrigationFrequencyDays: data['irrigationFrequencyDays'] ?? 1,
      status: WellStatus.values.firstWhere(
        (e) =>
            e.toString() == data['status'] ||
            e.toString().split('.').last == (data['status'] ?? ''),
        orElse: () => WellStatus.approved,
      ),
      pendingEdits: data['pendingEdits'] != null
          ? Map<String, dynamic>.from(data['pendingEdits'])
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.user?.id;

    return Scaffold(
      appBar: PreferredSize(preferredSize: const Size.fromHeight(80), child: SafeArea(child: NabaTopHeader(title: 'إدارة البئر'))),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wells')
                  .where('adminUserId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, ownedSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('well_members')
                      .where('userId', isEqualTo: userId)
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, memberSnap) {
                    List<Well> wells = [];

                    // Parse owned approved wells
                    if (ownedSnap.hasData) {
                      for (var doc in ownedSnap.data!.docs) {
                        try {
                          final w = _parseWellDoc(doc);
                          if (w.status == WellStatus.approved) {
                            wells.add(w);
                          }
                        } catch (e) {
                          debugPrint('Error parsing well: $e');
                        }
                      }
                    }

                    // For member wells, we need to fetch their details
                    List<String> memberWellIds = [];
                    if (memberSnap.hasData) {
                      for (var doc in memberSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        memberWellIds.add(data['wellId']);
                      }
                    }

                    if (memberWellIds.isNotEmpty) {
                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('wells')
                            .where(FieldPath.documentId,
                                whereIn: memberWellIds.take(10).toList())
                            .get(),
                        builder: (context, memberWellSnap) {
                          if (memberWellSnap.hasData) {
                            for (var doc in memberWellSnap.data!.docs) {
                              try {
                                final parsed = _parseWellDoc(doc);
                                if (!wells.any((w) => w.id == parsed.id)) {
                                  wells.add(parsed);
                                }
                              } catch (e) {
                                debugPrint('Error parsing member well: $e');
                              }
                            }
                          }
                          return _buildBody(context, wells);
                        },
                      );
                    }

                    return _buildBody(context, wells);
                  },
                );
              },
            ),
    );
  }

  Widget _buildBody(BuildContext context, List<Well> wells) {
    return SingleChildScrollView(
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [NabaTheme.primaryLight, NabaTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NabaTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.water_drop_rounded,
                color: Colors.white, size: 24),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.7), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: NabaTopHeader(
            title: 'حسابي - المزارع',
            trailing: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
          ),
        ),
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
                          ? const Icon(Icons.person_rounded,
                              size: 50, color: Colors.grey)
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
                      onPressed:
                          _isUploading ? null : () => _pickAndUploadImage(auth),
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
            _buildProfileItem(
                context, Icons.work_history_rounded, 'سجل الطلبات السابقة',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JobHistoryScreen()));
            }),
            _buildProfileItem(
                context, Icons.local_shipping_rounded, 'تتبع مشترياتي (المتجر)',
                onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OrdersHistoryScreen()));
            }),
            _buildProfileItem(context, Icons.history_rounded, 'تاريخ الري',
                onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('لا يوجد عمليات ري سابقة لعرضها.')),
              );
            }),
            _buildProfileItem(context, Icons.account_balance_wallet_outlined,
                'المحفظة المالية', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()));
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

  // ignore: unused_element
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
