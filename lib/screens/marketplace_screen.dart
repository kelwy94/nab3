import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../providers/job_provider.dart';
import '../models/types.dart';
import 'request_worker_screen.dart';
import 'request_equipment_screen.dart';
import 'job_details_screen.dart';
import 'cart_screen.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: NabaTheme.background,
        appBar: NabaAppBar(
          title: 'سوق نبع',
          showBackButton: false,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CartScreen()));
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Consumer<AppStateProvider>(
                    builder: (context, appState, child) {
                      if (appState.cart.isEmpty) return const SizedBox.shrink();
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
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: NabaTheme.primary,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'عمال ومعدات'),
                  Tab(text: 'منتجات ومستلزمات'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ServicesList(),
                  ProductCatalog(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCatalog extends StatelessWidget {
  const ProductCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final products = Provider.of<AppStateProvider>(context).products;
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return _buildProductCard(context, p);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic p) {
    return NabaCard(
      padding: EdgeInsets.zero,
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
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RequestWorkerScreen())),
        ),
        const SizedBox(height: 20),
        _serviceCard(
          context,
          'طلب معدة زراعية',
          'جرارات، حفارات، مواتير ري، حفار ليزر',
          Icons.agriculture_rounded,
          Colors.orange.shade700,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RequestEquipmentScreen())),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 40),
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
