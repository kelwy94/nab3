import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../models/types.dart';
import 'job_details_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

class EquipmentOwnerDashboard extends StatefulWidget {
  const EquipmentOwnerDashboard({super.key});

  @override
  State<EquipmentOwnerDashboard> createState() =>
      _EquipmentOwnerDashboardState();
}

class _EquipmentOwnerDashboardState extends State<EquipmentOwnerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _MyEquipmentTab(),
          _RentalRequestsTab(),
          WalletScreen(),
          _EquipmentProfileTab(),
        ],
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.agriculture_rounded, 'معداتي'),
                _buildNavItem(1, Icons.assignment_rounded, 'الطلبات'),
                _buildNavItem(2, Icons.account_balance_wallet_rounded, 'الماليات'),
                _buildNavItem(3, Icons.person_rounded, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
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
                padding: const EdgeInsets.only(right: 8),
                child: Text(label,
                    style: const TextStyle(
                        color: NabaTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            Icon(icon,
                color: isSelected ? NabaTheme.primary : Colors.grey, size: 26),
          ],
        ),
      ),
    );
  }
}

// -=-=-=-=-=- Tab 1: My Equipment -=-=-=-=-=-
class _MyEquipmentTab extends StatelessWidget {
  const _MyEquipmentTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'معداتي',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            onPressed: () => _showAddEquipmentDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment')
            .where('ownerId', isEqualTo: user?.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.agriculture_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('لم تضف أي معدات بعد',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 24),
                  NabaButton(
                    text: 'إضافة معدة جديدة',
                    onPressed: () => _showAddEquipmentDialog(context),
                    icon: Icons.add_circle_rounded,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length + 1, // +1 for header card
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: NabaCard(
                    onTap: () => _showAddEquipmentDialog(context),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: NabaTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.add_business_rounded,
                              color: NabaTheme.primary, size: 32),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('إضافة معدة جديدة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              Text('سجّل معدتك وابدأ في استقبال طلبات التأجير',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_back_ios,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }

              final doc = docs[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final name = data['name'] ?? 'معدة';
              final type = data['type'] ?? '';
              final status = data['status'] ?? 'available';
              final hourlyRate = data['hourlyRate'] ?? 0;

              Color statusColor = Colors.green;
              String statusText = 'متاح للإيجار';
              if (status == 'maintenance') {
                statusColor = Colors.orange;
                statusText = 'قيد الصيانة';
              } else if (status == 'rented') {
                statusColor = Colors.blue;
                statusText = 'مؤجر حالياً';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NabaCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            Icon(Icons.agriculture_rounded, color: statusColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('$type • $hourlyRate ج.م/ساعة',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(statusText,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        backgroundColor: statusColor,
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: const Text('حذف المعدة'),
                                content: Text('هل تريد حذف "$name"؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('حذف',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('equipment')
                                .doc(docId)
                                .delete();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEquipmentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final customTypeCtrl = TextEditingController();
    String selectedType = 'جرار';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
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
                  const Text('إضافة معدة جديدة',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const Text('اسم المعدة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'مثلاً: جرار نيوهولاند 75 حصان'),
                  ),
                  const SizedBox(height: 20),
                  const Text('نوع المعدة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: [
                      'جرار',
                      'حفار',
                      'لودر',
                      'سيارة نقل جامبو',
                      'ربع نقل',
                      'ماكينة رش',
                      'ماكينة ري',
                      'محراث',
                      'كومباين حصاد',
                      'موتور مياه',
                      'أخرى'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedType = v ?? 'جرار'),
                  ),
                  if (selectedType == 'أخرى') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customTypeCtrl,
                      decoration: const InputDecoration(
                          hintText: 'اكتب نوع المعدة'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('الموديل / سنة الصنع',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(hintText: '2023'),
                  ),
                  const SizedBox(height: 20),
                  const Text('سعر الإيجار بالساعة (ج.م)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '150'),
                  ),
                  const SizedBox(height: 32),
                  NabaButton(
                    text: 'حفظ المعدة',
                    icon: Icons.save_rounded,
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || rateCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('يرجى ملء جميع الحقول المطلوبة')),
                        );
                        return;
                      }
                      final finalType = selectedType == 'أخرى'
                          ? customTypeCtrl.text.isNotEmpty
                              ? customTypeCtrl.text
                              : 'أخرى'
                          : selectedType;
                      final user =
                          Provider.of<AuthProvider>(context, listen: false)
                              .user;
                      await FirebaseFirestore.instance
                          .collection('equipment')
                          .add({
                        'ownerId': user?.id,
                        'ownerName': user?.fullName,
                        'ownerPhone': user?.phone,
                        'name': nameCtrl.text,
                        'type': finalType,
                        'model': modelCtrl.text,
                        'hourlyRate': double.tryParse(rateCtrl.text) ?? 0,
                        'status': 'available',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم إضافة المعدة بنجاح!')),
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

// -=-=-=-=-=- Tab 2: Rental Requests -=-=-=-=-=-
class _RentalRequestsTab extends StatelessWidget {
  const _RentalRequestsTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'طلبات التأجير', showBackButton: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rental_requests')
            .where('equipmentOwnerId', isEqualTo: user?.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات تأجير حالياً',
                      style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final requesterName = data['requesterName'] ?? 'مزارع';
              final equipmentName = data['equipmentName'] ?? 'معدة';
              final duration = data['duration'] ?? '1 يوم';
              final price = data['totalPrice'] ?? 0;
              final status = data['status'] ?? 'pending';

              if (status != 'pending') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: data['jobId'] != null
                        ? () {
                            // Find the job object from provider if possible, or just navigate
                            // For simplicity, we can fetch it or just use a placeholder
                            // But usually, we want to navigate to the job details
                            FirebaseFirestore.instance
                                .collection('jobs')
                                .doc(data['jobId'])
                                .get()
                                .then((doc) {
                              if (doc.exists) {
                                // Create a Job object from data
                                final j = doc.data()!;
                                final job = Job(
                                  id: doc.id,
                                  requesterUserId: j['requesterUserId'] ?? '',
                                  assignedUserId: j['assignedUserId'],
                                  type: j['type'] ?? 'equipment',
                                  serviceType: j['serviceType'] ?? '',
                                  location: const {'lat': 0.0, 'lng': 0.0},
                                  startTime: (j['startTime'] as Timestamp).toDate(),
                                  endTime: (j['endTime'] as Timestamp).toDate(),
                                  status: JobStatus.values.firstWhere(
                                      (e) => e.toString() == j['status'],
                                      orElse: () => JobStatus.requested),
                                  price: (j['price'] as num?)?.toDouble(),
                                  notes: j['notes'] ?? '',
                                  address: j['address'],
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailsScreen(job: job),
                                  ),
                                );
                              }
                            });
                          }
                        : null,
                    child: NabaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(
                                    status == 'accepted' ? 'مقبول - تتبع' : 'مرفوض',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11)),
                                backgroundColor: status == 'accepted'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              Text(equipmentName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Text('الطالب: $requesterName • $duration',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NabaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$price ج.م',
                              style: const TextStyle(
                                  color: NabaTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text(equipmentName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('الطالب: $requesterName • المدة: $duration',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('rental_requests')
                                    .doc(docId)
                                    .update({'status': 'rejected'});
                              },
                              child: const Text('رفض'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final batch = FirebaseFirestore.instance.batch();
                                
                                // 1. Update Rental Request
                                final reqRef = FirebaseFirestore.instance
                                    .collection('rental_requests')
                                    .doc(docId);
                                batch.update(reqRef, {'status': 'accepted'});

                                // 2. Update linked Job if exists
                                if (data['jobId'] != null) {
                                  final jobRef = FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(data['jobId']);
                                  batch.update(jobRef, {
                                    'status': JobStatus.accepted.toString(),
                                    'assignedUserId': user?.id,
                                    'acceptedAt': FieldValue.serverTimestamp(),
                                  });
                                }

                                await batch.commit();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: NabaTheme.primary,
                                  foregroundColor: Colors.white),
                              child: const Text('قبول'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -=-=-=-=-=- Tab 3: Profile -=-=-=-=-=-
class _EquipmentProfileTab extends StatelessWidget {
  const _EquipmentProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user!;
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'حسابي',
        showBackButton: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: NabaTheme.primary.withOpacity(0.1),
              child: const Icon(Icons.person_rounded,
                  size: 50, color: NabaTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(user.fullName,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user.phone,
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
            if (user.paymentMethod != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'وسيلة الدفع: ${user.paymentMethodLabel}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildMenuItem(context, Icons.account_balance_wallet_outlined,
                'المحفظة المالية', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()));
            }),
            _buildMenuItem(context, Icons.settings_rounded, 'الإعدادات', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
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

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
}
