import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/delivery_data.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../providers/job_provider.dart';
import '../models/types.dart';
import '../utils/guest_utils.dart';
import 'request_worker_screen.dart';
import 'request_equipment_screen.dart';
import 'job_details_screen.dart';
import 'cart_screen.dart';
import 'product_details_screen.dart';
import 'orders_history_screen.dart';
import 'product_form_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final bool showAppBar;
  const MarketplaceScreen({super.key, this.showAppBar = true});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String? _selectedDistrict;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userDistrict = auth.user?.extraData?['district'] as String?;
      _selectedDistrict = userDistrict;
      _initialized = true;
    }
  }

  String? get _userDistrict {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.user?.extraData?['district'] as String?;
  }

  bool get _isCrossDistrict =>
      _selectedDistrict != null &&
      _userDistrict != null &&
      _selectedDistrict != _userDistrict;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: widget.showAppBar
          ? NabaAppBar(
              title: 'سوق نبع',
              showBackButton: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded),
                  tooltip: 'مشترياتي وتتبعها',
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrdersHistoryScreen()));
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()));
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Consumer<AppStateProvider>(
                        builder: (context, appState, child) {
                          if (appState.cart.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${appState.cart.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // District Selector
          _buildDistrictSelector(),

          // Cross-District Warning Banner
          if (_isCrossDistrict) _buildCrossDistrictBanner(),

          // Products Grid
          Expanded(child: _buildProductGrid()),
        ],
      ),
      floatingActionButton: Provider.of<AuthProvider>(context, listen: false).isGuest
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
              },
              backgroundColor: NabaTheme.primary,
              icon: const Icon(Icons.add_business_rounded, color: Colors.white),
              label: const Text('أضف إعلان / بيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildDistrictSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NabaTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: NabaTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDistrict,
                isExpanded: true,
                hint: const Text('اختر المركز',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Colors.grey)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: NabaTheme.primary),
                items: kDistricts.map((district) {
                  final isUserDistrict = district == _userDistrict;
                  return DropdownMenuItem(
                    value: district,
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(district,
                            style: TextStyle(
                              fontWeight: isUserDistrict
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isUserDistrict
                                  ? NabaTheme.primary
                                  : Colors.black87,
                            )),
                        if (isUserDistrict) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NabaTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('مركزك',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: NabaTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDistrict = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossDistrictBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ أنت تتصفح سوق $_selectedDistrict. خدمة التوصيل بين المراكز غير متاحة حالياً — التنسيق يكون مباشرة مع البائع.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    final products = Provider.of<AppStateProvider>(context).products;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allUsers = authProvider.allUsers;

    final currentUser = authProvider.user;

    // Filter products by selected district and approval status
    List<CatalogItem> filteredProducts = products.where((p) {
      // Must be approved OR owned by the current user
      final isMine = currentUser != null && p.sellerUserId == currentUser.id;
      if (!p.isApproved && !isMine) return false;

      if (_selectedDistrict == null) return true;

      final seller = allUsers.where((u) => u.id == p.sellerUserId).firstOrNull;
      if (seller == null) return true; 
      final sellerDistrict = seller.extraData?['district'] as String?;
      if (sellerDistrict == null) return true; 
      
      return sellerDistrict == _selectedDistrict;
    }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _selectedDistrict != null
                  ? 'لا توجد منتجات في $_selectedDistrict حالياً'
                  : 'لا توجد منتجات',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final p = filteredProducts[index];
        return _buildProductCard(context, p);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic p) {
    return NabaCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(product: p)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageSafe(p.photoUrl),
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
                        fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(p.unit,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: NabaTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 16),
                      ),
                      onPressed: () {
                        if (context.read<AuthProvider>().isGuest) {
                          GuestUtils.showGuestLoginPrompt(context);
                          return;
                        }
                        context.read<AppStateProvider>().addToCart(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت إضافة المنتج للسلة بنجاح'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    Text('${p.price} ج.م',
                        style: const TextStyle(
                            color: NabaTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSafe(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 40));
    }

    try {
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64.trim());
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error rendering image: $error');
          return const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40));
        },
      );
    } catch (e) {
      debugPrint('Error decoding base64: $e');
      return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 40));
    }
  }
}

class ServicesList extends StatelessWidget {
  const ServicesList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _serviceCard(
          context,
          'طلب عامل زراعي',
          'ري، تقليم، مكافحة آفات، جني محصول',
          Icons.engineering_rounded,
          Colors.blue.shade700,
          () {
            if (Provider.of<AuthProvider>(context, listen: false).isGuest) {
              GuestUtils.showGuestLoginPrompt(context);
              return;
            }
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RequestWorkerScreen()));
          },
        ),
        const SizedBox(height: 20),
        _serviceCard(
          context,
          'طلب معدة زراعية',
          'جرارات، حفارات، مواتير ري، حفار ليزر',
          Icons.agriculture_rounded,
          Colors.orange.shade700,
          () {
            if (Provider.of<AuthProvider>(context, listen: false).isGuest) {
              GuestUtils.showGuestLoginPrompt(context);
              return;
            }
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RequestEquipmentScreen()));
          },
        ),
        const SizedBox(height: 32),
        const MyActiveRequests(),
      ],
    );
  }

  Widget _serviceCard(BuildContext context, String title, String desc,
      IconData icon, Color color, VoidCallback onTap) {
    return NabaCard(
      onTap: onTap,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.7), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color)),
                const SizedBox(height: 4),
                Text(
                  desc,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}

class MyActiveRequests extends StatelessWidget {
  const MyActiveRequests({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final jobs = Provider.of<JobProvider>(context)
        .jobs
        .where((j) =>
            j.requesterUserId == user?.id &&
            j.status != JobStatus.paid &&
            j.status != JobStatus.reviewed)
        .toList();

    if (jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'طلباتي النشطة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...jobs.reversed.map((job) => _buildRequestCard(context, job)),
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, Job job) {
    final isWorker = job.type == 'worker';
    final color = isWorker ? Colors.blue.shade700 : Colors.orange.shade700;

    String statusLabel = 'نشط';
    Color statusColor = Colors.green;

    if (job.status == JobStatus.accepted) {
      statusLabel = 'تم القبول';
      statusColor = Colors.blue;
    } else if (job.status == JobStatus.inProgress) {
      statusLabel = 'جاري التنفيذ';
      statusColor = NabaTheme.primary;
    } else if (job.status == JobStatus.completed) {
      statusLabel = 'انتظر الدفع';
      statusColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NabaCard(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)));
        },
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              isWorker ? Icons.engineering_rounded : Icons.agriculture_rounded,
              color: color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    job.serviceType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'السعر: ${job.price?.toStringAsFixed(0) ?? "غير محدد"} ج.م',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
