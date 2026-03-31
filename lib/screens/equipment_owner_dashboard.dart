import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'settings_screen.dart';

class EquipmentOwnerDashboard extends StatelessWidget {
  const EquipmentOwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'لوحة إدارة المعدات',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildActionHeader(),
            const SizedBox(height: 32),
            const Text('معداتك المسجلة (4)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildEquipmentItem('جرار نيوهولاند 75 حصان', 'متاح للايجار',
                Icons.agriculture_rounded, Colors.blue),
            const SizedBox(height: 12),
            _buildEquipmentItem('محراث هيدروليك 11 سلاح', 'قيد الصيانة',
                Icons.handyman_rounded, Colors.orange),
            const SizedBox(height: 32),
            const Text('طلبات تأجير حديثة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildRequestCard(
                'طلب تأجير جرار', 'المنيا، سمالوط - 3 أيام', '1,500 ج.م'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader() {
    return NabaCard(
      padding: const EdgeInsets.all(24),
      onTap: () {},
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: NabaTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_business_rounded,
                color: NabaTheme.primary, size: 32),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('إضافة معدة جديدة',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text('قم بتسجيل معدتك الآن وابدأ في استقبال طلبات التأجير',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEquipmentItem(
      String name, String status, IconData icon, Color color) {
    return NabaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {},
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(status,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      backgroundColor: color,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(String type, String details, String price) {
    return NabaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price,
                  style: const TextStyle(
                      color: NabaTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text(type,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(details,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('رفض الطلب'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                      backgroundColor: NabaTheme.primary,
                      foregroundColor: Colors.white),
                  child: const Text('قبول الطلب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
