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
  String _selectedService = 'ري ميكانيكي';
  String _price = '';
  String _notes = '';
  String _address = '';

  final List<String> _services = [
    'ري ميكانيكي',
    'تقليم وتطعيم',
    'مكافحة آفات',
    'عزق وحرث',
    'جني محصول',
    'مساعدة فنية'
  ];

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
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            final isSelected = _selectedService == service;
                            return _buildServiceCard(service, isSelected);
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildFieldLabel('السعر المقترح (ج.م)'),
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: 'أدخل المبلغ المناسب للفدان أو اليوم'),
                          onSaved: (v) => _price = v!,
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('عنوان العمل وتفاصيل الموقع'),
                        TextFormField(
                          maxLines: 2,
                          decoration: const InputDecoration(
                              hintText: 'اكتب عنوان المزرعة أو أقرب علامة مميزة...'),
                          validator: (v) => v!.isEmpty ? 'مطلوب إدخال العنوان' : null,
                          onSaved: (v) => _address = v!,
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('ملاحظات إضافية'),
                        TextFormField(
                          maxLines: 3,
                          decoration: const InputDecoration(
                              hintText:
                                  'مثلاً: نوع المحصول، درجة الصعوبة، أو الوقت المفضل'),
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

                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final jobProvider =
                          Provider.of<JobProvider>(context, listen: false);

                      final newJob = Job(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        requesterUserId: auth.user!.id,
                        type: 'worker',
                        serviceType: _selectedService,
                        location: const {'lat': 0.0, 'lng': 0.0}, // Placeholder
                        startTime: DateTime.now(),
                        endTime: DateTime.now().add(const Duration(hours: 4)),
                        status: JobStatus.requested,
                        price: double.tryParse(_price),
                        notes: _notes,
                        address: _address,
                      );

                      await jobProvider.addJob(newJob);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'تم إرسال طلبك بنجاح وهو الآن يظهر في السوق!'),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? NabaTheme.primary : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getServiceIcon(title),
              color: isSelected ? Colors.white : NabaTheme.primary,
              size: 24, // Smaller icon as requested
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : NabaTheme.textPrimary,
                fontSize: 13, // Smaller font
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

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'ري ميكانيكي':
        return Icons.water_drop_rounded;
      case 'تقليم وتطعيم':
        return Icons.content_cut_rounded;
      case 'مكافحة آفات':
        return Icons.bug_report_rounded;
      case 'عزق وحرث':
        return Icons.agriculture_rounded;
      case 'جني محصول':
        return Icons.eco_rounded;
      case 'مساعدة فنية':
        return Icons.psychology_rounded;
      default:
        return Icons.work_rounded;
    }
  }
}
