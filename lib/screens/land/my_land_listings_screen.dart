import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_listing.dart';
import '../../providers/auth_provider.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import '../../widgets/land_widgets.dart';
import 'land_details_screen.dart';
import 'land_form_screen.dart';

/// The owner's side of the land market: their listings, viewing requests
/// they received, and requests they sent as a buyer.
class MyLandListingsScreen extends StatelessWidget {
  const MyLandListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user!.id;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: NabaTheme.background,
          appBar: AppBar(
            title: const Text('أراضيّ'),
            backgroundColor: NabaTheme.primary,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              indicatorColor: NabaTheme.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'إعلاناتي'),
                Tab(text: 'طلبات وصلتلي'),
                Tab(text: 'طلبات بعتها'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: NabaTheme.primary,
            foregroundColor: Colors.white,
            tooltip: 'إعلان جديد',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LandFormScreen())),
            child: const Icon(Icons.add_rounded),
          ),
          body: TabBarView(
            children: [
              _MyListingsTab(uid: uid),
              _InquiriesTab(
                  stream: LandService.inquiriesForOwner(uid), asOwner: true),
              _InquiriesTab(
                  stream: LandService.inquiriesByBuyer(uid), asOwner: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListingsTab extends StatelessWidget {
  final String uid;
  const _MyListingsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LandListing>>(
      stream: LandService.myListings(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const _Empty(
            icon: Icons.landscape_rounded,
            text: 'لسه ما عرضتش أي أرض',
            hint: 'اضغط + علشان تعرض أرضك في دقيقتين',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _MyListingTile(listing: list[i]),
        );
      },
    );
  }
}

class _MyListingTile extends StatelessWidget {
  final LandListing listing;
  const _MyListingTile({required this.listing});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإعلان؟'),
          content: Text('هيتم حذف "${listing.title}" نهائياً.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await LandService.deleteListing(listing.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    LandDetailsScreen(listingId: l.id, initial: l))),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 100,
                  child: LandImage(l.photos.isNotEmpty ? l.photos.first : null),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(l.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            LandStatusBadge(l.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(formatLandPrice(l.price),
                            style: const TextStyle(
                                color: NabaTheme.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        LandFact(Icons.straighten_rounded,
                            '${formatLandArea(l.areaFeddan)} • ${l.locationLabel}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (l.status == LandStatus.rejected &&
                (l.rejectionReason ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('سبب الرفض: ${l.rejectionReason}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
            const Divider(height: 1),
            Row(
              children: [
                _action(Icons.edit_rounded, 'تعديل', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LandFormScreen(existing: l)));
                }),
                if (l.status == LandStatus.approved)
                  _action(Icons.handshake_rounded, 'تم البيع',
                      () => LandService.markSold(l.id)),
                if (l.status == LandStatus.sold)
                  _action(Icons.replay_rounded, 'إعادة العرض',
                      () => LandService.markSold(l.id, sold: false)),
                _action(Icons.delete_outline_rounded, 'حذف',
                    () => _confirmDelete(context),
                    color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap,
          {Color color = NabaTheme.textSecondary}) =>
      Expanded(
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: color),
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      );
}

class _InquiriesTab extends StatelessWidget {
  final Stream<List<LandInquiry>> stream;
  final bool asOwner;
  const _InquiriesTab({required this.stream, required this.asOwner});

  static const _statusLabels = {
    'new': 'جديد',
    'contacted': 'تم التواصل',
    'closed': 'مغلق',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LandInquiry>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return _Empty(
            icon: Icons.mark_email_unread_rounded,
            text: asOwner ? 'مفيش طلبات معاينة لسه' : 'ما بعتش طلبات معاينة',
            hint: asOwner
                ? 'أول ما حد يهتم بأرضك هتلاقي طلبه هنا'
                : 'تصفح سوق الأراضي واطلب معاينة لأي أرض تعجبك',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _inquiryCard(context, list[i]),
        );
      },
    );
  }

  Widget _inquiryCard(BuildContext context, LandInquiry q) {
    final isNew = q.status == 'new';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isNew && asOwner
            ? Border.all(color: NabaTheme.accent, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: NabaTheme.primary.withOpacity(0.1),
                child: Icon(asOwner ? Icons.person_rounded : Icons.landscape,
                    color: NabaTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asOwner ? q.buyerName : q.listingTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      asOwner
                          ? 'على: ${q.listingTitle}'
                          : DateFormat('d MMMM • jm', 'ar').format(q.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: NabaTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(_statusLabels[q.status] ?? q.status,
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: isNew
                    ? NabaTheme.accent.withOpacity(0.2)
                    : Colors.grey.shade100,
                side: BorderSide.none,
              ),
            ],
          ),
          if (q.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(q.message, style: const TextStyle(height: 1.5)),
          ],
          if (q.visitDate != null) ...[
            const SizedBox(height: 8),
            LandFact(Icons.event_rounded,
                'معاد المعاينة المقترح: ${DateFormat('EEEE d MMMM', 'ar').format(q.visitDate!)}',
                color: NabaTheme.primary),
          ],
          if (asOwner) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      launchUrl(Uri.parse('tel:${q.buyerPhone}'));
                      if (isNew) {
                        LandService.setInquiryStatus(q.id, 'contacted');
                      }
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(q.buyerPhone),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'تغيير الحالة',
                  onSelected: (s) => LandService.setInquiryStatus(q.id, s),
                  itemBuilder: (_) => _statusLabels.entries
                      .map((e) =>
                          PopupMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final String hint;
  const _Empty({required this.icon, required this.text, required this.hint});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: NabaTheme.primary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(text,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NabaTheme.textSecondary)),
            ],
          ),
        ),
      );
}
