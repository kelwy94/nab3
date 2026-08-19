import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import 'farmer_dashboard.dart' show ProfileScreen;
import 'settings_screen.dart';
import 'wallet_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class DeliveryWorkerDashboard extends StatefulWidget {
  const DeliveryWorkerDashboard({super.key});

  @override
  State<DeliveryWorkerDashboard> createState() => _DeliveryWorkerDashboardState();
}

class _DeliveryWorkerDashboardState extends State<DeliveryWorkerDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DeliveryHomeTab(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.moped_rounded, 'الرئيسية'),
                _buildNavItem(1, Icons.person_rounded, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? NabaTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  label,
                  style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            Icon(icon, color: isSelected ? NabaTheme.primary : Colors.grey, size: 26),
          ],
        ),
      ),
    );
  }
}

class DeliveryHomeTab extends StatelessWidget {
  const DeliveryHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isAvailable = user?.extraData?['isAvailable'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: NabaTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('لوحة التوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final allOrders = appState.orders;
          
          final availableOrders = allOrders.where((o) =>
            o.deliveryMethod == 'delivery' &&
            o.status == OrderStatus.placed &&
            o.deliveryWorkerId == null
          ).toList();

          final myActiveOrders = allOrders.where((o) =>
            o.deliveryWorkerId == user?.id &&
            (o.status == OrderStatus.deliveryAccepted || o.status == OrderStatus.preparing || o.status == OrderStatus.outForDelivery)
          ).toList();

          final myCompletedOrders = allOrders.where((o) =>
            o.deliveryWorkerId == user?.id &&
            o.status == OrderStatus.completed
          ).toList();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusHeader(context, isAvailable),
                const SizedBox(height: 24),

                if (myActiveOrders.isNotEmpty) ...[
                  _buildSectionTitle('طلبات قيد التوصيل', Icons.motorcycle, Colors.blue.shade700),
                  const SizedBox(height: 12),
                  ...myActiveOrders.map((o) => _buildOrderCard(context, o, true)),
                  const SizedBox(height: 24),
                ],

                _buildSectionTitle('طلبات توصيل متاحة', Icons.inbox, NabaTheme.primary),
                const SizedBox(height: 12),
                if (availableOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('لا توجد طلبات توصيل متاحة حالياً.', style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else
                  ...availableOrders.map((o) => _buildOrderCard(context, o, false)),

                const SizedBox(height: 28),
                _buildSectionTitle('سجل التوصيل', Icons.history, Colors.purple),
                const SizedBox(height: 12),
                _buildMiniStatRow(myCompletedOrders.length.toString(), user),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStatusHeader(BuildContext context, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isAvailable
            ? const LinearGradient(colors: [Color(0xFF1B8A4E), Color(0xFF2ECC71)], begin: Alignment.topRight, end: Alignment.bottomLeft)
            : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isAvailable ? NabaTheme.primary : Colors.grey).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.check_circle_outline : Icons.pause_circle_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isAvailable ? 'أنت متاح للتوصيل الآن' : 'أنت في وضع الراحة',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  isAvailable ? 'سيصلك تنبيه عند وجود طلبات جديدة' : 'قم بتفعيل الوضع لتلقي الطلبات',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (v) {
              Provider.of<AuthProvider>(context, listen: false).toggleAvailability(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, bool isActive) {
    final color = isActive ? Colors.blue : NabaTheme.primary;
    final userId = Provider.of<AuthProvider>(context, listen: false).user!.id;

    return InkWell(
      onTap: () {
        // Show order details dialogue
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('تفاصيل الطلب #${order.id.substring(0, 5)}', textAlign: TextAlign.right),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('استلام من المحل: ${order.sellerUserId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('تسليم للمزارع: ${order.buyerUserId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('طريقة الدفع: ${order.paymentMethod ?? "غير محدد"}'),
                Text('رسوم التوصيل: ${order.deliveryFee} ج.م'),
                const SizedBox(height: 16),
                const Text('تأكد من المسافة قبل قبول الطلب لضمان التوصيل في الوقت المناسب.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.right),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              textDirection: ui.TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('طلب توصيل #${order.id.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${order.deliveryFee} ج.م', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('استلام من: عنوان المحل (اضغط للتفاصيل)', style: TextStyle(color: Colors.grey)),
            const Text('توصيل إلى: عنوان المزارع (اضغط للتفاصيل)', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (!isActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                      'deliveryWorkerId': userId,
                      'status': OrderStatus.deliveryAccepted.toString(),
                    });
                    
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final workerName = auth.user?.fullName ?? 'مندوب توصيل';
                    await FirebaseFirestore.instance.collection('users').doc(order.sellerUserId).collection('notifications').add({
                      'title': 'المندوب في الطريق!',
                      'body': 'لقد وافق $workerName على توصيل الطلب رقم #${order.id.substring(0, 5)} وسيصل لاستلامه قريباً.',
                      'createdAt': FieldValue.serverTimestamp(),
                      'isRead': false,
                    });

                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الطلب بنجاح وإشعار المحل')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  child: const Text('قبول التوصيل'),
                ),
              )
            else if (order.status == OrderStatus.outForDelivery)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                      'status': OrderStatus.completed.toString(),
                    });
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنهاء التوصيل بنجاح')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  child: const Text('تم التوصيل بنجاح'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  order.status == OrderStatus.preparing ? 'بانتظار تجهيز المحل...' : 'تم قبول الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatRow(String completedCount, User? user) {
    final rawRating = user?.extraData?['rating'];
    String displayRating = 'جديد';
    if (rawRating != null && rawRating is num && rawRating > 0) {
      displayRating = rawRating.toStringAsFixed(1);
    }

    return Row(
      children: [
        _stat('توصيلات تمت', completedCount, Colors.blue, Icons.check_circle_rounded),
        const SizedBox(width: 12),
        _stat('تقييمك', displayRating, Colors.orange, Icons.star_rounded),
      ],
    );
  }

  Widget _stat(String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
