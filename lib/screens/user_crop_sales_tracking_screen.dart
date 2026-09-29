import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class UserCropSalesTrackingScreen extends StatelessWidget {
  const UserCropSalesTrackingScreen({super.key});

  final List<String> _stages = const [
    'قيد المراجعة',
    'تم التأكيد',
    'في الطريق للتجميع',
    'تم التجميع',
    'تم البيع/الدفع'
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'تتبع طلبات المحاصيل'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('crop_sale_orders')
              .where('submitterId', isEqualTo: user.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _buildEmptyState();
            }
            
            final sortedDocs = docs.toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime); // descending
            });

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                final data = sortedDocs[index].data() as Map<String, dynamic>;
                return _buildOrderCard(data, sortedDocs[index].id);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'لا توجد أوامر بيع حالياً',
            style: TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'يمكنك عرض محصولك للبيع من الرئيسية.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String docId) {
    // Current Status Handling
    final currentStatus = data['status'] as String? ?? 'قيد المراجعة';

    // Fallback: If status is 'جديد', map it to 'قيد المراجعة' for legacy orders
    final normalizedStatus =
        currentStatus == 'جديد' ? 'قيد المراجعة' : currentStatus;

    int currentStageIndex = _stages.indexOf(normalizedStatus);
    if (currentStageIndex == -1) currentStageIndex = 0; // Default

    final String dateStr = data['createdAt'] != null
        ? intl.DateFormat('yyyy/MM/dd', 'ar')
            .format((data['createdAt'] as Timestamp).toDate())
        : 'اليوم';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Crop type and Date)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NabaTheme.primary.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined,
                        color: NabaTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${data['cropType'] ?? 'محصول'} - ${data['grade'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: NabaTheme.primary,
                          fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Rows
                Row(
                  children: [
                    _buildInfoChip(
                        Icons.scale_rounded, 'الكمية: ${data['quantity']}'),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                        Icons.tag, 'طلب: ${docId.substring(0, 5)}...'),
                  ],
                ),

                // Agreed Price Alert (if exists)
                if (data['agreedPrice'] != null &&
                    data['agreedPrice'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'السعر المتفق عليه: ${data['agreedPrice']} جنيه',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Text(
                  'حالة الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Vertical Timeline
                _buildTimeline(currentStageIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(int currentIndex) {
    return Column(
      children: List.generate(_stages.length, (index) {
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        final isLast = index == _stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Side: Dot and Line
            Column(
              children: [
                // The Dot
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? (isCurrent ? Colors.orange : Colors.green)
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: Colors.orange.shade200, width: 4)
                        : null,
                  ),
                  child: isCompleted && !isCurrent
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                // The Line (if not last)
                if (!isLast)
                  Container(
                    width: 2,
                    height: 30, // Distance between dots
                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Right Side: Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  _stages[index],
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
