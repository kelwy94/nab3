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
import 'profile_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  final user = auth.user;
                                  return GestureDetector(
                                    onTap: () {
                                      if (user != null) {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                                      } else {
                                        GuestUtils.showGuestLoginPrompt(context);
                                      }
                                    },
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFE2EBE5),
                                      backgroundImage: (user != null && user.profileImageUrl != null)
                                          ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                          : (user != null && user.profileImageBase64 != null)
                                              ? MemoryImage(base64Decode(user.profileImageBase64!))
                                              : null,
                                      child: (user == null || (user.profileImageUrl == null && user.profileImageBase64 == null))
                                          ? const Icon(Icons.person, color: Color(0xFF265B33))
                                          : null,
                                    ),
                                  );
                                }
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Text('مرحباً بك', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.waving_hand, color: Colors.amber, size: 14),
                                      ],
                                    ),
                                    Consumer<AuthProvider>(
                                      builder: (context, auth, _) => Text(
                                        auth.user?.fullName ?? 'ضيف',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Left side
                        Row(
                          textDirection: TextDirection.rtl,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87, size: 24),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Consumer<AppStateProvider>(
                                    builder: (context, appState, child) {
                                      if (appState.cart.isEmpty) return const SizedBox.shrink();
                                      return Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: Text('${appState.cart.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.receipt_long_rounded, color: Colors.black87, size: 24),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersHistoryScreen())),
                            ),
                            const SizedBox(width: 12),
                            if (!Provider.of<AuthProvider>(context, listen: false).isGuest)
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen())),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('أضف بيعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF265B33),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  elevation: 2,
                                  shadowColor: Colors.black26,
                                ),
                              ),
                          ],
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
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: TextField(
                              textDirection: TextDirection.rtl,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'ابحث عن المنتجات...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                suffixIcon: Icon(Icons.search, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2EBE5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune, color: Color(0xFF265B33)),
                            onPressed: () {
                              _showFilterBottomSheet(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Banner
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2EBE5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'خصم حتى 20% على المستلزمات الزراعية!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF265B33),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                child: const Text('تسوق الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const Expanded(
                          flex: 1,
                          child: Icon(Icons.agriculture_rounded, size: 70, color: Color(0xFF265B33)),
                        ),
                      ],
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
                        _buildCategoryChip('الكل', null, _selectedCategory == 'الكل'),
                        _buildCategoryChip('بذور', null, _selectedCategory == 'بذور'),
                        _buildCategoryChip('أسمدة', null, _selectedCategory == 'أسمدة'),
                        _buildCategoryChip('مبيدات', null, _selectedCategory == 'مبيدات'),
                        _buildCategoryChip('معدات', null, _selectedCategory == 'معدات'),
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
          color: isSelected ? const Color(0xFFE2EBE5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF265B33) : Colors.grey.shade600),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF265B33) : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: Color(0xFF265B33)),
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
                          selectedColor: const Color(0xFF265B33).withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF265B33),
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

    if (_selectedCategory != 'الكل') {
      filteredProducts = filteredProducts.where((p) {
        final cat = p.category.toLowerCase();
        final sel = _selectedCategory.toLowerCase();
        return cat.contains(sel) || sel.contains(cat);
      }).toList();
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

  Widget _buildProductCard(BuildContext context, dynamic p) {
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
                child: _buildImageSafe(p.photoUrl),
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
                          Text('${p.price} ج.م',
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
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
                            color: Color(0xFFE2EBE5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF265B33), size: 18),
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

  Widget _buildImageSafe(String? imageString) {
    if (imageString == null || imageString.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 40));
    }
    if (imageString.startsWith('http')) {
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
      );
    }
    try {
      String clean = imageString;
      if (clean.startsWith('base64,')) clean = clean.substring(7);
      else if (clean.contains(',')) clean = clean.split(',').last;
      final bytes = base64Decode(clean.trim());
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
      );
    } catch (e) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40));
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
