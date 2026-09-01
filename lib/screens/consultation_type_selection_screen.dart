import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'consultation_request_screen.dart';
import 'visit_request_screen.dart';

class ConsultationTypeSelectionScreen extends StatelessWidget {
  final String engineerId;
  final Map<String, dynamic> engineerData;

  const ConsultationTypeSelectionScreen({
    super.key,
    required this.engineerId,
    required this.engineerData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: NabaAppBar(
          title: engineerData['fullName'] ?? 'مهندس', showBackButton: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'كيف تفضل التواصل مع المهندس؟',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر نوع الخدمة التي تناسب احتياجك الحالي',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Remote Consultation Option
              _buildOptionCard(
                context,
                title: 'استشارة عن بعد',
                description:
                    'أرسل تفاصيل المشكلة (نص أو صوت) واحصل على الرد المباشر',
                icon: Icons.forum_rounded,
                color: Colors.blue,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConsultationRequestScreen(
                        engineerId: engineerId,
                        engineerData: engineerData,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Field Visit Option
              _buildOptionCard(
                context,
                title: 'طلب زيارة ميدانية',
                description:
                    'استدعاء المهندس لمزرعتك لفحص المشكلة على أرض الواقع',
                icon: Icons.directions_car_rounded,
                color: Colors.orange,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitRequestScreen(
                        engineerId: engineerId,
                        engineerData: engineerData,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
