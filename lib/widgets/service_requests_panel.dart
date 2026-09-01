import 'package:flutter/material.dart';

import '../theme.dart';
import '../screens/marketplace_screen.dart';
import '../screens/request_worker_screen.dart';
import '../screens/request_equipment_screen.dart';
import '../screens/consultation_market_screen.dart';
import '../screens/orders_history_screen.dart';

/// A reusable panel that shows the 4 main service request buttons.
/// Used in all non-farmer dashboards to give every user access to services.
class ServiceRequestsPanel extends StatelessWidget {
  const ServiceRequestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: NabaTheme.primary,
          foregroundColor: Colors.white,
          title: const Text('الخدمات المتاحة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'طلب خدمة', icon: Icon(Icons.handyman_rounded)),
              Tab(text: 'السوق', icon: Icon(Icons.storefront_rounded)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'مشترياتي وطلباتي',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OrdersHistoryScreen())),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildRequestServicesView(context),
            const MarketplaceScreen(
                showAppBar: false), // Embed the market directly here
          ],
        ),
      ),
    );
  }

  Widget _buildRequestServicesView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader('أقسام الخدمات'),
          const SizedBox(height: 12),
          _buildServiceGrid(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        textAlign: TextAlign.right,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NabaTheme.textPrimary));
  }

  Widget _buildServiceGrid(BuildContext context) {
    final services = [
      {
        'title': 'طلب عامل',
        'icon': Icons.handyman_rounded,
        'color': Colors.orange.shade700,
        'screen': 'worker'
      },
      {
        'title': 'طلب معدة',
        'icon': Icons.agriculture_rounded,
        'color': Colors.blue.shade700,
        'screen': 'equipment'
      },
      {
        'title': 'استشارة هندسية',
        'icon': Icons.workspace_premium_rounded,
        'color': Colors.teal,
        'screen': 'consult'
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: services
          .map((s) => _buildServiceCard(
                context,
                s['title'] as String,
                s['icon'] as IconData,
                s['color'] as Color,
                s['screen'] as String,
              ))
          .toList(),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, IconData icon,
      Color color, String screen) {
    return GestureDetector(
      onTap: () {
        Widget target;
        switch (screen) {
          case 'worker':
            target = const RequestWorkerScreen();
            break;
          case 'equipment':
            target = const RequestEquipmentScreen();
            break;
          case 'consult':
          default:
            target = const ConsultationMarketScreen();
            break;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => target));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.7), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
