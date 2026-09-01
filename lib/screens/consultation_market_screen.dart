import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'consultation_type_selection_screen.dart';

class ConsultationMarketScreen extends StatefulWidget {
  const ConsultationMarketScreen({super.key});

  @override
  State<ConsultationMarketScreen> createState() =>
      _ConsultationMarketScreenState();
}

class _ConsultationMarketScreenState extends State<ConsultationMarketScreen> {
  String _searchQuery = '';
  String? _selectedSpecialization;

  final List<String> _specializations = [
    'الكل',
    'مهندس انتاج نباتي',
    'مهندس الزراعة الذكية/الهندسة الزراعية',
    'مهندس الأراضي والمياه والاستصلاح',
    'مهندس وقاية النبات',
    'مهندس الصناعات الغذائية وجودة الغذاء',
    'مهندس الإنتاج النباتي والحيواني',
    'مهندس استزراع سمكي',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabaAppBar(title: 'استشارات هندسية زراعية'), // Renamed
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: NabaTheme.primary,
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم المهندس أو الكلمة المفتاحية...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _specializations.length,
                      itemBuilder: (context, index) {
                        final spec = _specializations[index];
                        final isSelected = _selectedSpecialization == spec ||
                            (_selectedSpecialization == null && spec == 'الكل');
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ChoiceChip(
                            label: Text(spec),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedSpecialization =
                                    spec == 'الكل' ? null : spec;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: UserRole.engineer.toString())
                    .where('status',
                        isEqualTo: AccountStatus.approved.toString())
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('لا يوجد مهندسين متاحين حالياً.'));
                  }

                  // Filter manually for search and specialization
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // We must ensure the role string actually matches 'UserRole.engineer' because we store it via enum.toString()
                    if (data['role'] != UserRole.engineer.toString()) {
                      return false;
                    }
                    if (data['status'] != AccountStatus.approved.toString() &&
                        data['status'] != 'approved') {
                      return false;
                    }

                    final name =
                        (data['fullName'] ?? '').toString().toLowerCase();
                    final extraData =
                        (data['extraData'] as Map<String, dynamic>?) ?? {};
                    final spec = extraData['specialization'] as String?;
                    final fieldType = extraData['fieldWorkType'] as String?;

                    if (_selectedSpecialization != null &&
                        spec != _selectedSpecialization) {
                      return false;
                    }

                    if (_searchQuery.isNotEmpty) {
                      return name.contains(_searchQuery.toLowerCase()) ||
                          (spec?.contains(_searchQuery) ?? false) ||
                          (fieldType?.contains(_searchQuery) ?? false);
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                        child: Text('لا يوجد مهندسين يطابقون بحثك.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final userDoc = filteredDocs[index];
                      final data = userDoc.data() as Map<String, dynamic>;
                      final extraData =
                          (data['extraData'] as Map<String, dynamic>?) ?? {};

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConsultationTypeSelectionScreen(
                                  engineerId: userDoc.id,
                                  engineerData: data,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor:
                                      NabaTheme.primary.withOpacity(0.1),
                                  backgroundImage: data['profileImageBase64'] !=
                                          null
                                      ? MemoryImage(const Base64Decoder()
                                          .convert(data['profileImageBase64']))
                                      : null,
                                  child: data['profileImageBase64'] == null
                                      ? const Icon(Icons.person,
                                          size: 40, color: NabaTheme.primary)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['fullName'] ?? 'مهندس مجهول',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        extraData['specialization'] ??
                                            'تخصص غير متوفر',
                                        style: const TextStyle(
                                          color: NabaTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.work_history_rounded,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'خبرة ${extraData['experienceYears'] ?? 0} سنة',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.location_on_rounded,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            extraData['fieldWorkType'] ??
                                                'ميداني',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      if (extraData['aboutMe'] != null &&
                                          extraData['aboutMe']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          extraData['aboutMe'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_left_rounded,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
