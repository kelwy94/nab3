import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/delivery_data.dart';
import '../../models/land_listing.dart';
import '../../providers/auth_provider.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/land_widgets.dart';
import '../../widgets/naba_widgets.dart';
import 'land_details_screen.dart';
import 'land_form_screen.dart';
import 'my_land_listings_screen.dart';

enum _LandSort { newest, priceLow, priceHigh, perFeddanLow, areaLarge }

const _sortLabels = {
  _LandSort.newest: 'الأحدث',
  _LandSort.priceLow: 'السعر: الأقل',
  _LandSort.priceHigh: 'السعر: الأعلى',
  _LandSort.perFeddanLow: 'سعر الفدان: الأقل',
  _LandSort.areaLarge: 'المساحة: الأكبر',
};

class _LandFilters {
  String? district;
  String? waterSource;
  bool registeredOnly = false;
  bool savedOnly = false;
  RangeValues? price;
  RangeValues? area;

  int get activeCount => [
        waterSource != null,
        registeredOnly,
        savedOnly,
        price != null,
        area != null,
      ].where((b) => b).length;
}

/// Browse approved land listings. Guests can browse; listing a land, saving
/// favorites and contacting sellers require an account.
class LandMarketScreen extends StatefulWidget {
  /// When embedded as a dashboard tab there's no back button.
  final bool embedded;
  const LandMarketScreen({super.key, this.embedded = false});

  @override
  State<LandMarketScreen> createState() => _LandMarketScreenState();
}

