import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/well_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class WellCreateScreen extends StatefulWidget {
  const WellCreateScreen({super.key});

  @override
  State<WellCreateScreen> createState() => _WellCreateScreenState();
}

class _WellCreateScreenState extends State<WellCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form State
  String _wellName = '';
  double _depth = 0;
  double _area = 0;
  int _participantCount = 1;
  double _flowRate = 0.0;
  double _hoursPerPerson = 1.0;
  int _irrigationFrequencyDays = 1;
  WaterOutput _output = WaterOutput.medium;
  FairnessRule _rule = FairnessRule.proportional;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'إضافة بئر جديد'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Hero(
                tag: 'well_icon',
                child: Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.water_drop_rounded,
                        size: 40, color: NabaTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'بيانات البئر الفنية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildInputSection(
                label: 'اسم البئر',
                child: TextFormField(
                  decoration:
                      const InputDecoration(hintText: 'مثلاً: بئر الصفا 1'),
                  onSaved: (v) => _wellName = v!,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInputSection(
                      label: 'المساحة (فدان)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0.0'),
                        onSaved: (v) => _area = double.tryParse(v ?? '0') ?? 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputSection(
                      label: 'العمق (متر)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0'),
                        onSaved: (v) => _depth = double.tryParse(v ?? '0') ?? 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInputSection(
                      label: 'عدد المشتركين (المبدئي)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '1'),
                        onSaved: (v) => _participantCount = int.tryParse(v ?? '1') ?? 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputSection(
                      label: 'تدفق المياه (م³/ساعة)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0.0'),
                        onSaved: (v) => _flowRate = double.tryParse(v ?? '0') ?? 0.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInputSection(
                      label: 'دورة الري (بالأيام)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'مثال: 7'),
                        onSaved: (v) => _irrigationFrequencyDays = int.tryParse(v ?? '1') ?? 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputSection(
                      label: 'ساعات الري (للفرد)',
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'مثال: 5'),
                        onSaved: (v) => _hoursPerPerson = double.tryParse(v ?? '1.0') ?? 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('قوة التصريف (الإنتاجية)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildModernSegmentedControl(),
              const SizedBox(height: 32),
              const Text('قاعدة العدل في التوزيع',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildFairnessSelection(),
              const SizedBox(height: 40),
              NabaButton(
                text: 'حفظ وتفعيل البئر',
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    final wellProvider =
                        Provider.of<WellProvider>(context, listen: false);

                    final newWell = Well(
                      id: 'well_${DateTime.now().millisecondsSinceEpoch}',
                      adminUserId: auth.user?.id ?? 'guest',
                      wellName: _wellName,
                      location: {'lat': 0.0, 'lng': 0.0}, // Mock location
                      depthMeters: _depth,
                      irrigatedAreaFeddan: _area,
                      waterOutput: _output,
                      participantCount: _participantCount,
                      flowRateM3PerHour: _flowRate,
                      fairnessRule: _rule,
                      allowedDays: [
                        'السبت',
                        'الأحد',
                        'الاثنين',
                        'الثلاثاء',
                        'الأربعاء',
                        'الخميس',
                        'الجمعة'
                      ],
                      allowedHours: {'start': '08:00', 'end': '20:00'},
                      slotDuration: 180, // 3 hours
                      hoursPerPerson: _hoursPerPerson,
                      irrigationFrequencyDays: _irrigationFrequencyDays,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    await wellProvider.addWell(newWell);

                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('تم حفظ البئر بنجاح!'),
                          backgroundColor: NabaTheme.primary),
                    );
                    navigator.pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: NabaTheme.textPrimary)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildModernSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: WaterOutput.values.map((o) {
          final isSelected = _output == o;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _output = o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? NabaTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getOutputLabel(o),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFairnessSelection() {
    return Column(
      children: FairnessRule.values.map((rule) {
        final isSelected = _rule == rule;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NabaCard(
            padding: const EdgeInsets.all(4),
            onTap: () => setState(() => _rule = rule),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected
                    ? NabaTheme.primary.withOpacity(0.05)
                    : Colors.transparent,
                border: Border.all(
                    color: isSelected ? NabaTheme.primary : Colors.transparent,
                    width: 2),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected ? NabaTheme.primary : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rule == FairnessRule.equal
                              ? 'توزيع متساوي'
                              : 'توزيع نسبي (حسب المساحة)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? NabaTheme.primary
                                : NabaTheme.textPrimary,
                          ),
                        ),
                        Text(
                          rule == FairnessRule.equal
                              ? 'كل مزارع يحصل على نفس عدد الساعات'
                              : 'ساعات الري تعتمد على مساحة أرض كل مزارع',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getOutputLabel(WaterOutput o) {
    switch (o) {
      case WaterOutput.low:
        return 'ضعيف';
      case WaterOutput.medium:
        return 'متوسط';
      case WaterOutput.high:
        return 'قوي';
    }
  }
}
