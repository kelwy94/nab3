import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'job_details_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import '../widgets/service_requests_panel.dart';
import '../widgets/sell_crop_card.dart';

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
        children: const [
          _MyEquipmentTab(),
          _RentalRequestsTab(),
          ServiceRequestsPanel(),
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
                _buildNavItem(2, Icons.apps_rounded, 'الخدمات'),
                _buildNavItem(
                    3, Icons.account_balance_wallet_rounded, 'الماليات'),
                _buildNavItem(4, Icons.person_rounded, 'حسابي'),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddEquipmentDialog(),
    );
  }
}

class AddEquipmentDialog extends StatefulWidget {
  const AddEquipmentDialog({super.key});

  @override
  State<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<AddEquipmentDialog> {
  final _modelCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _customTypeCtrl = TextEditingController();
  String _selectedType = 'جرار';
  bool _isUploading = false;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final Set<String> _selectedAttachments = {};
  String _pricingUnit = 'ساعة';

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked);
          if (_selectedImages.length > 4) {
            _selectedImages = _selectedImages.sublist(0, 4);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
        child: _isUploading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: NabaTheme.primary),
                  SizedBox(height: 16),
                  Text('جاري حفظ البيانات...',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NabaTheme.primary)),
                ],
              )
            : SingleChildScrollView(
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
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    const Text('صور المعدة (بحد أقصى 4 صور)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...List.generate(_selectedImages.length, (index) {
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade300)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImages[index].path,
                                          fit: BoxFit.cover)
                                      : Image.file(
                                          File(_selectedImages[index].path),
                                          fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.red),
                                  onPressed: () => _removeImage(index),
                                ),
                              )
                            ],
                          );
                        }),
                        if (_selectedImages.length < 4)
                          InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: NabaTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NabaTheme.primary),
                              ),
                              child: const Icon(Icons.add_a_photo,
                                  color: NabaTheme.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('نوع المعدة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: [
                        'جرار',
                        'لودر كبير',
                        'لودر صغير',
                        'سيارة ربع نقل',
                        'سيارة جامبو',
                        'حفار',
                        'بلدوزر',
                        'كلارك',
                        'خباطة آبار',
                        'بريمة آبار',
                        'أخرى'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedType = v ?? 'جرار';
                          _selectedAttachments.clear();
                        });
                      },
                    ),
                    if (_selectedType == 'جرار') ...[
                      const SizedBox(height: 16),
                      const Text('المرفقات المتوفرة',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'جرار فقط',
                          'مكبس',
                          'دراسة',
                          'قصابية',
                          'ليذر',
                          'محراث',
                          'فجاج',
                          'بتانة',
                          'لمامة',
                          'حشاشة',
                          'سطارة'
                        ].map((att) {
                          final isSelected = _selectedAttachments.contains(att);
                          return ChoiceChip(
                            label: Text(att),
                            selected: isSelected,
                            selectedColor: NabaTheme.primary.withOpacity(0.2),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAttachments.add(att);
                                } else {
                                  _selectedAttachments.remove(att);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (_selectedType == 'أخرى') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customTypeCtrl,
                        decoration:
                            const InputDecoration(hintText: 'اكتب نوع المعدة'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text('الموديل / سنة الصنع',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(hintText: '2023'),
                    ),
                    const SizedBox(height: 20),
                    const Text('سعر الإيجار للمعدة (ج.م)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '150'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _pricingUnit,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: ['ساعة', 'فدان']
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text('/ $e')))
                                .toList(),
                            onChanged: (v) => setState(() => _pricingUnit = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    NabaButton(
                      text: 'حفظ المعدة',
                      icon: Icons.save_rounded,
                      onPressed: () async {
                        if (_rateCtrl.text.isEmpty || _modelCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('يرجى ملء جميع الحقول المطلوبة')),
                          );
                          return;
                        }

                        setState(() => _isUploading = true);

                        final finalType = _selectedType == 'أخرى'
                            ? _customTypeCtrl.text.isNotEmpty
                                ? _customTypeCtrl.text
                                : 'أخرى'
                            : _selectedType;
                        final user =
                            Provider.of<AuthProvider>(context, listen: false)
                                .user;

                        try {
                          final docRef = await FirebaseFirestore.instance
                              .collection('equipment')
                              .add({
                            'ownerId': user?.id,
                            'ownerName': user?.fullName,
                            'ownerPhone': user?.phone,
                            'name': finalType,
                            'type': finalType,
                            'model': _modelCtrl.text,
                            'hourlyRate': double.tryParse(_rateCtrl.text) ?? 0,
                            'priceUnit': _pricingUnit,
                            if (finalType == 'جرار')
                              'attachments': _selectedAttachments.toList(),
                            'status': 'available',
                            'createdAt': FieldValue.serverTimestamp(),
                            'images': [],
                          });

                          List<String> imageUrls = [];
                          for (int i = 0; i < _selectedImages.length; i++) {
                            final image = _selectedImages[i];
                            final bytes = await image.readAsBytes();
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('equipment_images/${docRef.id}/img_$i');

                            final uploadTask = await storageRef.putData(bytes,
                                SettableMetadata(contentType: 'image/jpeg'));
                            final url = await uploadTask.ref.getDownloadURL();
                            imageUrls.add(url);
                          }

                          if (imageUrls.isNotEmpty) {
                            await docRef.update({'images': imageUrls});
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم إضافة المعدة بنجاح!')),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error uploading equipment: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'فشل الرفع، يرجى المحاولة مرة أخرى!')),
                            );
                            setState(() => _isUploading = false);
                          }
                        }
                      },
                    ),
                  ],
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
      appBar: const NabaAppBar(
          title: 'سوق الطلبات والمناقصات', showBackButton: false),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          // Equipment jobs only
          final equipmentJobs =
              jobProvider.jobs.where((j) => (j.type == 'equipment')).toList();

          final requestedJobs = equipmentJobs
              .where((j) =>
                  j.status == JobStatus.requested &&
                  j.requesterUserId != user?.id)
              .toList();

          final ongoingTasks = equipmentJobs
              .where((j) =>
                  j.assignedUserId == user?.id &&
                  (j.status == JobStatus.accepted ||
                      j.status == JobStatus.inProgress))
              .toList();

          final finishedPendingPayment = equipmentJobs
              .where((j) =>
                  j.assignedUserId == user?.id &&
                  j.status == JobStatus.completed)
              .toList();

          final workHistory = equipmentJobs
              .where((j) =>
                  j.assignedUserId == user?.id &&
                  (j.status == JobStatus.paid ||
                      j.status == JobStatus.reviewed))
              .toList();

          return RefreshIndicator(
            onRefresh: () async => jobProvider.fetchJobs(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SellCropCard(),
                  const SizedBox(height: 12),
                  // Ongoing Tasks
                  if (ongoingTasks.isNotEmpty) ...[
                    _buildSectionTitle('طلبات يتم تنفيذها الآن',
                        Icons.play_circle_fill, Colors.blue.shade700),
                    const SizedBox(height: 12),
                    ...ongoingTasks.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(
                              context,
                              job,
                              job.status == JobStatus.inProgress
                                  ? 'جاري التنفيذ'
                                  : 'تم القبول - توجه للموقع',
                              Colors.blue),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Pending Payment
                  if (finishedPendingPayment.isNotEmpty) ...[
                    _buildSectionTitle('طلبات بانتظار الدفع',
                        Icons.hourglass_top_rounded, Colors.orange.shade700),
                    const SizedBox(height: 12),
                    ...finishedPendingPayment.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(context, job,
                              'انتهى العمل - بانتظار الدفع', Colors.orange),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Available Jobs
                  _buildSectionTitle('طلبات معدات متاحة في السوق',
                      Icons.handshake_outlined, NabaTheme.primary),
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
                          Icon(Icons.inbox_rounded,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                              'لا توجد طلبات معدات حالياً. سيصلك تنبيه فور توفرها.',
                              style: TextStyle(color: Colors.grey.shade500),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ...requestedJobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildJobCard(context, job,
                              'متاح لتقديم عرض سعر', NabaTheme.primary),
                        )),

                  const SizedBox(height: 28),

                  // History
                  if (workHistory.isNotEmpty) ...[
                    _buildSectionTitle(
                        'سجل التأجير', Icons.history_rounded, Colors.purple),
                    const SizedBox(height: 12),
                    ...workHistory.reversed.take(5).map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child:
                              _buildJobCard(context, job, 'منتهي', Colors.grey),
                        )),
                  ]
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
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildJobCard(
      BuildContext context, Job job, String badgeText, Color badgeColor) {
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job))),
      child: NabaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badgeText,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                Text(job.serviceType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(job.address?.isNotEmpty == true ? job.address! : 'لم يحدد',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey.shade500),
              ],
            ),
          ],
        ),
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
