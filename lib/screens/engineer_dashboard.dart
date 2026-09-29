import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'profile_screen.dart';
import 'dart:convert';
import 'engineer_consultation_details_screen.dart';
import '../widgets/service_requests_panel.dart';
import '../widgets/sell_crop_card.dart';

class EngineerDashboard extends StatefulWidget {
  const EngineerDashboard({super.key});

  @override
  State<EngineerDashboard> createState() => _EngineerDashboardState();
}

class _EngineerDashboardState extends State<EngineerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('لوحة الحساب الاحترافي',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: NabaTheme.primary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded,
                color: Colors.white),
            onPressed: () {}, // For future notifications
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('consultations')
              .where('engineerUserId', isEqualTo: user.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs.toList() ?? [];
            docs.sort((a, b) {
              final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
              final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            // Categorize
            final newRequests = <DocumentSnapshot>[];
            final inProgressRequests = <DocumentSnapshot>[];
            final confirmedRequests = <DocumentSnapshot>[];
            final archivedRequests = <DocumentSnapshot>[];

            for (var doc in docs) {
              final statusStr = (doc.data() as Map)['status']?.toString() ?? '';

              if (statusStr.contains('pendingEngineerApproval')) {
                newRequests.add(doc);
              } else if (statusStr.contains('pendingPriceApproval') ||
                  statusStr.contains('negotiatingTime')) {
                inProgressRequests.add(doc);
              } else if (statusStr.contains('confirmed')) {
                confirmedRequests.add(doc);
              } else if (statusStr.contains('completed') ||
                  statusStr.contains('rated') ||
                  statusStr.contains('rejected')) {
                archivedRequests.add(doc);
              }
            }

            // Sort confirmed requests by their scheduled (proposed) date
            confirmedRequests.sort((a, b) {
              final aTime = (a.data() as Map)['proposedDate'] as Timestamp?;
              final bTime = (b.data() as Map)['proposedDate'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return aTime.compareTo(bTime);
            });

            return IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(user, newRequests, inProgressRequests,
                    archivedRequests.length),
                _buildScheduleTab(confirmedRequests),
                _buildArchiveTab(archivedRequests),
                const ServiceRequestsPanel(),
                const ProfileScreen(isTab: true),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: NabaTheme.primary,
            unselectedItemColor: Colors.grey.shade400,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_rounded), label: 'الجدول'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_rounded), label: 'الأرشيف'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.apps_rounded), label: 'الخدمات'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'البروفايل'),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== HOME TAB ======================
  Widget _buildHomeTab(User user, List<DocumentSnapshot> newReqs,
      List<DocumentSnapshot> inProgress, int completedCount) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(user),
          const SellCropCard(),
          _buildSummaryCards(newReqs.length, inProgress.length, completedCount),
          _buildSectionTitle('الطلبات الواردة (${newReqs.length})',
              Icons.mark_email_unread_rounded, Colors.orange),
          newReqs.isEmpty
              ? _buildEmptyState('لا توجد طلبات جديدة حالياً')
              : _buildList(newReqs, true),
          _buildSectionTitle('الطلبات الجارية (${inProgress.length})',
              Icons.autorenew_rounded, Colors.blue),
          inProgress.isEmpty
              ? _buildEmptyState('لا توجد تسعيرات قيد التفاوض')
              : _buildList(inProgress, false),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(User user) {
    final extra = user.extraData ?? {};
    final specialization = extra['specialization'] ?? 'استشاري زراعي';
    MemoryImage? avatar;
    if (user.profileImageBase64 != null) {
      avatar =
          MemoryImage(const Base64Decoder().convert(user.profileImageBase64!));
    }

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 20),
      decoration: const BoxDecoration(
        color: NabaTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: avatar,
                child: avatar == null
                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(specialization,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      Text(' 4.9 (12 تقييم)',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
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

  Widget _buildSummaryCards(
      int newCount, int inProgressCount, int completedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSingleCard('جديد', newCount.toString(),
                Icons.move_to_inbox_rounded, Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSingleCard('جارية', inProgressCount.toString(),
                Icons.hourglass_top_rounded, Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSingleCard('مكتملة', completedCount.toString(),
                Icons.done_all_rounded, Colors.teal),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ====================== LIST BUILDER ======================
  Widget _buildList(List<DocumentSnapshot> docs, bool isNew) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        final statusStr = data['status']?.toString() ?? '';
        final statusEnum = ConsultationStatus.values.firstWhere(
            (e) => statusStr.contains(e.name),
            orElse: () => ConsultationStatus.pendingEngineerApproval);

        Color c = Colors.grey;
        if (statusEnum == ConsultationStatus.pendingPriceApproval) {
          c = Colors.blue;
        } else if (statusEnum == ConsultationStatus.negotiatingTime)
          c = Colors.amber.shade700;
        else if (statusEnum == ConsultationStatus.confirmed)
          c = Colors.green;
        else if (statusEnum == ConsultationStatus.completed)
          c = Colors.teal;
        else if (statusEnum == ConsultationStatus.rejected) c = Colors.red;

        Color cardColor = isNew ? Colors.orange : c;
        bool isFieldVisit = data['serviceType'] == 'fieldVisit';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EngineerConsultationDetailsScreen(
                      requestId: doc.id,
                      requestData: data,
                      status: statusEnum,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cardColor.withOpacity(0.1),
                          child: Icon(
                              isFieldVisit ? Icons.directions_car : Icons.chat,
                              color: cardColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['farmerName'] ?? 'مزارع',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(_formatDateText(data['createdAt']),
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text('طلب جديد',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          )
                        else
                          _buildStatusBadge(statusEnum),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('تفاصيل المشكلة:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      data['problemDescription'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    if (isNew)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: NabaTheme.primary,
                                  foregroundColor: Colors.white),
                              icon: const Icon(Icons.price_check, size: 18),
                              label: const Text('تسعير المشكلة'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EngineerConsultationDetailsScreen(
                                      requestId: doc.id,
                                      requestData: data,
                                      status: statusEnum,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('عرض التفاصيل والمفاوضة',
                              style: TextStyle(
                                  color: NabaTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Icon(Icons.chevron_right_rounded,
                              color: NabaTheme.primary, size: 16),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ConsultationStatus status) {
    Color c = Colors.grey;
    String t = '';
    if (status == ConsultationStatus.pendingPriceApproval) {
      c = Colors.blue;
      t = 'في انتظار المزارع';
    } else if (status == ConsultationStatus.negotiatingTime) {
      c = Colors.purple;
      t = 'مفاوضة على الموعد';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(t,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDateText(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final d = timestamp.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  // ====================== SCHEDULE TAB ======================
  Widget _buildScheduleTab(List<DocumentSnapshot> confirmedReqs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(
            'المواعيد القادمة', Icons.event_available_rounded, Colors.green),
        confirmedReqs.isEmpty
            ? _buildEmptyState('ليس لديك أي زيارات مؤكدة قادمة')
            : const SizedBox(),
        ...confirmedReqs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = data['proposedDate'] as Timestamp?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('زيارة لـ: ${data['farmerName']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('الموعد: ${_formatDateText(date)}',
                          style: TextStyle(color: Colors.grey.shade700)),
                      Text('السعر: ${data['agreedPrice']} ج.م',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EngineerConsultationDetailsScreen(
                                  requestId: doc.id,
                                  requestData: data,
                                  status: ConsultationStatus.confirmed,
                                )));
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ====================== ARCHIVE TAB ======================
  Widget _buildArchiveTab(List<DocumentSnapshot> archivedReqs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(
            'أرشيف الاستشارات', Icons.inventory_2_rounded, Colors.teal),
        archivedReqs.isEmpty
            ? _buildEmptyState('لا يوجد استشارات مؤرشفة')
            : const SizedBox(),
        ...archivedReqs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sName = data['status'];
          final isRejected = sName == ConsultationStatus.rejected.name;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(
                  isRejected
                      ? Icons.cancel_rounded
                      : Icons.check_circle_rounded,
                  color: isRejected ? Colors.red : Colors.teal),
              title: Text(data['farmerName'] ?? ''),
              subtitle: Text(_formatDateText(data['createdAt'])),
              trailing: isRejected
                  ? const Text('مرفوضة', style: TextStyle(color: Colors.red))
                  : Text('${data['agreedPrice'] ?? 0} ج.م',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal)),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EngineerConsultationDetailsScreen(
                              requestId: doc.id,
                              requestData: data,
                              status: isRejected
                                  ? ConsultationStatus.rejected
                                  : ConsultationStatus.completed,
                            )));
              },
            ),
          );
        }),
      ],
    );
  }

  // ====================== PROFILE TAB ======================
  Widget _buildProfileTab(User user) {
    final extra = user.extraData ?? {};
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('الإعدادات الشخصية',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              _buildProfileRow('الاسم', user.fullName),
              const Divider(),
              _buildProfileRow('التخصص', extra['specialization'] ?? ''),
              const Divider(),
              _buildProfileRow(
                  'سنوات الخبرة', '${extra['experienceYears'] ?? 0} سنوات'),
              const Divider(),
              _buildProfileRow('رقم الجوال', user.phone),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit_rounded),
          label: const Text('تعديل الملف الشخصي (قريباً)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: NabaTheme.primary.withOpacity(0.1),
            foregroundColor: NabaTheme.primary,
            elevation: 0,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildProfileRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
