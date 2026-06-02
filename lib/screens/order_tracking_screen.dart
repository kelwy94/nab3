import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Order order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  bool _isConfirming = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int _getStatusStep(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.outForDelivery:
        return 2;
      case OrderStatus.completed:
        return 3;
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 'تم استلام الطلب';
      case OrderStatus.confirmed:
        return 'جاري التجهيز';
      case OrderStatus.outForDelivery:
        return 'في الطريق إليك';
      case OrderStatus.completed:
        return 'تم التسليم';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return Colors.blue;
      case OrderStatus.confirmed:
        return Colors.orange;
      case OrderStatus.outForDelivery:
        return Colors.purple;
      case OrderStatus.completed:
        return Colors.green;
    }
  }

  Future<void> _confirmReceipt() async {
    setState(() => _isConfirming = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .update({'status': OrderStatus.completed.toString()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مبروك! تم استلام الطلب بنجاح. شكراً لتسوقك من نبع 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
          title:
              'تتبع الطلب #${widget.order.id.substring(widget.order.id.length - 4)}'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.order.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final currentStatus = OrderStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
            orElse: () => OrderStatus.placed,
          );
          final step = _getStatusStep(currentStatus);
          final statusColor = _getStatusColor(currentStatus);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Summary Card
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor,
                            statusColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(
                                0.3 + _pulseController.value * 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            currentStatus == OrderStatus.completed
                                ? Icons.check_circle_rounded
                                : currentStatus == OrderStatus.outForDelivery
                                    ? Icons.local_shipping_rounded
                                    : currentStatus == OrderStatus.confirmed
                                        ? Icons.inventory_2_rounded
                                        : Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getStatusLabel(currentStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (currentStatus != OrderStatus.completed) ...[
                            const SizedBox(height: 8),
                            Text(
                              'تقدم الطلب: ${((step + 1) / 4 * 100).toInt()}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (step + 1) / 4,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Order Info
                NabaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('تفاصيل الطلب',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      _buildInfoRow('المبلغ الإجمالي',
                          '${widget.order.total} ج.م'),
                      _buildInfoRow('رسوم التوصيل',
                          '${widget.order.deliveryFee} ج.م'),
                      _buildInfoRow(
                          'طريقة التوصيل',
                          widget.order.deliveryMethod == 'delivery'
                              ? 'توصيل للباب'
                              : 'استلام من المتجر'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Timeline
                NabaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('مراحل الطلب',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildTimelineStep(
                        'تم تأكيد الطلب',
                        'استلمنا طلبك وجاري مراجعته',
                        Icons.receipt_long,
                        step >= 0,
                        isActive: step == 0,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        'جاري التجهيز',
                        'التاجر يقوم بتجهيز منتجاتك الآن',
                        Icons.inventory_2_outlined,
                        step >= 1,
                        isActive: step == 1,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        'في الطريق إليك',
                        'المندوب في طريقه لتسليمك الطلب',
                        Icons.local_shipping_outlined,
                        step >= 2,
                        isActive: step == 2,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        'تم التسليم',
                        'شكراً لتسوقك من نبع الجُدد',
                        Icons.check_circle_outline,
                        step >= 3,
                        isActive: step == 3,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                if (currentStatus == OrderStatus.outForDelivery)
                  NabaButton(
                    text: _isConfirming
                        ? 'جاري التأكيد...'
                        : 'تأكيد استلام الطلب ✅',
                    onPressed: _isConfirming ? null : _confirmReceipt,
                    icon: Icons.check_circle,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(
      String title, String subtitle, IconData icon, bool isCompleted,
      {bool isLast = false, bool isActive = false}) {
    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? NabaTheme.primary
                      : Colors.grey.shade200,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: NabaTheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: Icon(icon,
                    color: isCompleted ? Colors.white : Colors.grey, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? NabaTheme.primary
                        : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCompleted
                              ? NabaTheme.textPrimary
                              : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
