import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/payment_proof_dialog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;
  bool _leaveAtDoor = false;

  /// Fetch seller info from Firestore
  Future<Map<String, dynamic>?> _fetchSellerInfo(String sellerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint('Error fetching seller: $e');
    }
    return null;
  }

  /// Extract payment method label and details from seller data
  _SellerPaymentInfo _extractPaymentInfo(Map<String, dynamic>? sellerData) {
    if (sellerData == null) return _SellerPaymentInfo('غير محدد', '', sellerData?['fullName'] ?? 'البائع');

    final sellerName = sellerData['fullName'] ?? 'البائع';
    final sellerPaymentMethod = sellerData['paymentMethod'];
    final extraData = sellerData['extraData'] as Map<String, dynamic>?;

    // Determine method label
    String methodLabel = 'غير محدد';
    final methodStr = sellerPaymentMethod?.toString() ?? extraData?['paymentMethod']?.toString() ?? '';
    if (methodStr.contains('vodafoneCash')) methodLabel = 'فودافون كاش';
    else if (methodStr.contains('instaPay')) methodLabel = 'إنستاباي';
    else if (methodStr.contains('bankAccount')) methodLabel = 'حساب بنكي';

    // Determine payment details
    String details = sellerData['paymentDetails']?.toString() ?? '';
    if (details.isEmpty && extraData != null) {
      details = extraData['paymentDetails']?.toString() ?? '';
    }
    if (details.isEmpty) {
      details = sellerData['phone']?.toString() ?? '';
    }

    return _SellerPaymentInfo(methodLabel, details, sellerName);
  }

  void _startCheckout() async {
    final appState = context.read<AppStateProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    final cart = appState.cart;

    if (cart.isEmpty || user == null) return;

    setState(() => _isProcessing = true);

    // Group items by seller
    final itemsBySeller = <String, List<dynamic>>{};
    for (var item in cart) {
      itemsBySeller.putIfAbsent(item.sellerUserId, () => []).add(item);
    }

    final sellerIds = itemsBySeller.keys.toList();
    final totalSellers = sellerIds.length;
    const deliveryFeePerSeller = 20.0;
    bool allSuccess = true;

    // Process each seller one by one
    for (int i = 0; i < sellerIds.length; i++) {
      final sellerId = sellerIds[i];
      final sellerItems = itemsBySeller[sellerId]!;
      double sellerSubtotal = sellerItems.fold(0.0, (sum, item) => sum + (item.price * appState.getQuantity(item.id)));
      double sellerTotal = sellerSubtotal + deliveryFeePerSeller;

      // Fetch this seller's info
      final sellerData = await _fetchSellerInfo(sellerId);
      if (!mounted) return;

      final payInfo = _extractPaymentInfo(sellerData);

      if (payInfo.methodLabel == 'غير محدد' || payInfo.details.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('البائع "${payInfo.name}" لم يسجل بيانات الدفع. تواصل معه مباشرة.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        allSuccess = false;
        continue;
      }

      // Show payment proof dialog for THIS seller
      final sellerLabel = totalSellers > 1
          ? '${payInfo.name} (${i + 1} من $totalSellers)'
          : payInfo.name;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentProofDialog(
          recipientName: sellerLabel,
          paymentMethodLabel: payInfo.methodLabel,
          paymentDetails: payInfo.details,
          amount: sellerTotal,
          onSubmit: (senderNumber, screenshotBase64) async {
            // Create order for this seller
            await FirebaseFirestore.instance.collection('orders').add({
              'buyerUserId': user.id,
              'sellerUserId': sellerId,
              'status': 'OrderStatus.placed',
              'total': sellerTotal,
              'subtotal': sellerSubtotal,
              'deliveryFee': deliveryFeePerSeller,
              'deliveryMethod': 'delivery',
              'deliveryAddress': appState.selectedAddress ?? user.address,
              'leaveAtDoor': _leaveAtDoor,
              'paymentMethod': payInfo.methodLabel,
              'paymentProof': {
                'senderNumber': senderNumber,
                'screenshotBase64': screenshotBase64,
                'submittedAt': FieldValue.serverTimestamp(),
              },
              'createdAt': FieldValue.serverTimestamp(),
              'items': sellerItems
                  .map((item) => {
                        'itemId': item.id,
                        'name': item.name,
                        'price': item.price,
                        'quantity': appState.getQuantity(item.id),
                      })
                  .toList(),
            });

            // Add transaction to seller's wallet
            await FirebaseFirestore.instance.collection('transactions').add({
              'userId': sellerId,
              'type': 'incoming',
              'amount': sellerTotal,
              'note': 'طلب من ${user.fullName} (${payInfo.methodLabel})',
              'paymentMethod': payInfo.methodLabel,
              'buyerName': user.fullName,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Update seller wallet balance
            final walletRef = FirebaseFirestore.instance.collection('wallets').doc(sellerId);
            final walletDoc = await walletRef.get();
            if (walletDoc.exists) {
              final currentBalance = ((walletDoc.data() ?? {})['balance'] ?? 0.0).toDouble();
              await walletRef.update({'balance': currentBalance + sellerTotal});
            } else {
              await walletRef.set({'balance': sellerTotal, 'userId': sellerId});
            }
          },
        ),
      );

      if (result == true) {
        // Remove this seller's items from cart immediately
        for (var item in sellerItems) {
          final qty = appState.getQuantity(item.id);
          for (int q = 0; q < qty; q++) {
            appState.removeFromCart(item);
          }
        }
      } else {
        allSuccess = false;
        break; // User cancelled
      }
    }

    if (allSuccess && mounted) {
      appState.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(totalSellers > 1
                ? 'تم إرسال $totalSellers طلبات وإثباتات التحويل بنجاح!'
                : 'تم إرسال الطلب وإثبات التحويل بنجاح!'),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final cart = appState.cart;
    final subtotal = cart.fold(0.0, (sum, item) => sum + (item.price * appState.getQuantity(item.id)));
    // Delivery fee: 20 EGP per unique seller
    final uniqueSellers = cart.map((e) => e.sellerUserId).toSet().length;
    final deliveryFee = uniqueSellers * 20.0;
    final total = subtotal + deliveryFee;
    final itemCount = cart.fold(0, (sum, item) => sum + appState.getQuantity(item.id));
    final selectedAddress = appState.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: NabaTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Address Section
          _buildSectionCard(
            icon: Icons.location_on,
            iconColor: NabaTheme.primary,
            title: 'عنوان التوصيل',
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: NabaTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.location_on, color: NabaTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('توصيل إلى', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(selectedAddress ?? 'لم يتم تحديد العنوان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: Colors.grey),
              ],
            ),
            onTap: () => _showAddressSheet(context),
          ),

          // Delivery Instructions
          _buildSectionCard(
            icon: Icons.local_shipping,
            iconColor: Colors.blue.shade700,
            title: 'تعليمات التوصيل',
            child: InkWell(
              onTap: () => setState(() => _leaveAtDoor = !_leaveAtDoor),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.door_front_door, color: Colors.blue.shade700, size: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('اترك عند الباب', style: TextStyle(fontSize: 14), textAlign: TextAlign.right)),
                  Checkbox(value: _leaveAtDoor, onChanged: (v) => setState(() => _leaveAtDoor = v ?? false), activeColor: NabaTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ),

          // Shipment Items
          _buildSectionCard(
            icon: Icons.inventory_2,
            iconColor: Colors.orange.shade700,
            title: 'الشحنة ($itemCount منتج)',
            child: Column(
              children: cart.map((item) {
                final qty = appState.getQuantity(item.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.shopping_bag_outlined, color: NabaTheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text('${item.price} ج.م × $qty', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Payment Info Note
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'عند الضغط على "تأكيد الطلب" ستظهر بيانات الدفع الخاصة بالبائع لتحويل المبلغ وإرسال إثبات التحويل',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.5),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Payment Summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(textDirection: TextDirection.rtl, children: [
                  Icon(Icons.receipt_long, color: NabaTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('ملخص الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                _summaryRow('المجموع الفرعي', '${subtotal.toStringAsFixed(2)} ج.م'),
                const SizedBox(height: 8),
                _summaryRow('رسوم التوصيل', '${deliveryFee.toStringAsFixed(2)} ج.م', valueColor: Colors.orange),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي شامل الضريبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: NabaTheme.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),

      // Bottom Confirm Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$itemCount منتج', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text('${total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: NabaTheme.primary)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _startCheckout,
                    style: ElevatedButton.styleFrom(backgroundColor: NabaTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
                    child: _isProcessing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('تأكيد الطلب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required Color iconColor, required String title, required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(textDirection: TextDirection.rtl, children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: valueColor ?? Colors.black87)),
      ],
    );
  }

  void _showAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CheckoutAddressSheet(),
    );
  }
}

// ───────── Address Bottom Sheet for Checkout ─────────
class _CheckoutAddressSheet extends StatefulWidget {
  const _CheckoutAddressSheet();

  @override
  State<_CheckoutAddressSheet> createState() => _CheckoutAddressSheetState();
}

class _CheckoutAddressSheetState extends State<_CheckoutAddressSheet> {
  bool _isAddingNew = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final addresses = appState.savedAddresses;
    final selected = appState.selectedAddress;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('اختر العنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              if (!_isAddingNew)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: NabaTheme.primary),
                  title: const Text('إضافة عنوان جديد', textAlign: TextAlign.right, style: TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_left, color: NabaTheme.primary),
                  onTap: () => setState(() => _isAddingNew = true),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    TextField(controller: _controller, textAlign: TextAlign.right, autofocus: true,
                      decoration: InputDecoration(hintText: 'أدخل العنوان الجديد بالتفصيل...', prefixIcon: const Icon(Icons.edit_location_alt, color: NabaTheme.primary),
                        filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), maxLines: 2),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextButton(onPressed: () => setState(() { _isAddingNew = false; _controller.clear(); }), child: const Text('إلغاء', style: TextStyle(color: Colors.grey)))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: ElevatedButton.icon(
                        onPressed: () {
                          final addr = _controller.text.trim();
                          if (addr.isNotEmpty) { context.read<AppStateProvider>().addAddress(addr); _controller.clear(); setState(() => _isAddingNew = false); }
                        },
                        icon: const Icon(Icons.check, size: 18), label: const Text('حفظ'),
                        style: ElevatedButton.styleFrom(backgroundColor: NabaTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                    ]),
                  ]),
                ),
              const Divider(indent: 16, endIndent: 16),
              ...addresses.map((addr) {
                final isSel = addr == selected;
                return ListTile(
                  leading: Icon(isSel ? Icons.check_circle : Icons.circle_outlined, color: isSel ? NabaTheme.primary : Colors.grey),
                  title: Text(addr, textAlign: TextAlign.right, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                  onTap: () { context.read<AppStateProvider>().selectAddress(addr); Navigator.pop(context); },
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── Helper class ─────────
class _SellerPaymentInfo {
  final String methodLabel;
  final String details;
  final String name;
  _SellerPaymentInfo(this.methodLabel, this.details, this.name);
}
