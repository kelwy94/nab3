import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../models/types.dart';

class RequestWorkerScreen extends StatefulWidget {
  const RequestWorkerScreen({super.key});

  @override
  State<RequestWorkerScreen> createState() => _RequestWorkerScreenState();
}

class _RequestWorkerScreenState extends State<RequestWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedService = 'عامل ري';
  String _price = '';
  String _notes = '';
  String _address = '';
  String _priceUnit = 'باليوم';
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  final List<String> _services = [
    'عامل ري',
    'عامل تقطيع وتقليم وحش',
    'عامل تنظيف حشائش',
    'عامل خدمات نخيل',
    'عامل بناء حظائر',
    'عامل حرث وعزق',
    'عامل جني محصول',
  ];

  final List<String> _priceUnits = ['بالساعة', 'باليوم', 'يومية'];

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'ص' : 'م';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'طلب عامل زراعي'),
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
                          'ما هو نوع الخدمة التي تحتاجها؟',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 500 ? 4 : 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            final isSelected = _selectedService == service;
                            return _buildServiceCard(service, isSelected);
                          },
                        ),

                        const SizedBox(height: 28),

                        // Price + Unit Row
                        _buildFieldLabel('السعر المقترح'),
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            // Price Unit Selector
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: NabaTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: NabaTheme.primary.withOpacity(0.2)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _priceUnit,
                                  items: _priceUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NabaTheme.primary)))).toList(),
                                  onChanged: (v) => setState(() => _priceUnit = v!),
                                  icon: const Icon(Icons.arrow_drop_down, color: NabaTheme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Price Field
                            Expanded(
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  hintText: 'أدخل المبلغ (ج.م)',
                                  suffixText: 'ج.م',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                ),
                                onSaved: (v) => _price = v!,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Work Time
                        _buildFieldLabel('وقت العمل'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              // Start Time
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(true),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: NabaTheme.primary.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('من', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.access_time, color: NabaTheme.primary, size: 18),
                                            const SizedBox(width: 6),
                                            Text(_formatTime(_startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: NabaTheme.primary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.arrow_forward, color: Colors.grey.shade400, size: 20),
                              ),
                              // End Time
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(false),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('إلى', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.access_time, color: Colors.orange.shade700, size: 18),
                                            const SizedBox(width: 6),
                                            Text(_formatTime(_endTime), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade700)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        _buildFieldLabel('عنوان العمل وتفاصيل الموقع'),
                        TextFormField(
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'اكتب عنوان المزرعة أو أقرب علامة مميزة...',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v!.isEmpty ? 'مطلوب إدخال العنوان' : null,
                          onSaved: (v) => _address = v!,
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('ملاحظات إضافية'),
                        TextFormField(
                          maxLines: 3,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'مثلاً: نوع المحصول، درجة الصعوبة...',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          onSaved: (v) => _notes = v!,
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
                  text: 'نشر الطلب الآن',
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final jobProvider = Provider.of<JobProvider>(context, listen: false);

                      // Build start/end DateTime from TimeOfDay
                      final now = DateTime.now();
                      final startDt = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
                      final endDt = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);

                      final newJob = Job(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        requesterUserId: auth.user!.id,
                        type: 'worker',
                        serviceType: _selectedService,
                        location: const {'lat': 0.0, 'lng': 0.0},
                        startTime: startDt,
                        endTime: endDt,
                        status: JobStatus.requested,
                        price: double.tryParse(_price),
                        notes: '$_notes\n[وحدة السعر: $_priceUnit]',
                        address: _address,
                      );

                      await jobProvider.addJob(newJob);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم إرسال طلبك بنجاح وهو الآن يظهر في السوق!'),
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

  Widget _buildServiceCard(String title, bool isSelected) {
    return NabaCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _selectedService = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? NabaTheme.primary : Colors.white,
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : NabaTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getServiceIcon(title),
                color: isSelected ? Colors.white : NabaTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : NabaTheme.textPrimary,
                fontSize: 10,
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
        style: const TextStyle(fontWeight: FontWeight.bold, color: NabaTheme.textPrimary, fontSize: 14),
        textAlign: TextAlign.right,
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'عامل ري':
        return Icons.water_drop_rounded;
      case 'عامل تقطيع وتقليم وحش':
        return Icons.content_cut_rounded;
      case 'عامل تنظيف حشائش':
        return Icons.grass_rounded;
      case 'عامل خدمات نخيل':
        return Icons.park_rounded;
      case 'عامل بناء حظائر':
        return Icons.house_rounded;
      case 'عامل حرث وعزق':
        return Icons.agriculture_rounded;
      case 'عامل جني محصول':
        return Icons.eco_rounded;
      default:
        return Icons.work_rounded;
    }
  }
}
