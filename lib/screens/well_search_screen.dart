import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class WellSearchScreen extends StatelessWidget {
  const WellSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'البحث عن بئر'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('wells').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد آبار مضافة حالياً.'));
          }
          final wells = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wells.length,
            itemBuilder: (context, index) {
              final doc = wells[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildWellCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildWellCard(
      BuildContext context, String wellId, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NabaCard(
        onTap: () {
          _showJoinDialog(context, wellId, data['wellName'] ?? 'بدون اسم');
        },
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NabaTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.water_drop_rounded,
                  color: NabaTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(data['wellName'] ?? 'بئر مجهول',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'التدفق: ${data['flowRateM3PerHour'] ?? 'غير محدد'} م³/ساعة | المساحة: ${data['irrigatedAreaFeddan']} فدان',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _showJoinDialog(
                    context, wellId, data['wellName'] ?? 'بدون اسم');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('طلب انضمام',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, String wellId, String wellName) {
    double area = 0.0;
    DateTime? nextIrrigationDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateBuilder) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('الانضمام إلى "$wellName"',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('ما هي مساحة أرضك المروية من هذا البئر (بالفدان)؟',
                    textAlign: TextAlign.right),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'مثال: 5.5',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => area = double.tryParse(val) ?? 0.0,
                ),
                const SizedBox(height: 24),
                const Text('ميعاد الرية القادمة',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: nextIrrigationDate ?? DateTime.now(),
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
                      setStateBuilder(() {
                        nextIrrigationDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          nextIrrigationDate == null
                              ? 'اختر ميعاد أول رية'
                              : '${nextIrrigationDate!.day}/${nextIrrigationDate!.month}/${nextIrrigationDate!.year}',
                          style: TextStyle(
                            color: nextIrrigationDate == null
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
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (area <= 0 || nextIrrigationDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('الرجاء إدخال المساحة والميعاد بشكل صحيح.'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    // Perform Conflict Check
                    final hasConflict = await _checkConflictAndShowDialog(
                      context,
                      wellId,
                      nextIrrigationDate!,
                      user.uid,
                      ScaffoldMessenger.of(context),
                    );

                    if (hasConflict) return;

                    await FirebaseFirestore.instance
                        .collection('well_members')
                        .add({
                      'wellId': wellId,
                      'userId': user.uid,
                      'status': 'pending',
                      'landAreaFeddan': area,
                      'crops': [],
                      'nextIrrigationDate':
                          Timestamp.fromDate(nextIrrigationDate!),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تم إرسال طلب الانضمام بنجاح! سيظهر البئر في لوحتك قريباً.',
                              textAlign: TextAlign.right),
                          backgroundColor: NabaTheme.primary,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NabaTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    const Text('إرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<bool> _checkConflictAndShowDialog(
    BuildContext context,
    String wellId,
    DateTime pickedDate,
    String currentUserId,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final wellDoc = await db.collection('wells').doc(wellId).get();
      if (!wellDoc.exists) return false;

      final wellData = wellDoc.data()!;
      final cycleDays = wellData['irrigationFrequencyDays'] ?? 1;

      final List<Map<String, dynamic>> memberDates = [];

      if (wellData['nextIrrigationDate'] != null) {
        memberDates.add({
          'userId': wellData['adminUserId'],
          'date': (wellData['nextIrrigationDate'] as Timestamp).toDate(),
        });
      }

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

      final selectedNormalized =
          DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day);

      for (var existing in memberDates) {
        if (existing['userId'] == currentUserId) continue;
        final existingDate = existing['date'] as DateTime;
        final existingNormalized = DateTime.utc(
            existingDate.year, existingDate.month, existingDate.day);

        final daysDiff =
            selectedNormalized.difference(existingNormalized).inDays.abs();

        if (daysDiff % cycleDays == 0) {
          String conflictingName = 'مزارع آخر';
          try {
            final udoc =
                await db.collection('users').doc(existing['userId']).get();
            if (udoc.exists)
              conflictingName = udoc.data()!['fullName'] ?? conflictingName;
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
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Conflict check error: $e');
      return false;
    }
  }
}
