import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize addresses from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<AppStateProvider>().initAddressesFromUser(user?.address);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final cart = appState.cart;
    final total = cart.fold(0.0, (sum, item) => sum + (item.price * appState.getQuantity(item.id)));
    final itemCount = cart.fold(0, (sum, item) => sum + appState.getQuantity(item.id));
    final selectedAddress = appState.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: NabaTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'إفراغ السلة',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('إفراغ السلة', textAlign: TextAlign.right),
                    content: const Text('هل تريد حذف جميع المنتجات من السلة؟', textAlign: TextAlign.right),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                      TextButton(
                        onPressed: () {
                          context.read<AppStateProvider>().clearCart();
                          Navigator.pop(context);
                        },
                        child: const Text('حذف الكل', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: NabaTheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_cart_outlined, size: 64, color: NabaTheme.primary.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 20),
                  const Text('السلة فارغة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('ابدأ بإضافة منتجات من السوق', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ],
              ),
            )
          : Column(
              children: [
                // Address Header
                _AddressHeader(selectedAddress: selectedAddress),

                // Cart Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final qty = appState.getQuantity(item.id);
                      return _CartItemCard(item: item, quantity: qty);
                    },
                  ),
                ),

                // Bottom Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('الإجمالي', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            Text(
                              '${total.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: NabaTheme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NabaTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_cart_checkout, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Checkout ($itemCount)', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ───────── Address Header ─────────
class _AddressHeader extends StatelessWidget {
  final String? selectedAddress;
  const _AddressHeader({this.selectedAddress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddressSheet(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: NabaTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.location_on, color: NabaTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('التوصيل إلى', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    selectedAddress ?? 'اختر عنوان التوصيل',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddressBottomSheet(),
    );
  }
}

// ───────── Address Bottom Sheet ─────────
class _AddressBottomSheet extends StatefulWidget {
  const _AddressBottomSheet();

  @override
  State<_AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<_AddressBottomSheet> {
  bool _isAddingNew = false;
  final _newAddressController = TextEditingController();

  @override
  void dispose() {
    _newAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final addresses = appState.savedAddresses;
    final selected = appState.selectedAddress;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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

              // Add new address button or form
              if (!_isAddingNew) ...[
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: NabaTheme.primary),
                  title: const Text('إضافة عنوان جديد', textAlign: TextAlign.right, style: TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_left, color: NabaTheme.primary),
                  onTap: () => setState(() => _isAddingNew = true),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _newAddressController,
                        textAlign: TextAlign.right,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'أدخل العنوان الجديد بالتفصيل...',
                          prefixIcon: const Icon(Icons.edit_location_alt, color: NabaTheme.primary),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _isAddingNew = false;
                                _newAddressController.clear();
                              }),
                              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final addr = _newAddressController.text.trim();
                                if (addr.isNotEmpty) {
                                  context.read<AppStateProvider>().addAddress(addr);
                                  _newAddressController.clear();
                                  setState(() => _isAddingNew = false);
                                }
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('حفظ العنوان'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NabaTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(indent: 16, endIndent: 16),

              // Saved addresses list
              if (addresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('لا يوجد عناوين محفوظة', style: TextStyle(color: Colors.grey.shade500)),
                )
              else
                ...addresses.map((addr) {
                  final isSelected = addr == selected;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        context.read<AppStateProvider>().selectAddress(addr);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? NabaTheme.primary.withOpacity(0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? NabaTheme.primary.withOpacity(0.3) : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(Icons.home, color: isSelected ? NabaTheme.primary : Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isSelected ? 'العنوان الحالي' : 'عنوان محفوظ',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? NabaTheme.primary : Colors.black87),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.check_circle, color: NabaTheme.primary, size: 16),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(addr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.right),
                                ],
                              ),
                            ),
                            // Delete button
                            if (addresses.length > 1)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                                onPressed: () => context.read<AppStateProvider>().removeAddress(addr),
                              ),
                          ],
                        ),
                      ),
                    ),
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

// ───────── Cart Item Card ─────────
class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final int quantity;
  const _CartItemCard({required this.item, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Product Image
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildImage(item.photoUrl)),
          ),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Text('${item.price} ج.م', style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 6),
                    if (item.unit.isNotEmpty)
                      Text('/ ${item.unit}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                // Quantity Controls
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _qtyBtn(icon: quantity > 1 ? Icons.remove : Icons.delete_outline, color: quantity > 1 ? NabaTheme.primary : Colors.red,
                              onTap: () => context.read<AppStateProvider>().removeFromCart(item)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          _qtyBtn(icon: Icons.add, color: NabaTheme.primary, onTap: () => context.read<AppStateProvider>().addToCart(item)),
                        ],
                      ),
                    ),
                    Text('${(item.price * quantity).toStringAsFixed(2)} ج.م', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: color, size: 20)));
  }

  Widget _buildImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 32));
    }
    try {
      String clean = base64String;
      if (clean.contains(',')) clean = clean.split(',').last;
      return Image.memory(base64Decode(clean.trim()), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)));
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
  }
}
