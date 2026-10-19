import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_listing.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import '../../widgets/land_widgets.dart';
import 'land_details_screen.dart';

/// Admin moderation for the land market: approve or reject new listings
/// after checking the private ownership documents, and unpublish live ones.
class AdminLandReviewTab extends StatefulWidget {
  const AdminLandReviewTab({super.key});

  @override
  State<AdminLandReviewTab> createState() => _AdminLandReviewTabState();
}

class _AdminLandReviewTabState extends State<AdminLandReviewTab> {
  bool _showLive = false;

  Stream<List<LandListing>> get _stream => _showLive
      ? LandService.approvedListings()
      : LandService.pendingListings();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.hourglass_top_rounded),
                    label: Text('بانتظار المراجعة')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public_rounded),
                    label: Text('المعروضة')),
              ],
              selected: {_showLive},
              onSelectionChanged: (s) => setState(() => _showLive = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LandListing>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _showLive
                          ? 'لا توجد أراضي معروضة'
                          : 'لا توجد إعلانات بانتظار المراجعة 👌',
                      style: const TextStyle(color: NabaTheme.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _ReviewCard(listing: list[i], live: _showLive),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final LandListing listing;
  final bool live;
  const _ReviewCard({required this.listing, required this.live});

  Future<void> _reject(BuildContext context) async {
    final ctrl = TextEditingController();
    const quickReasons = [
      'الصور غير واضحة',
      'أوراق الملكية ناقصة',
      'السعر أو المساحة غير منطقيين',
      'بيانات الموقع غير صحيحة',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text(live ? 'إيقاف الإعلان' : 'رفض الإعلان'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in quickReasons)
                      ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setD(() => ctrl.text = r),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'السبب (هيوصل لصاحب الإعلان)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () {
                  final r = ctrl.text.trim();
                  if (r.isNotEmpty) Navigator.pop(ctx, r);
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;
    await LandService.review(listing, approve: false, reason: reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إبلاغ صاحب الإعلان')));
    }
  }

  Future<void> _approve(BuildContext context) async {
    await LandService.review(listing, approve: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم نشر الإعلان ✅'), backgroundColor: Colors.green));
    }
  }

  void _showDocs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: FutureBuilder<List<String>>(
            future: LandService.ownershipDocs(listing.id),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!;
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('أوراق الملكية',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text('صاحب الإعلان ما رفعش أوراق ملكية'))
                        : PageView(
                            children: [
                              for (final d in docs)
                                InteractiveViewer(
                                  child: LandImage(d, fit: BoxFit.contain),
                                ),
                            ],
                          ),
                  ),
                  if (docs.length > 1)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('اسحب لعرض باقي الأوراق',
                          style: TextStyle(color: NabaTheme.textSecondary)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: NabaTheme.premiumShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: l.photos.isEmpty
                ? const LandImage(null)
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: l.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 2),
                    itemBuilder: (_, i) => SizedBox(
                        width: 180, child: LandImage(l.photos[i])),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '${formatLandPrice(l.price)} • ${formatLandArea(l.areaFeddan)} • ${formatLandPrice(l.pricePerFeddan)}/فدان',
                    style: const TextStyle(
                        color: NabaTheme.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    LandFact(Icons.location_on_rounded, l.locationLabel),
                    LandFact(Icons.gavel_rounded,
                        LandOptions.legalStatuses[l.legalStatus] ?? ''),
                    LandFact(kWaterIcons[l.waterSource] ?? Icons.water,
                        LandOptions.waterSources[l.waterSource] ?? ''),
                    if (l.hasLocation)
                      const LandFact(Icons.map_rounded, 'عليه موقع',
                          color: Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                _OwnerLine(ownerId: l.ownerId, fallbackName: l.ownerName),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDocs(context),
                        icon: const Icon(Icons.description_rounded, size: 18),
                        label: const Text('الأوراق'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => LandDetailsScreen(
                                    listingId: l.id, initial: l))),
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('معاينة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _reject(context),
                        icon: const Icon(Icons.block_rounded),
                        label: Text(live ? 'إيقاف' : 'رفض'),
                      ),
                    ),
                    if (!live)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _approve(context),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('موافقة ونشر',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
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

class _OwnerLine extends StatelessWidget {
  final String ownerId;
  final String fallbackName;
  const _OwnerLine({required this.ownerId, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final name = d?['fullName'] ?? fallbackName;
        final phone = d?['phone'] as String?;
        return Row(
          children: [
            const Icon(Icons.person_rounded,
                size: 18, color: NabaTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
                child: Text('$name${phone != null ? ' • $phone' : ''}',
                    style: const TextStyle(fontSize: 13))),
            if (phone != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.call_rounded, color: NabaTheme.primary),
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              ),
          ],
        );
      },
    );
  }
}
