import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class VisitRequestScreen extends StatefulWidget {
  final String engineerId;
  final Map<String, dynamic> engineerData;

  const VisitRequestScreen({
    super.key,
    required this.engineerId,
    required this.engineerData,
  });

  @override
  State<VisitRequestScreen> createState() => _VisitRequestScreenState();
}

class _VisitRequestScreenState extends State<VisitRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();

  DateTime? _date1;
  DateTime? _date2;
  DateTime? _date3;

  bool _isLoading = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _areaCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(int dateIndex) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d != null) {
      if (mounted) {
        final t = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 9, minute: 0),
        );
        if (t != null) {
          final completeDate =
              DateTime(d.year, d.month, d.day, t.hour, t.minute);
          setState(() {
            if (dateIndex == 1) _date1 = completeDate;
            if (dateIndex == 2) _date2 = completeDate;
            if (dateIndex == 3) _date3 = completeDate;
          });
        }
      }
    }
  }

  Future<void> _submitVisitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date1 == null || _date2 == null || _date3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الرجاء اختيار 3 مواعيد مقترحة مختلفة')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final farmer = Provider.of<AuthProvider>(context, listen: false).user!;
      final docRef =
          FirebaseFirestore.instance.collection('consultations').doc();

      await docRef.set({
        'id': docRef.id,
        'type': 'visit',
        'farmerUserId': farmer.id,
        'farmerName': farmer.fullName,
        'engineerUserId': widget.engineerId,
        'engineerName': widget.engineerData['fullName'] ?? 'مهندس',
        'serviceType': widget.engineerData['extraData']?['specialization'] ??
            'زيارة ميدانية',
        'problemDescription': _problemCtrl.text.trim(),
        'visitLocation': _locationCtrl.text.trim(),
        'visitArea': _areaCtrl.text.trim(),
        'proposedDates': [
          Timestamp.fromDate(_date1!),
          Timestamp.fromDate(_date2!),
          Timestamp.fromDate(_date3!)
        ],
        'status': ConsultationStatus.pendingEngineerApproval.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال طلب الزيارة بنجاح'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to Market
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          const NabaAppBar(title: 'طلب زيارة ميدانية', showBackButton: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.map_rounded, color: Colors.orange, size: 30),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'أدخل بيانات المزرعة واقترح 3 مواعيد ليختار منها المهندس الأنسب له.',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'موقع المزرعة',
                    hintText: 'مثال: طريق القاهرة الإسكندرية الصحراوي، ك 60',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'مطلوب إدخال موقع المزرعة' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _areaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مساحة المزرعة',
                    hintText: 'مثال: 50 فدان',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.crop_free_rounded),
                  ),
                  validator: (v) => v!.isEmpty ? 'مطلوب إدخال المساحة' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _problemCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'التشخيص المبدئي أو سبب الزيارة',
                    hintText: 'اكتب باختصار سبب طلبك للمهندس...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'مطلوب توضيح سبب الزيارة' : null,
                ),
                const SizedBox(height: 32),
                const Text('المواعيد المقترحة (اختر 3)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _buildDateSelector(1, _date1),
                const SizedBox(height: 12),
                _buildDateSelector(2, _date2),
                const SizedBox(height: 12),
                _buildDateSelector(3, _date3),
                const SizedBox(height: 40),
                NabaButton(
                  text: _isLoading ? 'جاري الإرسال...' : 'إرسال طلب الزيارة',
                  onPressed: _isLoading ? null : _submitVisitRequest,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(int index, DateTime? date) {
    return InkWell(
      onTap: () => _pickDateTime(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
              color: date == null ? Colors.grey.shade300 : NabaTheme.primary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: date == null ? Colors.grey : NabaTheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                date == null
                    ? 'اختر الموعد المقترح الأول ($index)'
                    : DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                style: TextStyle(
                  color: date == null ? Colors.grey.shade600 : Colors.black,
                  fontWeight:
                      date != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (date != null)
              const Icon(Icons.check_circle_rounded, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
