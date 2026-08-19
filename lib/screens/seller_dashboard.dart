import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'order_tracking_screen.dart';
import 'product_form_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  final List<String> _categories = [
    'الكل',
    'بذور وأسمدة',
    'معدات ري',
    'أدوات زراعية',
    'مبيدات',
    'أخرى'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sellerId = context.read<AuthProvider>().user!.id;
      context.read<CatalogProvider>().listenToSellerData(sellerId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('متجري',
            style: TextStyle(
                color: NabaTheme.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.settings_outlined, color: NabaTheme.textPrimary),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        actions: [
          _buildNotificationBell(),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded,
                color: NabaTheme.primary),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: NabaTheme.primary,
          unselectedLabelColor: NabaTheme.textSecondary,
          indicatorColor: NabaTheme.primary,
          tabs: const [
            Tab(text: 'المنتجات'),
            Tab(text: 'الطلبات'),
            Tab(text: 'حسابي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildOrdersTab(),
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        backgroundColor: NabaTheme.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد'),
      ),
    );
  }

  Widget _buildProductsTab() {
    final catalog = context.watch<CatalogProvider>();
    final products = catalog.sellerProducts.where((p) {
      final matchesSearch = p.name.contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'الكل' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: products.isEmpty
              ? _buildEmptyState(
                  'لا توجد منتجات حالياً', Icons.inventory_2_outlined)
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _buildProductCard(products[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell() {
    final sellerId = context.read<AuthProvider>().user?.id;
    if (sellerId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: NabaTheme.primary),
              onPressed: () => _showNotifications(sellerId),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotifications(String sellerId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الإشعارات',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(sellerId)
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('لا توجد إشعارات'));
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isRead = data['isRead'] ?? false;
                        return ListTile(
                          title: Text(data['title'] ?? '', textAlign: TextAlign.right, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(data['body'] ?? '', textAlign: TextAlign.right),
                          leading: Icon(Icons.notifications_active_rounded, color: isRead ? Colors.grey : NabaTheme.primary),
                          onTap: () {
                            if (!isRead) {
                              doc.reference.update({'isRead': true});
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((c) => _buildCategoryChip(c)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedCategory = label),
        backgroundColor: Colors.grey.shade50,
        selectedColor: NabaTheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? NabaTheme.primary : NabaTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        checkmarkColor: NabaTheme.primary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: isSelected ? NabaTheme.primary : Colors.transparent)),
      ),
    );
  }

  Widget _buildProductCard(CatalogItem p) {
    return NabaCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageSafe(p.photoUrl, p.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${p.price} ج.م / ${p.unit}',
                    style: const TextStyle(
                        color: NabaTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 16, color: Colors.grey.shade400),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (p.stockStatus ? Colors.green : Colors.red)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.stockStatus ? 'متوفر' : 'نفذ',
                        style: TextStyle(
                            color: p.stockStatus ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSafe(String? base64String, String heroTag) {
    if (base64String == null || base64String.isEmpty) {
      return Center(
        child: Hero(
          tag: 'prod_$heroTag',
          child: Icon(Icons.inventory_2_rounded,
              size: 48, color: Colors.grey.shade300),
        ),
      );
    }

    try {
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64.trim());
      return Hero(
        tag: 'prod_$heroTag',
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Center(
                child: Icon(Icons.broken_image,
                    color: Colors.grey.shade300, size: 48));
          },
        ),
      );
    } catch (e) {
      return Center(
          child:
              Icon(Icons.broken_image, color: Colors.grey.shade300, size: 48));
    }
  }

  Widget _buildOrdersTab() {
    final orders = context.watch<CatalogProvider>().sellerOrders;

    return Column(
      children: [
        _buildModernShopStats(orders.length),
        Expanded(
          child: orders.isEmpty
              ? _buildEmptyState(
                  'لا توجد طلبات حالياً', Icons.shopping_bag_outlined)
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(orders[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildModernShopStats(int activeCount) {
    final orders = context.watch<CatalogProvider>().sellerOrders;
    // Calculate today's sales
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayOrders = orders.where((o) =>
        o.createdAt.isAfter(todayStart) || o.createdAt.isAtSameMomentAs(todayStart)).toList();
    final todaySalesTotal = todayOrders.fold(0.0, (sum, o) => sum + o.total);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: NabaTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: NabaTheme.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('طلبيات نشطة', activeCount.toString(),
              Icons.local_shipping_rounded),
          _stat('مبيعات اليوم', todaySalesTotal > 0 ? '${todaySalesTotal.toStringAsFixed(0)} ج' : '0', Icons.payments_rounded),
          _stat('التقييم', _getSellerRating(), Icons.star_rounded),
        ],
      ),
    );
  }

  String _getSellerRating() {
    final user = context.read<AuthProvider>().user;
    final rawRating = user?.extraData?['rating'];
    if (rawRating != null && rawRating is num && rawRating > 0) {
      return rawRating.toStringAsFixed(1);
    }
    return 'جديد';
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildOrderCard(Order o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: NabaTheme.primary.withOpacity(0.05),
                    shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded,
                    color: NabaTheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('طلب رقم #${o.id.substring(o.id.length - 4)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(intl.DateFormat('jm', 'ar').format(o.createdAt),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              _buildStatusBadge(o.status),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${o.total} ج.م',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: NabaTheme.primary)),
              const Text('إجمالي الطلب', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: o.status == OrderStatus.placed
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'بانتظار قبول مندوب التوصيل...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : NabaButton(
                        text: o.status == OrderStatus.deliveryAccepted
                            ? 'تجهيز الطلب'
                            : o.status == OrderStatus.preparing
                                ? 'في الطريق إليك'
                                : o.status == OrderStatus.completed && o.deliveryWorkerId != null
                                    ? 'تقييم المندوب'
                                    : 'مكتمل',
                        onPressed: o.status == OrderStatus.deliveryAccepted
                            ? () => context
                                .read<CatalogProvider>()
                                .updateOrderStatus(o.id, OrderStatus.preparing)
                            : o.status == OrderStatus.preparing
                                ? () => context
                                    .read<CatalogProvider>()
                                    .updateOrderStatus(o.id, OrderStatus.outForDelivery)
                                : o.status == OrderStatus.completed && o.deliveryWorkerId != null
                                    ? () async {
                                        int selectedRating = 5;
                                        await showDialog(
                                          context: context,
                                          builder: (context) => StatefulBuilder(
                                            builder: (context, setState) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                title: const Text('تقييم المندوب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text('ما هو تقييمك لسرعة وأداء مندوب التوصيل؟', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                                    const SizedBox(height: 24),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: List.generate(5, (index) {
                                                        return IconButton(
                                                          icon: Icon(
                                                            index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                                            color: Colors.amber,
                                                            size: 40,
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              selectedRating = index + 1;
                                                            });
                                                          },
                                                        );
                                                      }),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: NabaTheme.primary,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      try {
                                                        final workerDoc = FirebaseFirestore.instance.collection('users').doc(o.deliveryWorkerId);
                                                        final snapshot = await workerDoc.get();
                                                        if (snapshot.exists) {
                                                          final Map<String, dynamic> dataMap = snapshot.data() as Map<String, dynamic>? ?? {};
                                                          final Map<String, dynamic> extraData = dataMap['extraData'] is Map ? dataMap['extraData'] as Map<String, dynamic> : {};
                                                          final double currentRating = extraData['rating'] != null ? (extraData['rating'] as num).toDouble() : 5.0;
                                                          final int ratingCount = extraData['ratingCount'] != null ? (extraData['ratingCount'] as num).toInt() : 1;
                                                          final newRating = ((currentRating * ratingCount) + selectedRating) / (ratingCount + 1);
                                                          await workerDoc.set({
                                                            'extraData': {
                                                              'rating': newRating,
                                                              'ratingCount': ratingCount + 1,
                                                            }
                                                          }, SetOptions(merge: true));
                                                        }
                                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال تقييمك للمندوب بنجاح!')));
                                                      } catch (e) {
                                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                                                      }
                                                    },
                                                    child: const Text('إرسال التقييم'),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                      }
                                    : null,
                        isPrimary: o.status == OrderStatus.deliveryAccepted || o.status == OrderStatus.preparing,
                      ),
              ),
              if (o.status == OrderStatus.outForDelivery ||
                  o.status == OrderStatus.completed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrderTrackingScreen(order: o))),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('تتبع الطلب'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    Color text;
    String label;
    switch (status) {
      case OrderStatus.placed:
        bg = Colors.blue.shade50;
        text = Colors.blue.shade700;
        label = 'جديد';
        break;
      case OrderStatus.deliveryAccepted:
        bg = Colors.teal.shade50;
        text = Colors.teal.shade700;
        label = 'تم تعيين مندوب';
        break;
      case OrderStatus.preparing:
        bg = Colors.orange.shade50;
        text = Colors.orange.shade700;
        label = 'جاري التجهيز';
        break;
      case OrderStatus.outForDelivery:
        bg = Colors.purple.shade50;
        text = Colors.purple.shade700;
        label = 'في الطريق';
        break;
      case OrderStatus.completed:
        bg = Colors.green.shade50;
        text = Colors.green.shade700;
        label = 'مكتمل';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    
    final extraData = user.extraData ?? {};
    final shopName = extraData['shopName'] ?? '';
    final commercialReg = extraData['commercialReg'] ?? '';
    final category = extraData['category'] ?? '';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: NabaTheme.primary,
              child: Icon(Icons.storefront_rounded, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(shopName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          
          const Text('بيانات المحل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NabaTheme.primary)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.phone_rounded, color: NabaTheme.primary),
            title: const Text('رقم الهاتف'),
            subtitle: Text(user.phone),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_rounded, color: NabaTheme.primary),
            title: const Text('السجل التجاري'),
            subtitle: Text(commercialReg),
          ),
          ListTile(
            leading: const Icon(Icons.category_rounded, color: NabaTheme.primary),
            title: const Text('التصنيف'),
            subtitle: Text(category),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_on_rounded, color: NabaTheme.primary),
            title: const Text('موقع المحل على الخريطة'),
            subtitle: const Text('اضغط لتحديث موقع المحل'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () async {
              LatLng? initLoc;
              if (extraData['location'] != null) {
                initLoc = LatLng(
                  (extraData['location']['lat'] as num).toDouble(),
                  (extraData['location']['lng'] as num).toDouble()
                );
              }
              final result = await Navigator.push<LatLng>(
                context,
                MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: initLoc)),
              );
              
              if (result != null && mounted) {
                try {
                  final newExtraData = Map<String, dynamic>.from(extraData);
                  newExtraData['location'] = {
                    'lat': result.latitude,
                    'lng': result.longitude,
                  };
                  
                  await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                    'extraData': newExtraData,
                  });
                  
                  // Reload user
                  await context.read<AuthProvider>().reloadUser();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث الموقع بنجاح')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في التحديث: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

