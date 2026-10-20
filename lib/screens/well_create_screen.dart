import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/well_provider.dart';
import '../data/delivery_data.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

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
  String? _selectedDistrict;
  String? _selectedWellId;
  List<Map<String, dynamic>> _existingWells = [];
  bool _isLoadingWells = false;

  FairnessRule _rule = FairnessRule.proportional;
  LatLng? _selectedLocation;
  DateTime? _nextIrrigationDate;

  Future<void> _fetchWells(String district) async {
    setState(() => _isLoadingWells = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('wells')
          .where('district', isEqualTo: district)
          .where('status', isEqualTo: WellStatus.approved.toString())
          .get();
      setState(() {
        _existingWells = snap.docs
            .map((d) => {
                  'id': d.id,
                  'name': d.data()['wellName'] ?? 'بدون اسم',
                })
            .toList();
        _isLoadingWells = false;
        _selectedWellId = null;
      });
    } catch (e) {
      setState(() => _isLoadingWells = false);
    }
  }

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
                label: 'المركز',
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(hintText: 'اختر المركز'),
                  initialValue: _selectedDistrict,
                  items: kDistricts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedDistrict = v;
                        _selectedWellId = null;
                        _existingWells.clear();
                      });
                      _fetchWells(v);
                    }
                  },
                  validator: (v) => v == null ? 'اختر المركز' : null,
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedDistrict != null) ...[
                if (_isLoadingWells)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputSection(
                        label: 'اختر البئر للتسجيل عليه',
                        child: DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(hintText: 'اختر البئر'),
                          initialValue: _selectedWellId,
                          items: [
                            ..._existingWells.map((w) => DropdownMenuItem(
                                  value: w['id'] as String,
                                  child: Text(w['name'] as String),
                                )),
                            const DropdownMenuItem(
                              value: 'new_well',
                              child: Text('+ إضافة بئر جديد',
                                  style: TextStyle(
                                      color: NabaTheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedWellId = v;
                              _nextIrrigationDate = null;
                            });
                          },
                          validator: (v) => v == null ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
              ],

              if (_selectedWellId == 'new_well') ...[
                _buildLocationPicker(),
                const SizedBox(height: 24),
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
                          onSaved: (v) =>
                              _area = double.tryParse(v ?? '0') ?? 0,
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
                          onSaved: (v) =>
                              _depth = double.tryParse(v ?? '0') ?? 0,
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
                          onSaved: (v) =>
                              _participantCount = int.tryParse(v ?? '1') ?? 1,
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
                          onSaved: (v) =>
                              _flowRate = double.tryParse(v ?? '0') ?? 0.0,
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
                          decoration:
                              const InputDecoration(hintText: 'مثال: 7'),
                          onSaved: (v) => _irrigationFrequencyDays =
                              int.tryParse(v ?? '1') ?? 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputSection(
                        label: 'ساعات الري (للفرد)',
                        child: TextFormField(
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: 'مثال: 5'),
                          onSaved: (v) => _hoursPerPerson =
                              double.tryParse(v ?? '1.0') ?? 1.0,
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
                const SizedBox(height: 24),
              ], // End of new_well fields

              if (_selectedWellId != null) ...[
                const Text('ميعاد الرية القادمة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextIrrigationDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: NabaTheme.primary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _nextIrrigationDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          _nextIrrigationDate == null
                              ? 'اختر ميعاد أول رية (مطلوب)'
                              : '${_nextIrrigationDate!.day}/${_nextIrrigationDate!.month}/${_nextIrrigationDate!.year}',
                          style: TextStyle(
                            color: _nextIrrigationDate == null
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                        const Icon(Icons.calendar_month,
                            color: NabaTheme.primary),
                      ],
                    ),
                  ),
                ),
                if (_nextIrrigationDate == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, right: 12),
                    child: Text('يجب اختيار মيعاد الرية لتنظيم الجدول',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.right),
                  ),
                const SizedBox(height: 40),
              ],

              if (_selectedWellId != null)
                NabaButton(
                  text: _selectedWellId == 'new_well'
                      ? 'حفظ وتفعيل البئر'
                      : 'طلب انضمام للبئر',
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final wellProvider =
                          Provider.of<WellProvider>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      if (_nextIrrigationDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('الرجاء اختيار ميعاد الرية القادمة.'),
                                backgroundColor: Colors.red));
                        return;
                      }

                      // Conflict Check
                      final hasConflict = await _checkConflictAndShowDialog(
                        context,
                        _selectedWellId!,
                        _nextIrrigationDate!,
                        auth.user?.id ?? 'guest',
                        messenger,
                      );
                      if (hasConflict) return;

                      if (_selectedWellId == 'new_well') {
                        final newWell = Well(
                          id: 'well_${DateTime.now().millisecondsSinceEpoch}',
                          adminUserId: auth.user?.id ?? 'guest',
                          wellName: _wellName,
                          district: _selectedDistrict,
                          location: _selectedLocation != null
                              ? {
                                  'lat': _selectedLocation!.latitude,
                                  'lng': _selectedLocation!.longitude
                                }
                              : {'lat': 30.0, 'lng': 31.0},
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
                          slotDuration: 180,
                          hoursPerPerson: _hoursPerPerson,
                          irrigationFrequencyDays: _irrigationFrequencyDays,
                          nextIrrigationDate: _nextIrrigationDate,
                        );

                        await wellProvider.addWell(newWell);

                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('تم حفظ البئر بنجاح!'),
                              backgroundColor: NabaTheme.primary),
                        );
                      } else {
                        // Request Join
                        if (auth.user?.id == null) return;
                        await wellProvider.requestJoinWell(
                            _selectedWellId!, auth.user!.id,
                            nextIrrigationDate: _nextIrrigationDate);
                        messenger.showSnackBar(
                          const SnackBar(
                              content:
                                  Text('تم إرسال طلب الانضمام للبئر للمراجعة.'),
                              backgroundColor: NabaTheme.primary),
                        );
                      }

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
                              : rule == FairnessRule.proportional
                                  ? 'توزيع نسبي (حسب المساحة)'
                                  : 'توزيع يدوي',
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
                              : rule == FairnessRule.proportional
                                  ? 'ساعات الري تعتمد على مساحة أرض كل مزارع'
                                  : 'المدير يحدد الساعات لكل مزارع يدوياً',
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

  Widget _buildLocationPicker() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(
            builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
          ),
        );
        if (result != null) {
          setState(() {
            _selectedLocation = result;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedLocation != null
              ? Colors.green.shade50
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _selectedLocation != null
                  ? Colors.green.shade200
                  : Colors.blue.shade100),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedLocation != null
                    ? Colors.green.shade400
                    : Colors.blue.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedLocation != null
                    ? 'تم تحديد موقع البئر بنجاح'
                    : 'حدد موقع البئر على الخريطة',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: _selectedLocation != null
                        ? Colors.green.shade700
                        : Colors.blue,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.arrow_back_ios_new,
                size: 14,
                color: _selectedLocation != null ? Colors.green : Colors.blue),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkConflictAndShowDialog(
    BuildContext context,
    String wellId,
    DateTime pickedDate,
    String currentUserId,
    ScaffoldMessengerState messenger,
  ) async {
    // If it's a completely new well, no one else is on it yet.
    if (wellId == 'new_well') return false;

    try {
      final db = FirebaseFirestore.instance;
      final wellDoc = await db.collection('wells').doc(wellId).get();
      if (!wellDoc.exists) return false;

      final wellData = wellDoc.data()!;
      final cycleDays = wellData['irrigationFrequencyDays'] ?? 1;
      // With a daily cycle everyone irrigates every day (at different
      // hours), so a same-day match isn't a conflict.
      if (cycleDays <= 1) return false;

      final List<Map<String, dynamic>> memberDates = [];

      // 1. Check Creator's date
      if (wellData['nextIrrigationDate'] != null) {
        memberDates.add({
          'userId': wellData['adminUserId'],
          'date': (wellData['nextIrrigationDate'] as Timestamp).toDate(),
        });
      }

      // 2. Check all members dates
      final membersSnap = await db
          .collection('well_members')
          .where('wellId', isEqualTo: wellId)
          .get();

      for (var doc in membersSnap.docs) {
        final d = doc.data();
        if (d['nextIrrigationDate'] != null) {
          memberDates.add({
            'userId': d['userId'],
            'date': (d['nextIrrigationDate'] as Timestamp).toDate(),
          });
        }
      }

      // 3. Find conflict utilizing Modulo math
      final selectedNormalized =
          DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day);

      for (var existing in memberDates) {
        if (existing['userId'] == currentUserId) {
          continue; // Skip self if re-applying
        }
        final existingDate = existing['date'] as DateTime;
        final existingNormalized = DateTime.utc(
            existingDate.year, existingDate.month, existingDate.day);

        final daysDiff =
            selectedNormalized.difference(existingNormalized).inDays.abs();

        if (daysDiff % cycleDays == 0) {
          // Conflict found!
          // Try fetching the conflicting user's name
          String conflictingName = 'مزارع آخر';
          try {
            final udoc =
                await db.collection('users').doc(existing['userId']).get();
            if (udoc.exists) {
              conflictingName = udoc.data()!['fullName'] ?? conflictingName;
            }
          } catch (_) {}

          if (context.mounted) {
            final bool? shouldComplain = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('تعارض في مواعيد الري',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
                content: Text(
                  'عفواً، الميعاد الذي حددته يتعارض مع ميعاد رية "$conflictingName" على نفس البئر (بنفس دورة الري كل $cycleDays أيام).\n\nالرجاء اختيار ميعاد آخر، أو تفضل بتقديم شكوى لإدارة التطبيق لحل النزاع.',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء واختيار موعد آخر',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('إرسال شكوى للإدارة',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );

            if (shouldComplain == true) {
              await db.collection('complaints').add({
                'type': 'irrigation_conflict',
                'fromUserId': currentUserId,
                'targetUserId': existing['userId'],
                'wellId': wellId,
                'details':
                    'تعارض في اختيار يوم الري مع المزارع $conflictingName. الموعد المطلوب: ${pickedDate.toIso8601String()}',
                'status': 'newComplaint',
                'createdAt': FieldValue.serverTimestamp(),
                'extraData': {
                  'requestedDate': pickedDate.toIso8601String(),
                  'conflictingDate': existingDate.toIso8601String(),
                  'cycleDays': cycleDays,
                },
              });
              messenger.showSnackBar(
                const SnackBar(
                    content: Text(
                        'تم إرسال الشكوى للإدارة بنجاح. سيتم التواصل معك قريباً.'),
                    backgroundColor: Colors.teal),
              );
            }
          }
          return true; // Has conflict
        }
      }
      return false; // No conflict
    } catch (e) {
      debugPrint('Conflict check error: $e');
      return false; // Assuming no conflict to not block if error occurs, or handle differently.
    }
  }
}