class _LandMarketScreenState extends State<LandMarketScreen> {
  final _searchCtrl = TextEditingController();
  final _filters = _LandFilters();
  _LandSort _sort = _LandSort.newest;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LandListing> _apply(List<LandListing> all, Set<String> saved) {
    final q = _query.trim();
    final list = all.where((l) {
      if (q.isNotEmpty &&
          !'${l.title} ${l.village} ${l.district} ${l.description}'
              .contains(q)) {
        return false;
      }
      if (_filters.district != null && l.district != _filters.district) {
        return false;
      }
      if (_filters.waterSource != null &&
          l.waterSource != _filters.waterSource) {
        return false;
      }
      if (_filters.registeredOnly && l.legalStatus != 'registered') {
        return false;
      }
      if (_filters.savedOnly && !saved.contains(l.id)) return false;
      final p = _filters.price;
      if (p != null && (l.price < p.start || l.price > p.end)) return false;
      final a = _filters.area;
      if (a != null && (l.areaFeddan < a.start || l.areaFeddan > a.end)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _LandSort.newest:
        break; // already newest-first from the service
      case _LandSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _LandSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _LandSort.perFeddanLow:
        list.sort((a, b) => a.pricePerFeddan.compareTo(b.pricePerFeddan));
      case _LandSort.areaLarge:
        list.sort((a, b) => b.areaFeddan.compareTo(a.areaFeddan));
    }
    return list;
  }

  void _openForm() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || auth.user == null) {
      GuestUtils.showGuestLoginPrompt(context);
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LandFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.isGuest ? null : auth.user?.id;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabaTheme.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openForm,
          backgroundColor: NabaTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('اعرض أرضك',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: StreamBuilder<Set<String>>(
          stream: uid != null ? LandService.savedIds(uid) : Stream.value({}),
          builder: (context, savedSnap) {
            final saved = savedSnap.data ?? const <String>{};
            return StreamBuilder<List<LandListing>>(
              stream: LandService.approvedListings(),
              builder: (context, snap) {
                final all = snap.data ?? const <LandListing>[];
                final shown = _apply(all, saved);
                return CustomScrollView(
                  slivers: [
                    _buildHeader(uid, all),
                    SliverToBoxAdapter(child: _buildFilterBar(uid != null)),
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData)
                      const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()))
                    else if (snap.hasError)
                      SliverFillRemaining(
                          child: _empty(Icons.wifi_off_rounded,
                              'تعذّر تحميل الأراضي', 'تحقق من الاتصال وحاول مرة أخرى'))
                    else if (shown.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: all.isEmpty
                            ? _empty(Icons.landscape_rounded,
                                'لا توجد أراضي معروضة حالياً',
                                'كن أول من يعرض أرضه في سوق نبع')
                            : _empty(Icons.filter_alt_off_rounded,
                                'لا توجد نتائج مطابقة',
                                'جرّب تغيير الفلاتر أو كلمة البحث'),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        sliver: SliverList.builder(
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final l = shown[i];
                            return LandCard(
                              listing: l,
                              saved: saved.contains(l.id),
                              onToggleSave: uid == null
                                  ? null
                                  : () => LandService.toggleSaved(
                                      uid, l.id, !saved.contains(l.id)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        LandDetailsScreen(listingId: l.id, initial: l)),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String? uid, List<LandListing> all) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 150,
      automaticallyImplyLeading: false,
      leading: widget.embedded ? null : const NabaBackButton(),
      title: const Text('سوق الأراضي'),
      actions: [
        if (uid != null)
          IconButton(
            tooltip: 'إعلاناتي',
            icon: const Icon(Icons.dashboard_customize_rounded),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MyLandListingsScreen())),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                all.isEmpty
                    ? 'اشتري أو بيع أرضك بأمان'
                    : '${all.length} أرض معروضة • كل الإعلانات مراجَعة',
                style: const TextStyle(
                    color: NabaTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث بالقرية أو المركز...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  fillColor: NabaTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool canSave) {
    final count = _filters.activeCount;
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          ActionChip(
            avatar: Icon(Icons.tune_rounded,
                size: 18, color: count > 0 ? Colors.white : NabaTheme.primary),
            label: Text(count > 0 ? 'فلاتر ($count)' : 'فلاتر'),
            labelStyle: TextStyle(
                color: count > 0 ? Colors.white : NabaTheme.primary,
                fontWeight: FontWeight.bold),
            backgroundColor: count > 0 ? NabaTheme.primary : Colors.white,
            side: const BorderSide(color: NabaTheme.primary),
            onPressed: () => _showFilterSheet(canSave),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_LandSort>(
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => _sortLabels.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            child: Chip(
              avatar: const Icon(Icons.sort_rounded, size: 18),
              label: Text(_sortLabels[_sort]!),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          _districtChip(null, 'كل المراكز'),
          for (final d in kDistricts) _districtChip(d, d),
        ],
      ),
    );
  }

  Widget _districtChip(String? value, String label) {
    final selected = _filters.district == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filters.district = value),
        showCheckmark: false,
        selectedColor: const Color(0xFFE2EBE5),
        side: BorderSide(
            color: selected ? Colors.transparent : NabaTheme.divider),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF265B33) : NabaTheme.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
      ),
    );
  }

  static const _maxPrice = 20000000.0;
  static const _maxArea = 200.0;

  void _showFilterSheet(bool canSave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        var price = _filters.price ?? const RangeValues(0, _maxPrice);
        var area = _filters.area ?? const RangeValues(0, _maxArea);
        var water = _filters.waterSource;
        var registered = _filters.registeredOnly;
        var savedOnly = _filters.savedOnly;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (ctx, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('تصفية الأراضي',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _sheetLabel('السعر',
                      '${formatLandPrice(price.start)} - ${price.end >= _maxPrice ? 'بلا حد' : formatLandPrice(price.end)}'),
                  RangeSlider(
                    values: price,
                    min: 0,
                    max: _maxPrice,
                    divisions: 80,
                    activeColor: NabaTheme.primary,
                    onChanged: (v) => setSheet(() => price = v),
                  ),
                  _sheetLabel('المساحة',
                      '${area.start.round()} - ${area.end >= _maxArea ? 'بلا حد' : '${area.end.round()}'} فدان'),
                  RangeSlider(
                    values: area,
                    min: 0,
                    max: _maxArea,
                    divisions: 100,
                    activeColor: NabaTheme.primary,
                    onChanged: (v) => setSheet(() => area = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('مصدر المياه',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in LandOptions.waterSources.entries)
                        ChoiceChip(
                          avatar: Icon(kWaterIcons[e.key], size: 16),
                          label: Text(e.value),
                          selected: water == e.key,
                          selectedColor: NabaTheme.primary.withOpacity(0.15),
                          onSelected: (sel) =>
                              setSheet(() => water = sel ? e.key : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: registered,
                    activeColor: NabaTheme.primary,
                    title: const Text('أراضي بعقد مسجل فقط'),
                    onChanged: (v) => setSheet(() => registered = v),
                  ),
                  if (canSave)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: savedOnly,
                      activeColor: NabaTheme.primary,
                      title: const Text('المحفوظة فقط'),
                      onChanged: (v) => setSheet(() => savedOnly = v),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filters
                                ..price = null
                                ..area = null
                                ..waterSource = null
                                ..registeredOnly = false
                                ..savedOnly = false;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('مسح الكل'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: NabaTheme.primary,
                              foregroundColor: Colors.white),
                          onPressed: () {
                            setState(() {
                              _filters
                                ..price = (price.start <= 0 &&
                                        price.end >= _maxPrice)
                                    ? null
                                    : RangeValues(
                                        price.start,
                                        price.end >= _maxPrice
                                            ? double.infinity
                                            : price.end)
                                ..area = (area.start <= 0 && area.end >= _maxArea)
                                    ? null
                                    : RangeValues(
                                        area.start,
                                        area.end >= _maxArea
                                            ? double.infinity
                                            : area.end)
                                ..waterSource = water
                                ..registeredOnly = registered
                                ..savedOnly = savedOnly;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('عرض النتائج',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _sheetLabel(String title, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(
                  color: NabaTheme.primary, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _empty(IconData icon, String title, String subtitle) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NabaTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: NabaTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NabaTheme.textSecondary)),
            ],
          ),
        ),
      );
}
