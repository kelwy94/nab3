import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class JobBidsScreen extends StatelessWidget {
  final Job job;

  const JobBidsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'عروض أسعار العمال'),
      body: StreamBuilder<List<JobBid>>(
        stream: Provider.of<JobProvider>(context, listen: false)
            .getJobBidsStream(job.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bids = snapshot.data ?? [];

          if (bids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('لا توجد عروض أسعار حتى الآن',
                      style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('بانتظار تقديم العمال לעروضهم التنافسية',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: bids.length,
            itemBuilder: (context, index) {
              final bid = bids[index];
              return _buildBidCard(context, bid);
            },
          );
        },
      ),
    );
  }

  Widget _buildBidCard(BuildContext context, JobBid bid) {
    final authId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    final isMyTurn = bid.lastProposedByUserId != authId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NabaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${bid.currentPrice.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: NabaTheme.primary),
                ),
                Text(
                  bid.workerName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isMyTurn
                  ? 'عرض السعر الحالي مقدم من الطرف الآخر'
                  : 'لقد قدمت أنت هذا السعر بانتظار الرد',
              style: TextStyle(
                color: isMyTurn ? Colors.orange.shade700 : Colors.grey,
                fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            if (isMyTurn && bid.status != BidStatus.accepted)
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: NabaButton(
                      text: 'قبول العرض',
                      icon: Icons.check_circle_outline,
                      onPressed: () => _acceptBid(context, bid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NabaButton(
                      text: 'تفاوض',
                      icon: Icons.message_outlined,
                      isPrimary: false,
                      onPressed: () =>
                          _showNegotiateDialog(context, bid, authId!),
                    ),
                  ),
                ],
              ),
            if (bid.status == BidStatus.accepted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('تم الاتفاق والموافقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  void _acceptBid(BuildContext context, JobBid bid) async {
    try {
      await Provider.of<JobProvider>(context, listen: false)
          .acceptBid(job.id, bid.id, bid.workerUserId, bid.currentPrice);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول العرض! العامل الآن مكلف بالمهمة.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء قبول العرض')),
      );
    }
  }

  void _showNegotiateDialog(BuildContext context, JobBid bid, String userId) {
    final priceController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: NabaTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تقديم سعر مضاد',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('السعر الحالي المعروض: ${bid.currentPrice} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'السعر الجديد',
                      suffixText: 'ج.م',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final price =
                                  double.tryParse(priceController.text);
                              if (price == null || price <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('برجاء إدخال سعر صحيح')));
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                await context
                                    .read<JobProvider>()
                                    .updateBidPrice(
                                        job.id, bid.id, price, userId);
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إرسال العرض المضاد'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (bottomSheetContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('حدث خطأ أثناء الإرسال')),
                                  );
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NabaTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('إرسال عرض التفاوض',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
