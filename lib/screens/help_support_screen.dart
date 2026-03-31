import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabaAppBar(title: 'المساعدة والدعم'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent_rounded, size: 80, color: NabaTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'نحن هنا لمساعدتك',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'لأي استفسار أو مشكلة تواجهك في التطبيق، يرجى التواصل مع الإدارة المركزية (المالك) مباشرة عبّر القنوات التالية:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildContactCard(
              title: 'المالك',
              value: 'كارم عاطف علوي',
              icon: Icons.person_rounded,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              title: 'رقم الهاتف',
              value: '01284477397',
              icon: Icons.phone_rounded,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              title: 'البريد الإلكتروني',
              value: 'kelwy94@gmail.com',
              icon: Icons.email_rounded,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({required String title, required String value, required IconData icon, required Color color}) {
    return NabaCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        textDirection: TextDirection.rtl,
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
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
