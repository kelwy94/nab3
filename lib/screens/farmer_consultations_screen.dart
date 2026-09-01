import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class FarmerConsultationsScreen extends StatelessWidget {
  const FarmerConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.user?.id;

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: const NabaAppBar(
          title: 'الاستشارات والزيارات', showBackButton: false),
      backgroundColor: NabaTheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('farmerUserId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<QueryDocumentSnapshot> docs =
              snapshot.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'ليس لديك استشارات أو مواعيد زيارات حالياً',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final consultation = ConsultationRequest(
                id: docs[index].id,
                farmerUserId: data['farmerUserId'],
                farmerName: data['farmerName'],
                engineerUserId: data['engineerUserId'],
                engineerName: data['engineerName'],
                serviceType: data['serviceType'],
                problemDescription: data['problemDescription'],
                status: ConsultationStatus.values.firstWhere(
                  (e) => (data['status']?.toString() ?? '').contains(e.name),
                  orElse: () => ConsultationStatus.pendingEngineerApproval,
                ),
                agreedPrice: (data['agreedPrice'] as num?)?.toDouble(),
                proposedDate: data['proposedDate'] != null
                    ? (data['proposedDate'] as Timestamp).toDate()
                    : null,
                farmerProposedDate: data['farmerProposedDate'] != null
                    ? (data['farmerProposedDate'] as Timestamp).toDate()
                    : null,
                finalAgreedDate: data['finalAgreedDate'] != null
                    ? (data['finalAgreedDate'] as Timestamp).toDate()
                    : null,
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                rating: (data['rating'] as num?)?.toDouble(),
              );

              return _buildConsultationCard(context, consultation);
            },
          );
        },
      ),
    );
  }

  Widget _buildConsultationCard(BuildContext context, ConsultationRequest req) {
    Color statusColor = Colors.grey;
    String statusLabel = 'قيد المراجعة';

    switch (req.status) {
      case ConsultationStatus.pendingEngineerApproval:
        statusLabel = 'بانتظار موافقة المهندس';
        statusColor = Colors.orange;
        break;
      case ConsultationStatus.rejected:
        statusLabel = 'مرفوضة';
        statusColor = Colors.red;
        break;
      case ConsultationStatus.pendingPriceApproval:
      case ConsultationStatus.negotiatingTime:
        statusLabel = 'جاري التفاوض / تحديد الموعد';
        statusColor = Colors.blue;
        break;
      case ConsultationStatus.confirmed:
        statusLabel = 'مؤكدة';
        statusColor = NabaTheme.primary;
        break;
      case ConsultationStatus.completed:
      case ConsultationStatus.rated:
        statusLabel = 'مكتملة';
        statusColor = Colors.green;
        break;
    }

    final hasAgreedDate = req.finalAgreedDate != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    req.serviceType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.engineering_rounded,
                    color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text('المهندس: ${req.engineerName}',
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money_rounded,
                    color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                    'السعر المتفق عليه: ${req.agreedPrice != null ? '${req.agreedPrice} ج.م' : 'لم يحدد بعد'}',
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
            if (hasAgreedDate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'موعد الاستشارة القادم',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${req.finalAgreedDate!.year}-${req.finalAgreedDate!.month.toString().padLeft(2, '0')}-${req.finalAgreedDate!.day.toString().padLeft(2, '0')} ${req.finalAgreedDate!.hour.toString().padLeft(2, '0')}:${req.finalAgreedDate!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (req.status == ConsultationStatus.pendingPriceApproval) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('consultations')
                          .doc(req.id)
                          .update({
                        'status': ConsultationStatus.confirmed.name,
                        'finalAgreedDate': req.proposedDate != null
                            ? Timestamp.fromDate(req.proposedDate!)
                            : null,
                      }),
                      child: const Text('موافق (تأكيد)',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: req.proposedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 60)),
                        );
                        if (d != null) {
                          final t = await showTimePicker(
                              context: context,
                              initialTime:
                                  const TimeOfDay(hour: 10, minute: 0));
                          if (t != null) {
                            final dt = DateTime(
                                d.year, d.month, d.day, t.hour, t.minute);
                            FirebaseFirestore.instance
                                .collection('consultations')
                                .doc(req.id)
                                .update({
                              'status': ConsultationStatus.negotiatingTime.name,
                              'farmerProposedDate': Timestamp.fromDate(dt),
                            });
                          }
                        }
                      },
                      child: const Text('موعد بديل',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
