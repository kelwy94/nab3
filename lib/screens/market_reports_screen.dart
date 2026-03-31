import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class MarketReportsScreen extends StatelessWidget {
  const MarketReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'تقارير السوق'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('النشرة الزراعية والاقتصادية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildReportCard(
              context,
              'مؤشر أسعار المحاصيل وتوقعات العائد للموسم القادم بالفيوم',
              'يمثل هذا التقرير تحليلاً لاحتياجات السوق المحلي مقارنة بالإنتاج المتوقع لمساعدتك في اتخاذ قرارات التمويل.',
              Icons.trending_up_rounded,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              context,
              'تحليل جدوى الاستثمار في الآبار بالأراضي المستصلحة',
              'نظرة تفصيلية حول تكاليف الحفر وتركيب الطاقات الشمسية مقارنة بعوائد المزارعين السنوية عبر المشاركة.',
              Icons.pie_chart_rounded,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              context,
              'تقرير حول التطور التكنولوجي للمعدات وفرص الإيجار',
              'يقيم التقرير معدل الطلب على استئجار الجرارات والحفارات في منطقة الدلتا وصعيد مصر.',
              Icons.auto_graph_rounded,
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String title, String desc, IconData icon, Color color) {
    return NabaCard(
      padding: const EdgeInsets.all(20),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري تجهيز وبدء تحميل التقرير، يرجى الانتظار...')),
        );
      },
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(desc,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.download_rounded, size: 14, color: NabaTheme.primary),
                    SizedBox(width: 4),
                    Text('تحميل التقرير',
                        style: TextStyle(
                            color: NabaTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
