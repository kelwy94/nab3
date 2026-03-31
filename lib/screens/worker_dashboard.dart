import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../models/types.dart';
import 'settings_screen.dart';
import 'job_details_screen.dart';
import 'farmer_dashboard.dart' show ProfileScreen, WellManagementScreen;
import '../widgets/irrigation_calendar.dart';
import 'dart:ui' as ui;

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    WorkerHomeTab(),
    IrrigationCalendar(),
    WellManagementScreen(),
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
                _buildNavItem(0, Icons.work_rounded, 'الرئيسية'),
                _buildNavItem(1, Icons.calendar_month_rounded, 'الجدول'),
                _buildNavItem(2, Icons.water_drop_rounded, 'البئر'),
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

class WorkerHomeTab extends StatelessWidget {
  const WorkerHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isAvailable = user?.extraData?['isAvailable'] ?? false;

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'لوحة العمل والتوظيف',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          final requestedJobs = jobProvider.jobs
              .where(
                  (j) => j.type == 'worker' && j.status == JobStatus.requested)
              .toList();

          final ongoingTasks = jobProvider.jobs
              .where((j) =>
                  j.type == 'worker' &&
                  j.assignedUserId == user?.id &&
                  (j.status == JobStatus.accepted ||
                      j.status == JobStatus.inProgress))
              .toList();

          final finishedPendingPayment = jobProvider.jobs
              .where((j) =>
                  j.type == 'worker' &&
                  j.assignedUserId == user?.id &&
                  j.status == JobStatus.completed)
              .toList();

          final workHistory = jobProvider.jobs
              .where((j) =>
                  j.type == 'worker' &&
                  j.assignedUserId == user?.id &&
                  (j.status == JobStatus.paid ||
                      j.status == JobStatus.reviewed))
              .toList();

          return RefreshIndicator(
            onRefresh: () async => jobProvider.fetchJobs(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusHeader(context, isAvailable),
                  const SizedBox(height: 32),
                  if (ongoingTasks.isNotEmpty) ...[
                    const Text('مهام جارية الآن',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: NabaTheme.primary)),
                    const SizedBox(height: 16),
                    ...ongoingTasks.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildJobCard(
                            context,
                            job,
                            job.status == JobStatus.inProgress
                                ? 'جاري التنفيذ'
                                : 'تم القبول - توجه للموقع',
                          ),
                        )),
                    const SizedBox(height: 32),
                  ],
                  if (finishedPendingPayment.isNotEmpty) ...[
                    const Text('مهام بانتظار الدفع',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    const SizedBox(height: 16),
                    ...finishedPendingPayment.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildJobCard(
                            context,
                            job,
                            'انتهى العمل - بانتظار تحصيل المبلغ',
                          ),
                        )),
                    const SizedBox(height: 32),
                  ],
                  const Text('طلبات عمل قريبة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (jobProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (requestedJobs.isEmpty)
                    const NabaCard(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                            'لا توجد طلبات عمل حالياً. سيصلك تنبيه فور توفرها.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...requestedJobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildJobCard(
                            context,
                            job,
                            'متاح للقبول',
                          ),
                        )),
                  const SizedBox(height: 32),
                  const Text('سجل أعمالك',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildMiniStatRow(workHistory.length.toString(), user),
                  const SizedBox(height: 16),
                  if (workHistory.isNotEmpty)
                    ...workHistory.reversed.take(5).map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildHistoryCard(context, job),
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, bool isAvailable) {
    return NabaCard(
      padding: const EdgeInsets.all(20),
      onTap: () {},
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isAvailable ? NabaTheme.primaryGradient : null,
              color: !isAvailable ? Colors.grey.shade200 : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color: isAvailable ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isAvailable ? 'أنت متاح للعمل الآن' : 'أنت في وضع الراحة',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  isAvailable
                      ? 'سيصلك تنبيه عند وجود طلبات جديدة'
                      : 'قم بتفعيل الوضع لتلقي الطلبات',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (v) {
              Provider.of<AuthProvider>(context, listen: false)
                  .toggleAvailability(v);
            },
            activeColor: NabaTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Job job, String loc) {
    return NabaCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)));
      },
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: NabaTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.work_outline_rounded,
                color: NabaTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(job.serviceType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(loc,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${job.price?.toStringAsFixed(0) ?? "---"} ج.م',
              style: const TextStyle(
                  color: NabaTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildMiniStatRow(String completedCount, User? user) {
    final rawRating = user?.extraData?['rating'];
    String displayRating = 'جديد';
    if (rawRating != null && rawRating is num && rawRating > 0) {
      displayRating = rawRating.toStringAsFixed(1);
    }

    return Row(
      children: [
        _stat('أعمال منجزة', completedCount, Colors.blue),
        const SizedBox(width: 12),
        _stat('تقييمك', displayRating, Colors.orange),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, Job job) {
    return NabaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)));
      },
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(job.serviceType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('تم تحصيل المبلغ: ${job.price?.toStringAsFixed(0)} ج.م',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String val, Color color) {
    return Expanded(
      child: NabaCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        onTap: () {},
        child: Column(
          children: [
            Text(val,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
