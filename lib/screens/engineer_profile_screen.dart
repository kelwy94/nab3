import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'consultation_request_screen.dart';
import 'visit_request_screen.dart';

class EngineerProfileScreen extends StatelessWidget {
  final String engineerId;
  final Map<String, dynamic> engineerData;

  const EngineerProfileScreen({
    super.key,
    required this.engineerId,
    required this.engineerData,
  });

  @override
  Widget build(BuildContext context) {
    final extraData =
        (engineerData['extraData'] as Map<String, dynamic>?) ?? {};
    List<String> fieldWorkTypesList =
        (extraData['fieldWorkTypes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
    if (fieldWorkTypesList.isEmpty && extraData['fieldWorkType'] != null) {
      fieldWorkTypesList.add(extraData['fieldWorkType'].toString());
    }

    final experienceYears = extraData['experienceYears'] ?? '0';
    final aboutMe = extraData['aboutMe'] as String?;
    final specialization = extraData['specialization'] ?? 'مهندس زراعي';
    final certificateBase64 = extraData['certificateImageBase64'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const NabaAppBar(title: 'بروفايل المهندس', showBackButton: true),
      // Bottom buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConsultationRequestScreen(
                          engineerId: engineerId,
                          engineerData: engineerData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('طلب استشارة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitRequestScreen(
                          engineerId: engineerId,
                          engineerData: engineerData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_car_rounded),
                  label: const Text('طلب زيارة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: NabaTheme.primary.withOpacity(0.1),
                      backgroundImage:
                          engineerData['profileImageBase64'] != null
                              ? MemoryImage(const Base64Decoder()
                                  .convert(engineerData['profileImageBase64']))
                              : null,
                      child: engineerData['profileImageBase64'] == null
                          ? const Icon(Icons.person,
                              size: 50, color: NabaTheme.primary)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      engineerData['fullName'] ?? 'مهندس مجهول',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialization,
                      style: const TextStyle(
                          fontSize: 16,
                          color: NabaTheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 24),
                        const SizedBox(width: 4),
                        const Text('5.0',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('(0 تقييم)',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              // Experience Box
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: NabaTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: NabaTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.work_history_rounded,
                            color: NabaTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سنوات الخبرة',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('خبرة $experienceYears سنوات',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Fields of work chips
              if (fieldWorkTypesList.isNotEmpty)
                _buildSectionInfo(
                    'مجلات العمل (الخبرات)',
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fieldWorkTypesList
                            .map((type) => Chip(
                                  label: Text(type),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                          color: Colors.grey.shade300)),
                                ))
                            .toList(),
                      ),
                    )),

              // About Me
              if (aboutMe != null && aboutMe.isNotEmpty)
                _buildSectionInfo(
                    'نبذة شخصية',
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(aboutMe,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.black87)),
                    )),

              // Certificate
              if (certificateBase64 != null)
                _buildSectionInfo(
                    'الشهادات والاعتمادات',
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          const Base64Decoder().convert(certificateBase64),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    )),

              const SizedBox(height: 16),

              // Ratings Placeholder
              _buildSectionInfo(
                  'آراء العملاء',
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('لا توجد تقييمات حالياً',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionInfo(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content,
        ],
      ),
    );
  }
}
