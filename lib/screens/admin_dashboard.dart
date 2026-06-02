import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../providers/well_provider.dart';
import '../theme.dart';
import 'settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUnlocked = true;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _adminNoteController = TextEditingController();

  late WellProvider _wellProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wellProvider = Provider.of<WellProvider>(context, listen: false);
    // Defer to avoid calling notifyListeners during build
    Future.microtask(() => _wellProvider.enableAdminMode());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
    _adminNoteController.dispose();
    // Defer to avoid notifyListeners during widget tree lock
    Future.microtask(() {
      if (!_wellProvider.isDisposed) _wellProvider.disableAdminMode();
    });
    super.dispose();
  }

  Widget _buildLockScreen() {
    return Container(
      color: NabaTheme.background,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NabaTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: NabaTheme.primary, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'لوحة التحكم محمية',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NabaTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'الرجاء إدخال كلمة المرور للمتابعة',
                textAlign: TextAlign.center,
                style: TextStyle(color: NabaTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '•••••',
                  hintStyle: TextStyle(color: Colors.grey.shade300),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) => _attemptUnlock(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _attemptUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('دخول',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _attemptUnlock() {
    if (_passwordController.text == '12321') {
      setState(() => _isUnlocked = true);
      context.read<WellProvider>().enableAdminMode();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير صحيحة')),
      );
    }
  }

  // ignore: unused_element
  void _showPasswordDialog() {
    // Deprecated in favor of _buildLockScreen
  }

  bool _showOnlyPending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: _buildAppBar(),
      body: !_isUnlocked
          ? _buildLockScreen()
          : Column(
              children: [
                _buildClassicTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildUsersTab(),
                      _buildJobsTab(),
                      _buildWellsTab(),
                      _buildLandPlotsTab(),
                      _buildDataExplorerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: NabaTheme.primary,
      elevation: 4,
      foregroundColor: Colors.white,
      title: const Text('لوحة التحكم',
          style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildClassicTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: NabaTheme.primary,
        indicatorWeight: 2,
        labelColor: NabaTheme.primary,
        unselectedLabelColor: NabaTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        onTap: (index) => setState(() {}),
        tabs: const [
          Tab(text: 'إحصائيات', height: 36),
          Tab(text: 'المستخدمين', height: 36),
          Tab(text: 'المهام', height: 36),
          Tab(text: 'الآبار', height: 36),
          Tab(text: 'الأراضي', height: 36),
          Tab(text: 'البيانات', height: 36),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final authProvider = context.watch<AuthProvider>();
    final jobProvider = context.watch<JobProvider>();
    final allUsers = authProvider.allUsers;
    final allJobs = jobProvider.jobs;
    final isLoading = authProvider.isLoading || jobProvider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allUsers.isEmpty && allJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'لم يتم العثور على بيانات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'تأكد من الاتصال بالإنترنت وقم بتحديث الصفحة.\nإذا كنت تستخدم متصفح الويب، يرجى التأكد من صلاحيات قاعدة البيانات.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader('نظرة عامة'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildClassicStatCard(
                'المستخدمين',
                '${allUsers.length} (${allUsers.where((u) => u.status == AccountStatus.pending).length} معلق)',
                Icons.people,
                NabaTheme.primary,
                onTap: () => _tabController.animateTo(1)),
            _buildClassicStatCard('طلبات العمال (مهام)',
                allJobs.length.toString(), Icons.assignment, Colors.orange,
                onTap: () => _tabController.animateTo(2)),
            _buildClassicStatCard(
                'مكتملة',
                allJobs
                    .where((j) => j.status == JobStatus.completed)
                    .length
                    .toString(),
                Icons.done_all,
                Colors.green,
                onTap: () => _tabController.animateTo(2)),
            _buildClassicStatCard(
                'قيد التنفيذ',
                allJobs
                    .where((j) => j.status == JobStatus.inProgress)
                    .length
                    .toString(),
                Icons.sync,
                Colors.blue,
                onTap: () => _tabController.animateTo(2)),
          ],
        ),
        if (allUsers.any((u) => u.status == AccountStatus.pending)) ...[
          const SizedBox(height: 32),
          _buildSectionHeader('طلبات تسجيل بانتظار الموافقة'),
          const SizedBox(height: 12),
          ...allUsers
              .where((u) => u.status == AccountStatus.pending)
              .map((u) => _buildUserApprovalItem(u)),
        ],
        const SizedBox(height: 32),
        _buildSectionHeader('النشاط الأخير'),
        const SizedBox(height: 16),
        if (allUsers.isEmpty)
          const Center(child: Text('لا يوجد نشاط مستخدمين حالياً'))
        else
          ...allUsers.take(10).map((u) => _buildActivityItem(u)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: NabaTheme.textPrimary),
      textAlign: TextAlign.right,
    );
  }

  Widget _buildUserApprovalItem(User u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(u.fullName[0],
                    style: const TextStyle(color: Colors.orange)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(u.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('طلب انضمام كـ ${_getRoleName(u.role)}',
                        style: const TextStyle(
                            fontSize: 12, color: NabaTheme.textSecondary)),
                    Text(u.phone,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context
                      .read<AuthProvider>()
                      .updateUserStatus(
                          u.id, {'status': AccountStatus.approved.toString()}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('موافقة وقبول'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmDeleteUser(u),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildVibrantStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: NabaTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(User u) {
    return InkWell(
      onTap: () => _showUserDetail(u),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            CircleAvatar(
              backgroundColor: NabaTheme.primary.withOpacity(0.1),
              child: Text(u.fullName[0],
                  style: const TextStyle(color: NabaTheme.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('انضم كـ ${_getRoleName(u.role)}',
                      style: const TextStyle(
                          fontSize: 12, color: NabaTheme.textSecondary)),
                ],
              ),
            ),
            Text(intl.DateFormat('jm', 'ar').format(u.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: NabaTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final allUsers = context.watch<AuthProvider>().allUsers;
    final filteredUsers = _showOnlyPending
        ? allUsers.where((u) => u.status == AccountStatus.pending).toList()
        : allUsers;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي: ${filteredUsers.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Text('بانتظار الموافقة فقط',
                      style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _showOnlyPending,
                    activeThumbColor: NabaTheme.primary,
                    onChanged: (val) => setState(() => _showOnlyPending = val),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final u = filteredUsers[index];
              return _buildUserCard(u);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassicStatCard(
      String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: NabaTheme.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: NabaTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(User u) {
    _adminNoteController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: NabaTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'بيانات ${_getRoleName(u.role)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: NabaTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildDetailCard(
                      'المعلومات الأساسية',
                      [
                        'الاسم: ${u.fullName}',
                        'رقم الهاتف: ${u.phone}',
                        'البريد: ${u.email ?? "غير مسجل"}',
                        'العنوان: ${u.address}',
                        'رقم البطاقة: ${u.nationalIdHash}',
                      ],
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    if (u.extraData != null && u.extraData!.isNotEmpty)
                      _buildDetailCard(
                        'بيانات العمل / الإضافية',
                        u.extraData!.entries
                            .where((e) =>
                                e.key != 'password' &&
                                e.key != 'adminNote' &&
                                e.key != 'nationalIdFrontBase64' &&
                                e.key != 'nationalIdBackBase64')
                            .map((e) => '${_translateKey(e.key)}: ${e.value}')
                            .toList(),
                        Icons.business_center_outlined,
                      ),
                    if (u.extraData != null &&
                        u.extraData!['nationalIdFrontBase64'] != null) ...[
                      const SizedBox(height: 16),
                      const Text('صورة وجه البطاقة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                            base64Decode(u.extraData!['nationalIdFrontBase64']),
                            fit: BoxFit.contain),
                      ),
                    ],
                    if (u.extraData != null &&
                        u.extraData!['nationalIdBackBase64'] != null) ...[
                      const SizedBox(height: 16),
                      const Text('صورة ظهر البطاقة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                            base64Decode(u.extraData!['nationalIdBackBase64']),
                            fit: BoxFit.contain),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'ملاحظة الإدارة (ستظهر للمستخدم)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adminNoteController,
                      maxLines: 3,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'اكتب ملاحظة هنا...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (u.status == AccountStatus.pending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await context
                                    .read<AuthProvider>()
                                    .updateUserStatus(
                                      u.id,
                                      {
                                        'status':
                                            AccountStatus.approved.toString()
                                      },
                                      adminNote: _adminNoteController.text,
                                    );
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('موافقة وقبول',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('تأكيد الرفض'),
                                    content: const Text(
                                        'هل أنت متأكد من رفض هذا الطلب؟'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('رفض الطلب',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await context
                                      .read<AuthProvider>()
                                      .updateUserStatus(
                                        u.id,
                                        {
                                          'status':
                                              AccountStatus.rejected.toString()
                                        },
                                        adminNote: _adminNoteController.text,
                                      );
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('رفض الطلب'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Center(
                        child: Text(
                          'الحالة الحالية: ${_getAccountStatusName(u.status)}',
                          style: TextStyle(
                              color: u.status == AccountStatus.approved
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<String> details, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: NabaTheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24),
          ...details.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  d,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 14, color: NabaTheme.textSecondary),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWellsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: NabaTheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: NabaTheme.primary,
              tabs: [
                Tab(text: 'الآبار المعتمدة'),
                Tab(text: 'طلبات الآبار'),
                Tab(text: 'طلبات الانضمام'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildApprovedWellsList(),
                _buildPendingWellsList(),
                _buildPendingJoinsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Well _parseWellDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Well(
      id: doc.id,
      adminUserId: data['adminUserId'] ?? '',
      wellName: data['wellName'] ?? '',
      location: Map<String, double>.from((data['location'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      depthMeters: (data['depthMeters'] ?? 0.0).toDouble(),
      irrigatedAreaFeddan: (data['irrigatedAreaFeddan'] ?? 0.0).toDouble(),
      waterOutput: WaterOutput.values.firstWhere(
        (e) => e.toString() == data['waterOutput'] || e.toString().split('.').last == data['waterOutput'],
        orElse: () => WaterOutput.medium,
      ),
      participantCount: data['participantCount'] ?? 1,
      flowRateM3PerHour: data['flowRateM3PerHour']?.toDouble(),
      fairnessRule: FairnessRule.values.firstWhere(
        (e) => e.toString() == data['fairnessRule'] || e.toString().split('.').last == data['fairnessRule'],
        orElse: () => FairnessRule.proportional,
      ),
      allowedDays: List<String>.from(data['allowedDays'] ?? []),
      allowedHours: Map<String, String>.from((data['allowedHours'] ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()))),
      slotDuration: data['slotDuration'] ?? 0,
      hoursPerPerson: (data['hoursPerPerson'] ?? 1.0).toDouble(),
      irrigationFrequencyDays: data['irrigationFrequencyDays'] ?? 1,
      status: WellStatus.values.firstWhere(
        (e) => e.toString() == data['status'] || e.toString().split('.').last == data['status'],
        orElse: () => WellStatus.approved,
      ),
      pendingEdits: data['pendingEdits'] != null
          ? Map<String, dynamic>.from(data['pendingEdits'])
          : null,
    );
  }

  Widget _buildApprovedWellsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wells')
          .where('status', isEqualTo: WellStatus.approved.toString())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد آبار معتمدة'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final w = _parseWellDoc(docs[index]);
            final hasEditRequest =
                w.pendingEdits != null && w.pendingEdits!.isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: hasEditRequest ? Colors.orange.shade50 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: hasEditRequest ? Colors.orange : Colors.transparent),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.water_drop, color: Colors.blue, size: 32),
                title: Text(w.wellName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.right),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        'المساحة: ${w.irrigatedAreaFeddan} فدان  |  العمق: ${w.depthMeters}م',
                        textAlign: TextAlign.right),
                    if (hasEditRequest) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('يوجد طلب تعديل بيانات جديد',
                            style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ],
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasEditRequest ? Colors.orange : NabaTheme.primary),
                  onPressed: () => hasEditRequest
                      ? _showEditRequestReviewDialog(w)
                      : _showWellReviewDialog(w),
                  child: Text(hasEditRequest ? 'مراجعة الطلب' : 'تعديل البئر',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        );
      },
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات آبار معلقة'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final w = _parseWellDoc(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.water_drop, color: Colors.blue, size: 32),
                title: Text(w.wellName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.right),
                subtitle: Text(
                    'المساحة: ${w.irrigatedAreaFeddan} فدان  |  العمق: ${w.depthMeters}م',
                    textAlign: TextAlign.right),
                trailing: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: NabaTheme.primary),
                  onPressed: () => _showWellReviewDialog(w),
                  child: const Text('مراجعة وموافقة',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingJoinsList() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('well_members')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات انضمام معلقة'));
          }
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildJoinRequestCard(doc.id, data);
              });
        });
  }

  Widget _buildJoinRequestCard(String docId, Map<String, dynamic> data) {
    return FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection('users')
              .doc(data['userId'])
              .get(),
          FirebaseFirestore.instance
              .collection('wells')
              .doc(data['wellId'])
              .get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Card(
                child: ListTile(
                    title:
                        Text('جاري التحميل...', textAlign: TextAlign.right)));
          }
          final userDoc = snapshot.data![0];
          final wellDoc = snapshot.data![1];
          final userName = userDoc.data()?['fullName'] ?? 'مستخدم مجهول';
          final wellName = wellDoc.data()?['wellName'] ?? 'بئر مجهول';

          return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('طلب انضمام من: $userName',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right),
                            Text('للبئر: $wellName',
                                style: const TextStyle(color: Colors.blue),
                                textAlign: TextAlign.right),
                            Text(
                                'المساحة المروية: ${data['landAreaFeddan']} فدان',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.right),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('well_members')
                              .doc(docId)
                              .update({'status': 'approved'});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم الموافقة بنجاح')));
                          }
                        },
                        child: const Text('موافقة',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('well_members')
                              .doc(docId)
                              .update({'status': 'rejected'});
                        },
                        child: const Text('رفض'),
                      ),
                    ],
                  )));
        });
  }

  void _showWellReviewDialog(Well w) {
    final nameController = TextEditingController(text: w.wellName);
    final areaController =
        TextEditingController(text: w.irrigatedAreaFeddan.toString());
    final depthController =
        TextEditingController(text: w.depthMeters.toString());
    final flowController =
        TextEditingController(text: w.flowRateM3PerHour?.toString() ?? '');
    final partsController =
        TextEditingController(text: w.participantCount.toString());
    final freqController =
        TextEditingController(text: w.irrigationFrequencyDays.toString());
    final hoursController =
        TextEditingController(text: w.hoursPerPerson.toString());

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
                w.status == WellStatus.approved
                    ? 'تعديل بيانات البئر'
                    : 'مراجعة بيانات البئر',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameController,
                      textAlign: TextAlign.right,
                      decoration:
                          const InputDecoration(labelText: 'اسم البئر')),
                  TextField(
                      controller: areaController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'المساحة المروية (فدان)')),
                  TextField(
                      controller: depthController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'العمق (متر)')),
                  TextField(
                      controller: flowController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'معدل التدفق (متر مكعب/ساعة)')),
                  TextField(
                      controller: partsController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'عدد المشتركين (المبدئي)')),
                  TextField(
                      controller: freqController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'دورة الري (بالأيام)')),
                  TextField(
                      controller: hoursController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'ساعات الري (للفرد)')),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('wells')
                      .doc(w.id)
                      .update({
                    'wellName': nameController.text,
                    'irrigatedAreaFeddan':
                        double.tryParse(areaController.text) ??
                            w.irrigatedAreaFeddan,
                    'depthMeters':
                        double.tryParse(depthController.text) ?? w.depthMeters,
                    'flowRateM3PerHour': double.tryParse(flowController.text) ??
                        w.flowRateM3PerHour,
                    'participantCount': int.tryParse(partsController.text) ??
                        w.participantCount,
                    'irrigationFrequencyDays':
                        int.tryParse(freqController.text) ??
                            w.irrigationFrequencyDays,
                    'hoursPerPerson': double.tryParse(hoursController.text) ??
                        w.hoursPerPerson,
                    'status': WellStatus.approved.toString(),
                    'editRequest': FieldValue.delete(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(w.status == WellStatus.approved
                            ? 'تم حفظ التعديلات بنجاح!'
                            : 'تم اعتماد وتفعيل البئر بنجاح!')));
                  }
                },
                child: Text(
                    w.status == WellStatus.approved
                        ? 'حفظ التعديلات'
                        : 'حفظ وموافقة',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  void _showEditRequestReviewDialog(Well w) {
    if (w.pendingEdits == null) return;

    final List<Widget> changes = [];
    w.pendingEdits!.forEach((key, value) {
      String label = _translateWellKey(key);
      String oldValue = _getWellValueString(w, key);
      changes.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16)),
              const Icon(Icons.arrow_back, size: 20, color: Colors.grey),
              Text(oldValue,
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.red,
                      fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
        ),
      );
    });

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('مراجعة طلب التعديل',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: changes,
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () async {
                  await context.read<WellProvider>().rejectWellEdit(w.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('رفض الطلب',
                    style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  await context
                      .read<WellProvider>()
                      .approveWellEdit(w.id, w.pendingEdits!);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم تطبيق التعديلات بنجاح!')));
                  }
                },
                child: const Text('موافقة وتطبيق',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  String _translateWellKey(String key) {
    switch (key) {
      case 'wellName':
        return 'اسم البئر';
      case 'irrigatedAreaFeddan':
        return 'المساحة المروية (فدان)';
      case 'depthMeters':
        return 'العمق (متر)';
      case 'flowRateM3PerHour':
        return 'معدل التدفق';
      case 'participantCount':
        return 'عدد المشتركين';
      case 'irrigationFrequencyDays':
        return 'دورة الري (أيام)';
      case 'hoursPerPerson':
        return 'ساعات الري (للفرد)';
      default:
        return key;
    }
  }

  String _getWellValueString(Well w, String key) {
    switch (key) {
      case 'wellName':
        return w.wellName;
      case 'irrigatedAreaFeddan':
        return w.irrigatedAreaFeddan.toString();
      case 'depthMeters':
        return w.depthMeters.toString();
      case 'flowRateM3PerHour':
        return w.flowRateM3PerHour?.toString() ?? 'غير محدد';
      case 'participantCount':
        return w.participantCount.toString();
      case 'irrigationFrequencyDays':
        return w.irrigationFrequencyDays.toString();
      case 'hoursPerPerson':
        return w.hoursPerPerson.toString();
      default:
        return 'قيمة سابقة';
    }
  }

  String _translateKey(String key) {
    final translations = {
      'shopName': 'اسم المحل',
      'commercialReg': 'السجل التجاري',
      'category': 'التصنيف',
      'landArea': 'مساحة الأرض',
      'crops': 'المحاصيل',
      'irrigationType': 'نوع الري',
      'equipmentName': 'اسم المعدة',
      'model': 'الموديل',
      'equipmentType': 'نوع المعدة',
      'hourlyRate': 'سعر الساعة',
    };
    return translations[key] ?? key;
  }

  String _getAccountStatusName(AccountStatus s) {
    switch (s) {
      case AccountStatus.pending:
        return 'بانتظار الموافقة';
      case AccountStatus.approved:
        return 'مقبول';
      case AccountStatus.rejected:
        return 'مرفوض';
    }
  }

  Widget _buildUserCard(User u) {
    return InkWell(
      onTap: () => _showUserDetail(u),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                CircleAvatar(
                    radius: 18,
                    child: Text(u.fullName[0],
                        style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(u.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${_getRoleName(u.role)} • ${u.phone}',
                          style: const TextStyle(
                              fontSize: 11, color: NabaTheme.textSecondary)),
                    ],
                  ),
                ),
                if (u.status == AccountStatus.approved)
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                if (u.status == AccountStatus.pending)
                  const Icon(Icons.timer_outlined,
                      color: Colors.orange, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (u.status == AccountStatus.pending)
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: _buildActionButton(
                        'موافقة',
                        Colors.green,
                        () => context.read<AuthProvider>().updateUserStatus(
                            u.id,
                            {'status': AccountStatus.approved.toString()}),
                      ),
                    ),
                  ),
                if (u.status == AccountStatus.approved)
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: _buildActionButton(
                        'تعديل',
                        Colors.blue,
                        () => _showEditUser(u),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: _buildActionButton(
                      'حذف',
                      Colors.red,
                      () => _confirmDeleteUser(u),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsTab() {
    final jobs = context.watch<JobProvider>().jobs;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final j = jobs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.assignment_outlined, color: NabaTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(j.serviceType,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${j.price ?? 0} ج.م • ${_getJobStatusName(j.status)}',
                        style: const TextStyle(
                            fontSize: 10, color: NabaTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: Colors.redAccent),
                onPressed: () => _confirmDeleteJob(j),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataExplorerTab() {
    return GridView.count(
      padding: const EdgeInsets.all(24),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildDataCategoryCard('إدارة الآبار', Icons.water_drop, Colors.cyan,
            onTap: () => _showAllWells()),
        _buildDataCategoryCard(
            'إدارة المنتجات', Icons.shopping_cart, Colors.orange,
            onTap: () => _showAllProducts()),
        _buildDataCategoryCard('التقارير', Icons.analytics, Colors.indigo),
        _buildDataCategoryCard(
            'الإشعارات', Icons.notifications_active, Colors.red),
      ],
    );
  }

  Widget _buildDataCategoryCard(String title, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _showEditUser(User u) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات المستخدم', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                  labelText: 'الاسم الكامل', alignLabelWithHint: true),
              controller: TextEditingController(text: u.fullName),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              context
                  .read<AuthProvider>()
                  .updateUserStatus(u.id, {'extraData.isVerified': true});
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(User u) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: Text('هل أنت متأكد من حذف ${u.fullName}؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AuthProvider>().deleteUser(u.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteJob(Job j) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: Text('هل أنت متأكد من حذف طلب ${j.serviceType}؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<JobProvider>().deleteJob(j.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAllWells() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
            const Text(
              'الآبار',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('wells').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد آبار مسجلة'));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;
                      final wellName = data['wellName'] ?? '';
                      final area = data['irrigatedAreaFeddan'] ?? 0;
                      final depth = data['depthMeters'] ?? 0;
                      final statusStr = data['status']?.toString() ?? '';
                      final isApproved = statusStr.contains('approved');
                      final isPending = statusStr.contains('pending');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(Icons.water_drop, color: Colors.cyan),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(wellName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '$area فدان • $depth متر',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (isPending)
                              ElevatedButton(
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('wells')
                                      .doc(docId)
                                      .update({'status': WellStatus.approved.toString()});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('موافقة'),
                              )
                            else
                              Text(
                                  isApproved ? 'مقبول' : 'مرفوض',
                                  style: TextStyle(
                                      color: isApproved
                                          ? Colors.blue
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllProducts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
            const Text(
              'المنتجات',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('catalog')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('حدث خطأ'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = snapshot.data!.docs;
                  if (products.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات مسجلة'));
                  }

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index].data() as Map<String, dynamic>;
                      final docId = products[index].id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(Icons.shopping_cart,
                                color: Colors.orange),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(p['name'] ?? 'بدون اسم',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('${p['price']} ج.م • ${p['category']}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('catalog')
                                    .doc(docId)
                                    .delete();
                              },
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return 'مزارع';
      case UserRole.worker:
        return 'عامل';
      case UserRole.investor:
        return 'مستثمر';
      case UserRole.seller:
        return 'تاجر';
      case UserRole.equipmentOwner:
        return 'صاحب معدات';
      case UserRole.admin:
        return 'مسؤول';
    }
  }

  String _getJobStatusName(JobStatus status) {
    switch (status) {
      case JobStatus.requested:
        return 'مطلوب';
      case JobStatus.accepted:
        return 'مقبول';
      case JobStatus.inProgress:
        return 'جاري التنفيذ';
      case JobStatus.completed:
        return 'مكتمل';
      case JobStatus.paid:
        return 'تم الدفع';
      case JobStatus.reviewed:
        return 'تم التقييم';
      case JobStatus.disputed:
        return 'متنازع عليه';
    }
  }

  Widget _buildLandPlotsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('land_plots')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final pendingPlots = docs.where((d) => (d.data() as Map)['status'] == 'pending').toList();
        final approvedPlots = docs.where((d) => (d.data() as Map)['status'] == 'approved').toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (pendingPlots.isNotEmpty) ...[
              _buildSectionHeader('طلبات أراضي بانتظار الموافقة (${pendingPlots.length})'),
              const SizedBox(height: 12),
              ...pendingPlots.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.landscape_rounded, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(data['name'] ?? 'قطعة أرض',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('المالك: ${data['ownerName'] ?? 'غير معروف'} • ${data['area'] ?? 0} فدان',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text('البئر: ${data['wellName'] ?? 'غير محدد'}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('land_plots').doc(doc.id).update({'status': 'approved'});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('موافقة'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('land_plots').doc(doc.id).update({'status': 'rejected'});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
            _buildSectionHeader('الأراضي المعتمدة (${approvedPlots.length})'),
            const SizedBox(height: 12),
            if (approvedPlots.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لا توجد أراضي معتمدة', style: TextStyle(color: Colors.grey))))
            else
              ...approvedPlots.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${data['name']} • ${data['area']} فدان • ${data['ownerName'] ?? ''}', style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
