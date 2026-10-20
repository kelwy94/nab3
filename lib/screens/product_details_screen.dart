import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/product_categories.dart';
import '../models/types.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../utils/guest_utils.dart';
import '../widgets/naba_widgets.dart';
import '../widgets/smart_image.dart';

/// Product page. Supplies are bought through the cart; machinery and used
/// items are arranged directly with the seller (call / WhatsApp), since
/// they are usually inspected and negotiated first.
class ProductDetailsScreen extends StatefulWidget {
  final CatalogItem product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  late final Future<Map<String, dynamic>?> _seller = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.product.sellerUserId)
      .get()
      .then((d) => d.data());

  CatalogItem get p => widget.product;
  ProductCategory get _category => categoryByName(p.category);
  bool get _contactSeller =>
      _category.isMachinery || isUsedCondition(p.condition);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool _requireAccount() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || auth.user == null) {
      GuestUtils.showGuestLoginPrompt(context);
      return false;
    }
    return true;
  }

  Future<void> _call(String phone) async {
    if (!_requireAccount()) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _whatsapp(String phone) async {
    if (!_requireAccount()) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = digits.startsWith('0') ? '2$digits' : digits;
    final text = Uri.encodeComponent(
        'السلام عليكم، أنا مهتم بـ "${p.name}" المعروض على تطبيق نبع بسعر ${_price(p.price)}.');
    await launchUrl(Uri.parse('https://wa.me/$intl?text=$text'),
        mode: LaunchMode.externalApplication);
  }

  void _addToCart() {
    if (!_requireAccount()) return;
    context.read<AppStateProvider>().addToCart(p);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تمت إضافة المنتج للسلة'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
    ));
  }

  static String _price(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} ج.م';

  @override
  Widget build(BuildContext context) {
    final photos = p.allPhotos;
    final used = isUsedCondition(p.condition);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabaTheme.background,
        bottomNavigationBar: _bottomBar(),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              automaticallyImplyLeading: false,
              leading: const NabaBackButton(background: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: photos.isEmpty ? 1 : photos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => Container(
                        color: Colors.white,
                        child: SmartImage(photos.isEmpty ? null : photos[i],
                            placeholderIcon: _category.icon),
                      ),
                    ),
                    if (photos.length > 1)
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            photos.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? NabaTheme.primary
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _badge(_category.icon, _category.name,
                            NabaTheme.primary),
                        if (_category.showCondition)
                          _badge(
                              used
                                  ? Icons.autorenew_rounded
                                  : Icons.new_releases_rounded,
                              p.condition,
                              used ? Colors.orange.shade800 : Colors.blue),
                        if (!p.stockStatus)
                          _badge(Icons.block_rounded, 'غير متاح حالياً',
                              Colors.red),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: NabaTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_price(p.price),
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: NabaTheme.primary)),
                        if (!_category.isMachinery && p.unit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, right: 4),
                            child: Text('/ ${p.unit}',
                                style: const TextStyle(
                                    color: NabaTheme.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        if (p.discountPercentage > 0)
                          _badge(Icons.local_offer_rounded,
                              'خصم ${p.discountPercentage.toStringAsFixed(0)}%',
                              Colors.red),
                        if (p.negotiable)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('قابل للتفاوض',
                                style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    if (p.address.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            size: 16, color: NabaTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(p.address,
                                style: const TextStyle(
                                    color: NabaTheme.textSecondary))),
                      ]),
                    ],
                    if (p.specs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _card('المواصفات الفنية', _specsGrid()),
                    ],
                    if (!_category.isMachinery) ...[
                      const SizedBox(height: 16),
                      _card('معلومات الطلب', _orderInfo()),
                    ],
                    const SizedBox(height: 16),
                    _card(
                      'الوصف',
                      Text(
                        (p.description ?? '').isNotEmpty
                            ? p.description!
                            : 'لا يوجد وصف إضافي.',
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sellerCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specsGrid() {
    final entries = kMachinerySpecs.entries
        .where((e) => (p.specs[e.key] ?? '').isNotEmpty)
        .toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in entries)
          Container(
            width: 150,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NabaTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.value,
                    style: const TextStyle(
                        fontSize: 11, color: NabaTheme.textSecondary)),
                Text(
                  e.key == 'hours'
                      ? '${p.specs[e.key]} ساعة'
                      : (e.key == 'power'
                          ? '${p.specs[e.key]} حصان'
                          : p.specs[e.key]!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _orderInfo() => Column(
        children: [
          _infoRow(Icons.inventory_rounded, 'المتاح',
              p.quantity > 0 ? '${p.quantity.toStringAsFixed(0)} ${p.unit}' : '-'),
          _infoRow(Icons.shopping_basket_rounded, 'أقل طلب',
              '${p.minOrderQuantity.toStringAsFixed(0)} ${p.unit}'),
          _infoRow(Icons.local_shipping_rounded, 'التوصيل',
              p.deliveryAvailable ? 'متاح' : 'استلام من البائع'),
        ],
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: NabaTheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: NabaTheme.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _sellerCard() => FutureBuilder<Map<String, dynamic>?>(
        future: _seller,
        builder: (context, snap) {
          final name = snap.data?['fullName'] as String? ?? 'البائع';
          final rating =
              (snap.data?['extraData']?['rating'] as num?)?.toDouble();
          return _card(
            'البائع',
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: NabaTheme.primary.withOpacity(0.1),
                  child: Text(name.characters.first,
                      style: const TextStyle(
                          color: NabaTheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                if (rating != null) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          );
        },
      );

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4)),
      ]),
      child: SafeArea(
        top: false,
        child: _contactSeller
            ? FutureBuilder<Map<String, dynamic>?>(
                future: _seller,
                builder: (context, snap) {
                  final phone = snap.data?['phone'] as String?;
                  return Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: NabaTheme.primary,
                            foregroundColor: Colors.white),
                        onPressed: phone == null ? null : () => _call(phone),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('اتصل بالبائع',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white),
                        onPressed:
                            phone == null ? null : () => _whatsapp(phone),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('واتساب',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]);
                },
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    foregroundColor: Colors.white),
                onPressed: p.stockStatus ? _addToCart : null,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(p.stockStatus ? 'أضف للسلة' : 'غير متاح حالياً',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}
