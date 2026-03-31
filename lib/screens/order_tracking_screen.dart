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

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isConfirming = false;

  int _getStatusStep(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed: return 0;
      case OrderStatus.confirmed: return 1;
      case OrderStatus.outForDelivery: return 2;
      case OrderStatus.completed: return 3;
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
          const SnackBar(content: Text('مبروك! تم استلام الطلب بنجاح.')),
        );
        Navigator.pop(context); // Go back to history
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
    // We can wrap this in a StreamBuilder to get real-time updates of the order status
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(title: 'تتبع الطلب #${widget.order.id.substring(widget.order.id.length - 4)}'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.order.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('الطلب غير موجود'));

          final currentStatus = OrderStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
            orElse: () => OrderStatus.placed,
          );
          final step = _getStatusStep(currentStatus);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NabaCard(
                  child: Column(
                    children: [
                      _buildTimelineStep('تم تأكيد الطلب', 'استلمنا طلبك وجاري مراجعته', Icons.receipt_long, step >= 0, isLast: false),
                      _buildTimelineStep('جاري التجهيز', 'التاجر يقوم بتجهيز منتجاتك الآن', Icons.inventory_2_outlined, step >= 1, isLast: false),
                      _buildTimelineStep('في الطريق إليك', 'المندوب في طريقه لتسليمك الطلب', Icons.local_shipping_outlined, step >= 2, isLast: false),
                      _buildTimelineStep('تم التسليم', 'شكراً لتسوقك من نبع الجُدد', Icons.check_circle_outline, step >= 3, isLast: true),
                    ],
                  ),
                ),
                const Spacer(),
                if (currentStatus == OrderStatus.outForDelivery)
                  NabaButton(
                    text: _isConfirming ? 'جاري التأكيد...' : 'تأكيد استلام الطلب',
                    onPressed: _isConfirming ? null : _confirmReceipt,
                    icon: Icons.check_circle,
                  ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, IconData icon, bool isActive, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? NabaTheme.primary : Colors.grey.shade200,
                ),
                child: Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? NabaTheme.primary : Colors.grey.shade200,
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
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? NabaTheme.textPrimary : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
