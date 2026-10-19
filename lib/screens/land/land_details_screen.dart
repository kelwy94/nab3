import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_listing.dart';
import '../../providers/auth_provider.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/land_widgets.dart';
import 'land_form_screen.dart';

class LandDetailsScreen extends StatefulWidget {
  final String listingId;

  /// Shown immediately while the live document loads.
  final LandListing? initial;

  const LandDetailsScreen({super.key, required this.listingId, this.initial});

  @override
  State<LandDetailsScreen> createState() => _LandDetailsScreenState();
}

class _LandDetailsScreenState extends State<LandDetailsScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  Future<Map<String, dynamic>?>? _ownerFuture;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadOwner(String ownerId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .get();
    return doc.data();
  }

  bool _requireAccount() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || auth.user == null) {
      GuestUtils.showGuestLoginPrompt(context);
      return false;
    }
    return true;
  }

  Future<void> _call(String phone) async {
    if (!_requireAccount()) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _whatsapp(String phone, LandListing l) async {
    if (!_requireAccount()) return;
    // Egyptian mobile numbers: 01xxxxxxxxx -> 201xxxxxxxxx
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = digits.startsWith('0') ? '2$digits' : digits;
    final text = Uri.encodeComponent(
        'السلام عليكم، أنا مهتم بالأرض المعروضة على تطبيق نبع: "${l.title}" (${l.locationLabel}).');
    await launchUrl(Uri.parse('https://wa.me/$intl?text=$text'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<LandListing?>(
        stream: LandService.listing(widget.listingId),
        initialData: widget.initial,
        builder: (context, snap) {
          final l = snap.data;
          if (l == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: snap.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator()
                    : const Text('هذا الإعلان لم يعد متاحاً'),
              ),
            );
          }
          _ownerFuture ??= _loadOwner(l.ownerId);
          final auth = context.watch<AuthProvider>();
          final isOwner = !auth.isGuest && auth.user?.id == l.ownerId;

          return Scaffold(
            backgroundColor: NabaTheme.background,
            bottomNavigationBar: isOwner ? _ownerBar(l) : _buyerBar(l),
            body: CustomScrollView(
              slivers: [
                _gallery(l),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isOwner && l.status != LandStatus.approved)
                          _ownerStatusBanner(l),
                        _priceBlock(l),
                        const SizedBox(height: 16),
                        _factsGrid(l),
                        if (l.features.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _section('المميزات', _featuresWrap(l)),
                        ],
                        if (l.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _section(
                              'الوصف',
                              Text(l.description,
                                  style: const TextStyle(
                                      height: 1.7,
                                      color: NabaTheme.textPrimary))),
                        ],
                        if (l.hasLocation) ...[
                          const SizedBox(height: 16),
                          _section('الموقع على الخريطة', _map(l)),
                        ],
                        const SizedBox(height: 16),
                        _sellerCard(l),
                        const SizedBox(height: 16),
                        _safetyTips(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------- gallery

  Widget _gallery(LandListing l) {
    final photos = l.photos.isEmpty ? <String?>[null] : l.photos;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: NabaTheme.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final img = LandImage(photos[i]);
                return GestureDetector(
                  onTap: photos[i] == null
                      ? null
                      : () => _openFullscreen(photos.cast<String>(), i),
                  child: i == 0 ? Hero(tag: 'land_${l.id}', child: img) : img,
                );
              },
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    photos.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(List<String> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: LandImage(photos[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- sections

  Widget _ownerStatusBanner(LandListing l) {
    final (color, icon, text) = switch (l.status) {
      LandStatus.rejected => (
          Colors.red,
          Icons.error_outline_rounded,
          'لم يتم قبول الإعلان${(l.rejectionReason ?? '').isNotEmpty ? ': ${l.rejectionReason}' : ''}. عدّل البيانات وأعد الإرسال.'
        ),
      LandStatus.sold => (
          Colors.blueGrey,
          Icons.handshake_rounded,
          'هذه الأرض مسجلة كمباعة ولا تظهر في السوق.'
        ),
      _ => (
          Colors.orange.shade800,
          Icons.hourglass_top_rounded,
          'إعلانك قيد المراجعة وسيظهر في السوق بعد موافقة الإدارة.'
        ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, height: 1.5))),
      ]),
    );
  }

  Widget _priceBlock(LandListing l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatLandPrice(l.price),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: NabaTheme.primary)),
            const SizedBox(width: 8),
            if (l.negotiable)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('قابل للتفاوض',
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        Text(
            '${NumberFormat('#,##0').format(l.price)} ج.م • '
            '${formatLandPrice(l.pricePerFeddan)} للفدان',
            style: const TextStyle(color: NabaTheme.textSecondary)),
        const SizedBox(height: 12),
        Text(l.title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: NabaTheme.textPrimary)),
        const SizedBox(height: 6),
        LandFact(Icons.location_on_rounded,
            [l.locationLabel, l.governorate].where((s) => s.isNotEmpty).join('، '),
            color: NabaTheme.primary),
      ],
    );
  }

  Widget _factsGrid(LandListing l) {
    final facts = [
      (Icons.straighten_rounded, 'المساحة', formatLandArea(l.areaFeddan)),
      (kWaterIcons[l.waterSource] ?? Icons.water_drop_rounded, 'المياه',
          LandOptions.waterSources[l.waterSource] ?? '-'),
      (Icons.gavel_rounded, 'الوضع القانوني',
          LandOptions.legalStatuses[l.legalStatus] ?? '-'),
      (Icons.terrain_rounded, 'نوع التربة',
          LandOptions.soilTypes[l.soilType] ?? '-'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        for (final (icon, label, value) in facts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NabaTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: NabaTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, color: NabaTheme.textSecondary)),
                      Text(value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _featuresWrap(LandListing l) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in l.features)
            Chip(
              avatar: Icon(kLandFeatureIcons[f] ?? Icons.check_rounded,
                  size: 18, color: NabaTheme.primary),
              label: Text(LandOptions.features[f] ?? f),
              backgroundColor: NabaTheme.primary.withOpacity(0.06),
              side: BorderSide.none,
            ),
        ],
      );

  Widget _map(LandListing l) {
    final point = LatLng(l.lat!, l.lng!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.nab3.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 44),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${l.lat},${l.lng}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.directions_rounded),
          label: const Text('افتح في خرائط جوجل'),
        ),
      ],
    );
  }

  Widget _sellerCard(LandListing l) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _ownerFuture,
      builder: (context, snap) {
        final owner = snap.data;
        final name = (owner?['fullName'] as String?)?.isNotEmpty == true
            ? owner!['fullName'] as String
            : l.ownerName;
        final created = DateFormat('d MMMM yyyy', 'ar').format(l.createdAt);
        return _section(
          'صاحب الأرض',
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: NabaTheme.primary.withOpacity(0.1),
                child: Text(name.isNotEmpty ? name.characters.first : '؟',
                    style: const TextStyle(
                        color: NabaTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('نُشر الإعلان $created',
                        style: const TextStyle(
                            color: NabaTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Tooltip(
                message: 'تمت مراجعة الإعلان من إدارة نبع',
                child: Icon(Icons.verified_user_rounded, color: Colors.green),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _safetyTips() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'نصيحة: عاين الأرض بنفسك، وراجع أوراق الملكية مع محامٍ قبل دفع أي مبلغ. '
                'نبع منصة عرض فقط ولا يستلم أي أموال للبيع.',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  // ----------------------------------------------------------- bottom bars

  Widget _buyerBar(LandListing l) {
    if (l.status != LandStatus.approved) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l.status == LandStatus.sold
                ? 'تم بيع هذه الأرض'
                : 'هذا الإعلان غير متاح حالياً',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: NabaTheme.textSecondary),
          ),
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _ownerFuture,
      builder: (context, snap) {
        final phone = snap.data?['phone'] as String?;
        return _bar([
          if (phone != null && phone.isNotEmpty) ...[
            _roundAction(Icons.call_rounded, Colors.blue, () => _call(phone)),
            const SizedBox(width: 10),
            _roundAction(Icons.chat_rounded, const Color(0xFF25D366),
                () => _whatsapp(phone, l)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_requireAccount()) _showInquirySheet(l);
              },
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('اطلب معاينة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]);
      },
    );
  }

  Widget _ownerBar(LandListing l) {
    return _bar([
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LandFormScreen(existing: l))),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('تعديل'),
        ),
      ),
      if (l.status == LandStatus.approved || l.status == LandStatus.sold) ...[
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: l.status == LandStatus.sold
                  ? NabaTheme.primary
                  : Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                LandService.markSold(l.id, sold: l.status != LandStatus.sold),
            icon: Icon(l.status == LandStatus.sold
                ? Icons.replay_rounded
                : Icons.handshake_rounded),
            label: Text(
                l.status == LandStatus.sold ? 'إعادة العرض' : 'تم البيع'),
          ),
        ),
      ],
    ]);
  }

  Widget _bar(List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(top: false, child: Row(children: children)),
      );

  Widget _roundAction(IconData icon, Color color, VoidCallback onTap) =>
      Material(
        color: color.withOpacity(0.1),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color),
          padding: const EdgeInsets.all(14),
        ),
      );

  // --------------------------------------------------------------- inquiry

  void _showInquirySheet(LandListing l) {
    final user = context.read<AuthProvider>().user!;
    final msgCtrl = TextEditingController(
        text: 'السلام عليكم، أنا مهتم بالأرض وأرغب في معاينتها.');
    DateTime? visitDate;
    var sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('طلب معاينة الأرض',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('هيوصل طلبك لصاحب الأرض ويتواصل معك على ${user.phone}',
                    style: const TextStyle(color: NabaTheme.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'رسالتك',
                    fillColor: NabaTheme.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 60)),
                      initialDate: now.add(const Duration(days: 1)),
                    );
                    if (picked != null) setSheet(() => visitDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(visitDate == null
                      ? 'اختار ميعاد مناسب للمعاينة (اختياري)'
                      : 'المعاينة: ${DateFormat('EEEE d MMMM', 'ar').format(visitDate!)}'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: NabaTheme.primary,
                      foregroundColor: Colors.white),
                  onPressed: sending
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setSheet(() => sending = true);
                          try {
                            await LandService.sendInquiry(
                              listing: l,
                              buyerId: user.id,
                              buyerName: user.fullName,
                              buyerPhone: user.phone,
                              message: msgCtrl.text.trim(),
                              visitDate: visitDate,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'تم إرسال طلبك ✅ صاحب الأرض هيتواصل معاك قريباً'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!ctx.mounted) return;
                            setSheet(() => sending = false);
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('تعذّر إرسال الطلب، حاول مرة أخرى'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('إرسال الطلب',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
