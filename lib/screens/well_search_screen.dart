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

  Widget _buildWellCard(BuildContext context, String wellId, Map<String, dynamic> data) {
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
              child: const Icon(Icons.water_drop_rounded, color: NabaTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(data['wellName'] ?? 'بئر مجهول',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                _showJoinDialog(context, wellId, data['wellName'] ?? 'بدون اسم');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('طلب انضمام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, String wellId, String wellName) {
    double area = 0.0;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('الانضمام إلى "$wellName"', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('ما هي مساحة أرضك المروية من هذا البئر (بالفدان)؟', textAlign: TextAlign.right),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'مثال: 5.5',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) => area = double.tryParse(val) ?? 0.0,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (area <= 0) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('well_members').add({
                    'wellId': wellId,
                    'userId': user.uid,
                    'status': 'pending',
                    'landAreaFeddan': area,
                    'crops': [],
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال طلب الانضمام بنجاح! سيظهر البئر في لوحتك قريباً.', textAlign: TextAlign.right),
                        backgroundColor: NabaTheme.primary,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إرسال', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
