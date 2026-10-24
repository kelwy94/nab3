import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_categories.dart';
import '../widgets/smart_image.dart';
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
  String _searchQuery = '';
  static const _usedFilter = 'مستعمل';
  String _selectedCategory = 'الكل';
  String _sortOption = 'newest';
  int _selectedDiscount = 0;

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

  Widget _headerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: filled ? NabaTheme.brand : Colors.white,
      shape: CircleBorder(
          side: filled ? BorderSide.none : const BorderSide(color: NabaTheme.divider)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 21, color: filled ? Colors.white : NabaTheme.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      floatingActionButton: context.watch<AuthProvider>().isGuest
          ? null
          : FloatingActionButton.extended(
              heroTag: 'market_sell',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
              backgroundColor: NabaTheme.accent,
              foregroundColor: NabaTheme.textPrimary,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('اعرض للبيع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        if (Navigator.of(context).canPop())
                          const SizedBox(
                              width: 52,
                              height: 52,
                              child: NabaBackButton(background: Colors.white)),
                        Expanded(
                          child: Text('السوق', style: NabaTheme.display(26)),
                        ),
                        _headerButton(
                          tooltip: 'طلباتي',
                          icon: Icons.receipt_long_outlined,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersHistoryScreen())),
                        ),
                        const SizedBox(width: 8),
                        Consumer<AppStateProvider>(
                          builder: (context, appState, _) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _headerButton(
                                tooltip: 'السلة',
                                icon: Icons.shopping_cart_outlined,
                                filled: true,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                              ),
                              if (appState.cart.isNotEmpty)
                                Positioned(
                                  top: -2,
                                  left: -2,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 18),
                                    height: 18,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: NabaTheme.accent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text('${appState.cart.length}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: NabaTheme.divider),
                            ),
                            child: TextField(
                              textDirection: TextDirection.rtl,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'دوّر على سماد، بذور، جرار...',
                                hintStyle: TextStyle(color: NabaTheme.textSecondary),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: Icon(Icons.search_rounded, color: NabaTheme.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: NabaTheme.textPrimary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune, color: Colors.white),
                            onPressed: () {
                              _showFilterBottomSheet(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sell used equipment banner
                  GestureDetector(
                    onTap: () {
                      if (context.read<AuthProvider>().isGuest) {
                        GuestUtils.showGuestLoginPrompt(context);
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProductFormScreen(
                                  initialCategory: 'آلات زراعية')));
                    },
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: NabaTheme.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset('assets/images/icons/tractor.png'),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'بيع معداتك المستعملة',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: NabaTheme.primary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'جرارات، محاريث، طلمبات، ألواح شمسية',
                                  style: TextStyle(fontSize: 12, color: NabaTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded, color: NabaTheme.primary),
                        ],
                      ),
                    ),
                  ),

                  // Categories Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('التصنيفات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                        Text('عرض الكل', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  // Categories List
                  SizedBox(
                    height: 45,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      reverse: true, // RTL
                      children: [
                        _buildCategoryChip('الكل', Icons.apps_rounded, _selectedCategory == 'الكل'),
                        _buildCategoryChip(_usedFilter, Icons.autorenew_rounded, _selectedCategory == _usedFilter),
                        for (final c in kProductCategories)
                          _buildCategoryChip(c.name, c.icon, _selectedCategory == c.name),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isCrossDistrict) _buildCrossDistrictBanner(),
                ],
              ),
            ),
            _buildProductGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData? icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? NabaTheme.primaryTint : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? NabaTheme.primary : Colors.grey.shade600),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NabaTheme.primary : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: NabaTheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    String tempSort = _sortOption;
    int tempDiscount = _selectedDiscount;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تصفية وترتيب المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    const Text('ترتيب حسب:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: const Text('الأحدث'),
                      value: 'newest',
                      groupValue: tempSort,
                      onChanged: (v) => setModalState(() => tempSort = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('السعر: من الأقل للأعلى'),
                      value: 'price_asc',
                      groupValue: tempSort,
                      onChanged: (v) => setModalState(() => tempSort = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('السعر: من الأعلى للأقل'),
                      value: 'price_desc',
                      groupValue: tempSort,
                      onChanged: (v) => setModalState(() => tempSort = v!),
                    ),
                    
                    const Divider(),
                    const Text('نسبة الخصم:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [0, 10, 20, 30].map((int discount) {
                        return ChoiceChip(
                          label: Text(discount == 0 ? 'الكل' : '$discount% فأكثر'),
                          selected: tempDiscount == discount,
                          onSelected: (bool selected) {
                            if (selected) {
                              setModalState(() => tempDiscount = discount);
                            }
                          },
                          selectedColor: NabaTheme.primary.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NabaTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _sortOption = tempSort;
                            _selectedDiscount = tempDiscount;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('تطبيق'),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildCrossDistrictBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'أنت تتصفح منتجات في مركز $_selectedDistrict وهو مختلف عن مركز إقامتك',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    final catalog = Provider.of<AppStateProvider>(context);
    List<CatalogItem> filteredProducts = catalog.products.where((p) => p.isApproved).toList();

    if (_searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts.where((p) {
        return p.name.contains(_searchQuery) || p.category.contains(_searchQuery);
      }).toList();
    }

    if (_selectedCategory == _usedFilter) {
      filteredProducts = filteredProducts.where((p) => isUsedCondition(p.condition)).toList();
    } else if (_selectedCategory != 'الكل') {
      filteredProducts = filteredProducts
          .where((p) => categoryByName(p.category).name == _selectedCategory)
          .toList();
    }

    if (_selectedDiscount > 0) {
      filteredProducts = filteredProducts.where((p) => p.discountPercentage >= _selectedDiscount).toList();
    }

    if (_sortOption == 'price_asc') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortOption == 'price_desc') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else {
      filteredProducts = filteredProducts.reversed.toList();
    }

    if (filteredProducts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _selectedDistrict != null
                    ? 'لا يوجد منتجات في $_selectedDistrict'
                    : 'لا توجد منتجات متاحة',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final p = filteredProducts[index];
            return _buildProductCard(context, p);
          },
          childCount: filteredProducts.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, CatalogItem p) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(p.photoUrl, placeholderIcon: categoryByName(p.category).icon),
                    if (isUsedCondition(p.condition))
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('مستعمل',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(p.unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.discountPercentage > 0) Text('${(p.price / (1 - p.discountPercentage / 100)).toStringAsFixed(0)} ج.م',
                              style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 11)),
                          Text('${p.price == p.price.roundToDouble() ? p.price.toStringAsFixed(0) : p.price} ج.م',
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (p.negotiable)
                            Text('قابل للتفاوض', style: TextStyle(color: Colors.orange.shade800, fontSize: 10)),
                        ],
                      ),
                      if (categoryByName(p.category).isMachinery || isUsedCondition(p.condition))
                        // Machinery and used items are arranged with the seller.
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: NabaTheme.primaryTint, shape: BoxShape.circle),
                            child: const Icon(Icons.call_rounded, color: NabaTheme.primary, size: 18),
                          ),
                        )
                      else
                      GestureDetector(
                        onTap: () {
                          if (context.read<AuthProvider>().isGuest) {
                            GuestUtils.showGuestLoginPrompt(context);
                            return;
                          }
                          context.read<AppStateProvider>().addToCart(p);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج للسلة بنجاح'), duration: Duration(seconds: 1)));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: NabaTheme.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: NabaTheme.primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
