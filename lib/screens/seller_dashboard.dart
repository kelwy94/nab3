import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'order_tracking_screen.dart';
import 'product_form_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildOrdersTab(),
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
                child: NabaButton(
                  text: 'تجهيز الطلب',
                  onPressed: o.status == OrderStatus.placed
                      ? () {
                          context
                              .read<CatalogProvider>()
                              .updateOrderStatus(o.id, OrderStatus.confirmed);
                        }
                      : null,
                  isPrimary: o.status == OrderStatus.placed,
                ),
              ),
              if (o.status == OrderStatus.confirmed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context
                          .read<CatalogProvider>()
                          .updateOrderStatus(o.id, OrderStatus.outForDelivery);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('بدء التوصيل'),
                  ),
                ),
              ],
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
    String text = 'موضوع';
    Color color = Colors.orange;
    switch (status) {
      case OrderStatus.placed:
        text = 'جديد';
        color = Colors.blue;
        break;
      case OrderStatus.confirmed:
        text = 'مؤكد';
        color = Colors.orange;
        break;
      case OrderStatus.outForDelivery:
        text = 'جاري التوصيل';
        color = Colors.purple;
        break;
      case OrderStatus.completed:
        text = 'مكتمل';
        color = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
}
