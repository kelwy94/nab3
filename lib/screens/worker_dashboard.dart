import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'farmer_dashboard.dart' show ProfileScreen;
import 'job_details_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    WorkerHomeTab(),
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
                _buildNavItem(1, Icons.person_rounded, 'حسابي'),
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
                  style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            Icon(icon, color: isSelected ? NabaTheme.primary : Colors.grey, size: 26),
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: NabaTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('لوحة العمل والتوظيف', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          final requestedJobs = jobProvider.jobs
              .where((j) => j.type == 'worker' && j.status == JobStatus.requested)
              .toList();

          final ongoingTasks = jobProvider.jobs
              .where((j) =>
                  j.type == 'worker' &&
                  j.assignedUserId == user?.id &&
                  (j.status == JobStatus.accepted || j.status == JobStatus.inProgress))
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
                  (j.status == JobStatus.paid || j.status == JobStatus.reviewed))
              .toList();

          return RefreshIndicator(
            onRefresh: () async => jobProvider.fetchJobs(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusHeader(context, isAvailable),
                  const SizedBox(height: 24),

                  // Ongoing Tasks
                  if (ongoingTasks.isNotEmpty) ...[
                    _buildSectionTitle('مهام جارية الآن', Icons.play_circle_fill, Colors.blue.shade700),
                    const SizedBox(height: 12),
                    ...ongoingTasks.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(
                            context, job,
                            job.status == JobStatus.inProgress ? 'جاري التنفيذ' : 'تم القبول - توجه للموقع',
                            Colors.blue,
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Pending Payment
                  if (finishedPendingPayment.isNotEmpty) ...[
                    _buildSectionTitle('مهام بانتظار الدفع', Icons.hourglass_top_rounded, Colors.orange.shade700),
                    const SizedBox(height: 12),
                    ...finishedPendingPayment.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(context, job, 'انتهى العمل - بانتظار تحصيل المبلغ', Colors.orange),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Available Jobs
                  _buildSectionTitle('طلبات عمل قريبة', Icons.work_outline_rounded, NabaTheme.primary),
                  const SizedBox(height: 12),
                  if (jobProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (requestedJobs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('لا توجد طلبات عمل حالياً. سيصلك تنبيه فور توفرها.',
                              style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ...requestedJobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(context, job, 'متاح للقبول', NabaTheme.primary),
                        )),

                  const SizedBox(height: 28),

                  // Stats
                  _buildSectionTitle('سجل أعمالك', Icons.bar_chart_rounded, Colors.purple),
                  const SizedBox(height: 12),
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

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStatusHeader(BuildContext context, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isAvailable
            ? const LinearGradient(colors: [Color(0xFF1B8A4E), Color(0xFF2ECC71)], begin: Alignment.topRight, end: Alignment.bottomLeft)
            : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isAvailable ? NabaTheme.primary : Colors.grey).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.check_circle_outline : Icons.pause_circle_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isAvailable ? 'أنت متاح للعمل الآن' : 'أنت في وضع الراحة',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  isAvailable ? 'سيصلك تنبيه عند وجود طلبات جديدة' : 'قم بتفعيل الوضع لتلقي الطلبات',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (v) {
              Provider.of<AuthProvider>(context, listen: false).toggleAvailability(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Job job, String statusText, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withOpacity(0.15), accentColor.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.work_outline_rounded, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(job.serviceType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(statusText, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text('${job.price?.toStringAsFixed(0) ?? "---"}', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('ج.م', style: TextStyle(color: accentColor.withOpacity(0.6), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        _stat('أعمال منجزة', completedCount, Colors.blue, Icons.check_circle_rounded),
        const SizedBox(width: 12),
        _stat('تقييمك', displayRating, Colors.orange, Icons.star_rounded),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, Job job) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(job.serviceType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('تم تحصيل المبلغ: ${job.price?.toStringAsFixed(0)} ج.م',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
