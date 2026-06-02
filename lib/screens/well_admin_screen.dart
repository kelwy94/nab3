import 'package:flutter/material.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class WellAdminScreen extends StatelessWidget {
  final Well well;
  const WellAdminScreen({super.key, required this.well});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(title: 'إدارة: ${well.wellName}'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModernStatCard(),
            const SizedBox(height: 32),
            const Text('الأعضاء والمشاركين',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
            const SizedBox(height: 16),
            _buildModernMembersList(),
            const SizedBox(height: 40),
            NabaButton(
              text: 'توليد جدول ري جديد',
              icon: Icons.auto_awesome_rounded,
              onPressed: () => _generateSchedule(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NabaTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: NabaTheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('فدان', well.irrigatedAreaFeddan.toString(),
                  Icons.landscape_rounded),
              Container(width: 1, height: 40, color: Colors.white24),
              _statItem('متر عمق', well.depthMeters.toString(),
                  Icons.vertical_align_bottom_rounded),
              Container(width: 1, height: 40, color: Colors.white24),
              _statItem('مشارك', '12', Icons.people_alt_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildModernMembersList() {
    return Column(
      children: List.generate(
          3,
          (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NabaCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const CircleAvatar(
                          backgroundColor: NabaTheme.primary,
                          child:
                              Text('م', style: TextStyle(color: Colors.white))),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('محمد علي عبد الله',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('15 فدان - المحاصيل: قمح، ذرة',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (index == 0)
                        const Chip(
                          label: Text('مسؤول',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          backgroundColor: NabaTheme.accent,
                        ),
                      IconButton(
                          icon: const Icon(Icons.settings_outlined,
                              color: Colors.grey, size: 20),
                          onPressed: () {}),
                    ],
                  ),
                ),
              )),
    );
  }

  void _generateSchedule(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('جاري توليد الجدول والتحقق من القواعد...'),
          backgroundColor: NabaTheme.primary),
    );
  }
}
