import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../models/types.dart';

class RequestEquipmentScreen extends StatefulWidget {
  const RequestEquipmentScreen({super.key});

  @override
  State<RequestEquipmentScreen> createState() => _RequestEquipmentScreenState();
}

class _RequestEquipmentScreenState extends State<RequestEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedEquip = 'جرار زراعي';
  String _price = '';
  String _duration = '';

  final List<String> _equipment = [
    'جرار زراعي',
    'حفار هيدروليك',
    'لودر',
    'سيارة نقل جامبو',
    'ربع نقل',
    'ماكينة ري',
    'ماكينة رش',
    'محراث ليزر',
    'موتور مياه',
    'أخرى'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'طلب معدة زراعية'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'اختر المعدة المطلوبة',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 500 ? 3 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: _equipment.length,
                          itemBuilder: (context, index) {
                            final item = _equipment[index];
                            final isSelected = _selectedEquip == item;
                            return _buildEquipCard(item, isSelected);
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildFieldLabel('السعر المقترح للإيجار (ج.م)'),
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: 'أدخل المبلغ المناسب للفدان أو اليوم'),
                          onSaved: (v) => _price = v!,
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('مدة العمل المطلوبة (أيام/ساعات)'),
                        TextFormField(
                          decoration: const InputDecoration(
                              hintText: 'مثلاً: يومين، أو 5 ساعات عمل'),
                          onSaved: (v) => _duration = v!,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: NabaButton(
                  text: 'نشر طلب المعدة',
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final jobProvider =
                          Provider.of<JobProvider>(context, listen: false);

                      final newJob = Job(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        requesterUserId: auth.user!.id,
                        type: 'equipment',
                        serviceType: _selectedEquip,
                        location: const {'lat': 0.0, 'lng': 0.0}, // Placeholder
                        startTime: DateTime.now(),
                        endTime: DateTime.now().add(const Duration(days: 1)),
                        status: JobStatus.requested,
                        price: double.tryParse(_price),
                        notes: 'المدة المطلوبة: $_duration',
                      );

                      await jobProvider.addJob(newJob);

                      // Also send to rental_requests to alert owners
                      final equipSnap = await FirebaseFirestore.instance
                          .collection('equipment')
                          .where('status', isEqualTo: 'available')
                          .get();

                      for (final doc in equipSnap.docs) {
                        final eData = doc.data();
                        await FirebaseFirestore.instance
                            .collection('rental_requests')
                            .add({
                          'equipmentId': doc.id,
                          'equipmentName': eData['name'],
                          'equipmentOwnerId': eData['ownerId'],
                          'requesterId': auth.user!.id,
                          'requesterName': auth.user!.fullName,
                          'requestedType': _selectedEquip,
                          'offeredPrice': _price,
                          'duration': _duration,
                          'status': 'pending',
                          'jobId': newJob.id,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'تم إرسال طلب المعدة وهو الآن يظهر في السوق ولأصحاب المعدات!'),
                              backgroundColor: NabaTheme.primary),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipCard(String title, bool isSelected) {
    return NabaCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _selectedEquip = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? NabaTheme.primary : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEquipIcon(title),
              color: isSelected ? Colors.white : NabaTheme.primary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : NabaTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: NabaTheme.textPrimary,
            fontSize: 14),
        textAlign: TextAlign.right,
      ),
    );
  }

  IconData _getEquipIcon(String equip) {
    switch (equip) {
      case 'جرار زراعي':
        return Icons.agriculture_rounded;
      case 'حفار هيدروليك':
        return Icons.construction_rounded;
      case 'لودر':
        return Icons.front_loader;
      case 'سيارة نقل جامبو':
        return Icons.local_shipping_rounded;
      case 'ربع نقل':
        return Icons.fire_truck_rounded;
      case 'ماكينة ري':
        return Icons.water_drop_rounded;
      case 'محراث ليزر':
        return Icons.precision_manufacturing_rounded;
      case 'ماكينة رش':
        return Icons.opacity_rounded;
      case 'موتور مياه':
        return Icons.plumbing_rounded;
      case 'كومباين حصاد':
        return Icons.grass_rounded;
      default:
        return Icons.settings_rounded;
    }
  }
}
