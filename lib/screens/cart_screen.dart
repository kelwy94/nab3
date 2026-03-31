import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessing = false;

  void _checkout() async {
    final appState = context.read<AppStateProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (appState.cart.isEmpty) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Group items by seller
      final itemsBySeller = <String, List<dynamic>>{};

      for (var item in appState.cart) {
        if (!itemsBySeller.containsKey(item.sellerUserId)) {
          itemsBySeller[item.sellerUserId] = [];
        }
        itemsBySeller[item.sellerUserId]!.add(item);
      }

      // Create an order for each seller
      for (var sellerId in itemsBySeller.keys) {
        final sellerItems = itemsBySeller[sellerId]!;
        double sellerTotal =
            sellerItems.fold(0.0, (sum, item) => sum + item.price);

        await FirebaseFirestore.instance.collection('orders').add({
          'buyerUserId': user.id,
          'sellerUserId': sellerId,
          'status': 'OrderStatus.placed',
          'total': sellerTotal,
          'deliveryFee': 0, // Placeholder
          'deliveryMethod': 'delivery',
          'createdAt': FieldValue.serverTimestamp(),
          'items': sellerItems
              .map((i) => {
                    'itemId': i.id,
                    'name': i.name,
                    'price': i.price,
                    'quantity': 1, // Basic support for now: 1 per tap
                  })
              .toList(),
        });
      }

      appState.clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الطلب بنجاح!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الطلب: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<AppStateProvider>().cart;
    final total = cart.fold(0.0, (sum, item) => sum + item.price);

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: AppBar(
        backgroundColor: NabaTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('سلة المشتريات'),
        centerTitle: true,
      ),
      body: cart.isEmpty
          ? const Center(
              child: Text(
                'السلة فارغة',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(Icons.shopping_bag,
                              color: NabaTheme.primary, size: 32),
                          title: Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right),
                          subtitle: Text('${item.price} ج.م',
                              textAlign: TextAlign.right),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () {
                              context
                                  .read<AppStateProvider>()
                                  .removeFromCart(item);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -5))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${total.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: NabaTheme.primary)),
                          const Text('الإجمالي',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _checkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NabaTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('إتمام الطلب',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
