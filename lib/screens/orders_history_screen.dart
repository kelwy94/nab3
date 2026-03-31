import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'order_tracking_screen.dart';
import 'package:intl/intl.dart' as intl;

class OrdersHistoryScreen extends StatelessWidget {
  const OrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final allOrders = context.watch<AppStateProvider>().orders;
    final myOrders = allOrders.where((o) => o.buyerUserId == user?.id).toList();

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'مشترياتي'),
      body: myOrders.isEmpty
          ? const Center(
              child: Text('لا توجد طلبات شراء سابقة',
                  style: TextStyle(color: Colors.grey, fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: myOrders.length,
              itemBuilder: (context, index) {
                final o = myOrders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: NabaCard(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: o)));
                    },
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: NabaTheme.primary.withOpacity(0.05),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.shopping_bag_rounded,
                              color: NabaTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('طلب رقم #${o.id.substring(o.id.length - 4)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${o.total} ج.م • ${intl.DateFormat('yyyy/MM/dd').format(o.createdAt)}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        _buildStatusBadge(o.status),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    String text = '';
    Color color = Colors.grey;
    switch (status) {
      case OrderStatus.placed:
        text = 'مراجعة';
        color = Colors.blue;
        break;
      case OrderStatus.confirmed:
        text = 'تجهيز';
        color = Colors.orange;
        break;
      case OrderStatus.outForDelivery:
        text = 'في الطريق';
        color = Colors.purple;
        break;
      case OrderStatus.completed:
        text = 'تم التسليم';
        color = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
