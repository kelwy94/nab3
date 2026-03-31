import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'package:intl/intl.dart' as intl;

class AssetManagementScreen extends StatelessWidget {
  const AssetManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'إدارة الأصول والاستثمارات'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('payerUserId', isEqualTo: user?.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final paymentsDocs = snapshot.data?.docs ?? [];
          
          if (paymentsDocs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد أصول نشطة أو استثمارات سابقة',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            );
          }

          final payments = paymentsDocs.map((d) => d.data() as Map<String, dynamic>).toList();
          payments.sort((a, b) {
            final tA = a['createdAt'] as Timestamp?;
            final tB = b['createdAt'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final data = payments[index];
              final amount = data['amount'] ?? 0.0;
              final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final relatedType = data['relatedType'] ?? 'غير معروف';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: NabaCard(
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            color: Colors.purple),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              relatedType == 'well' ? 'استثمار في بئر مياه' : 'تمويل زراعي عام',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              intl.DateFormat('yyyy/MM/dd').format(date),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${amount.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: NabaTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
}
