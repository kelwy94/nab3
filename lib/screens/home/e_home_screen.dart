import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../models/types.dart';
import '../../providers/auth_provider.dart';
import '../../providers/well_provider.dart';
import '../../services/well_turn_service.dart';
import '../../theme.dart';
import '../consultation_market_screen.dart';
import '../irrigation/well_turn_screen.dart';
import '../land/land_market_screen.dart';
import '../request_equipment_screen.dart';
import '../request_worker_screen.dart';
import '../sell_crop_screen.dart';

/// Home tab ("ذهب الواحة" design): date-palm hero, live irrigation turn,
/// quick services and the markets.
class EHomeScreen extends StatelessWidget {
  /// Switches the dashboard's bottom tab (1 = irrigation, 2 = market).
  final ValueChanged<int> onSwitchTab;
  const EHomeScreen({super.key, required this.onSwitchTab});

  static const _heroHeight = 330.0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final wells = context
        .watch<WellProvider>()
        .myWells
        .where((w) => w.status == WellStatus.approved)
        .toList();
    final firstName = (user?.fullName ?? '').trim().split(' ').first;
    final greeting = DateTime.now().hour < 12 ? 'صباح الخير' : 'مساء الخير';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: NabaTheme.background,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _hero(
                      context,
                      '$greeting${firstName.isEmpty ? '' : ' يا $firstName'}',
                      user?.id),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: -52,
                    child: wells.isEmpty
                        ? _noWellCard()
                        : _TurnCard(well: wells.first, uid: user?.id ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 70),
              _sectionTitle('محتاج إيه النهارده؟'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _service(context, 'عامل', 'assets/images/icons/worker.png',
                        const RequestWorkerScreen()),
                    const SizedBox(width: 10),
                    _service(context, 'معدة', 'assets/images/icons/tractor.png',
                        const RequestEquipmentScreen()),
                    const SizedBox(width: 10),
                    _service(
                        context,
                        'مهندس',
                        'assets/images/icons/consultations.png',
                        const ConsultationMarketScreen()),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle('الأسواق'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _landsCard(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _marketCard(
                        title: 'مستلزمات ومعدات',
                        subtitle: 'جديد ومستعمل',
                        icon: 'assets/images/icons/market_v2.png',
                        onTap: () => onSwitchTab(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ hero

  Widget _hero(BuildContext context, String greeting, String? uid) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/dates_bg.png',
              fit: BoxFit.cover, alignment: const Alignment(0, -0.3)),
          // Darkens the top and bottom so the text stays readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.45, 1],
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xC70A1410),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          Image.asset('assets/logo.png', width: 40, height: 40),
                    ),
                    const SizedBox(width: 10),
                    Text('نبع',
                        style: NabaTheme.display(22, color: Colors.white)),
                    const Spacer(),
                    if (uid != null) _NotificationsButton(uid: uid),
                  ]),
                  const Spacer(),
                  Text(greeting,
                      style: NabaTheme.display(28,
                          color: Colors.white, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('عندك محصول للبيع؟',
                        style:
                            TextStyle(color: Color(0xFFF3EBDD), fontSize: 14)),
                    const SizedBox(width: 10),
                    Material(
                      color: NabaTheme.accent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SellCropScreen())),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Text('اعرض محصولك',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: NabaTheme.textPrimary)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noWellCard() => _FloatingCard(
        onTap: () => onSwitchTab(1),
        child: Row(children: [
          Image.asset('assets/images/icons/well.png', width: 50, height: 50),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجّل بئرك أو انضم لبئر',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('واعرف دورك في الري وتنبيه قبله',
                    style: TextStyle(
                        color: NabaTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded,
              color: NabaTheme.textSecondary),
        ]),
      );

  // -------------------------------------------------------------- sections

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(text, style: NabaTheme.display(18, weight: 700)),
      );

  Widget _service(
      BuildContext context, String label, String icon, Widget screen) {
    return Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: NabaTheme.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => screen)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Image.asset(icon, width: 44, height: 44),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _landsCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('land_listings')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snap) {
        final n = snap.data?.size ?? 0;
        return Material(
          color: NabaTheme.primary,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LandMarketScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أراضي',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(n > 0 ? '$n معروضة' : 'اشتري أو بيع',
                          style: const TextStyle(
                              color: Color(0xFFD5E8D9), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset('assets/images/icons/lands_v2.png'),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _marketCard({
    required String title,
    required String subtitle,
    required String icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NabaTheme.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: NabaTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Image.asset(icon, width: 34, height: 34),
          ]),
        ),
      ),
    );
  }
}

/// White card that floats over the bottom edge of the hero photo.
class _FloatingCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _FloatingCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F1B1F1D), blurRadius: 34, offset: Offset(0, 14)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

/// Live summary of the well rotation: who irrigates now and when it's me.
class _TurnCard extends StatelessWidget {
  final Well well;
  final String uid;
  const _TurnCard({required this.well, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WellTurn?>(
      stream: WellTurnService.watch(well.id),
      builder: (context, snap) {
        final t = snap.data;
        String label;
        String value;
        String detail;
        double? progress;

        if (t == null || t.isEmpty) {
          label = 'دور الري';
          value = well.wellName;
          detail = well.adminUserId == uid
              ? 'رتّب دور الشركاء على البئر'
              : 'صاحب البئر لسه ما رتبش الدور';
        } else if (t.currentUserId == uid) {
          label = t.state == WellTurn.running ? 'دورك شغال' : 'دورك جه';
          value = t.state == WellTurn.running
              ? 'فاضل ${formatTurnDuration(t.remainingMinutes())}'
              : (t.state == WellTurn.paused ? 'البئر واقف' : 'افتح المية');
          detail =
              '${well.wellName} · ${t.state == WellTurn.waiting ? 'دوس «بدأت» لما تبدأ' : (t.pauseReason ?? 'دوس «خلصت» لما تخلص')}';
          final allotted = t.hoursOf(uid) * 60;
          if (t.state != WellTurn.waiting && allotted > 0) {
            progress = (t.elapsedMinutes() / allotted).clamp(0.0, 1.0);
          }
        } else {
          final mine = t.upcoming().where((e) => e.uid == uid).firstOrNull;
          label = 'دورك في الري بعد';
          value = mine == null
              ? '-'
              : (t.state == WellTurn.paused
                  ? 'البئر واقف'
                  : formatTurnDuration(mine.startsInMinutes));
          final now = t.state == WellTurn.running
              ? 'بيروي دلوقتي: ${t.nameOf(t.currentUserId)}'
              : (t.state == WellTurn.paused
                  ? (t.pauseReason ?? 'البئر واقف')
                  : 'الدور على: ${t.nameOf(t.currentUserId)}');
          detail = '${well.wellName} · $now';
          if (mine != null && t.state != WellTurn.paused) {
            final at =
                DateTime.now().add(Duration(minutes: mine.startsInMinutes));
            detail += ' · حوالي ${DateFormat('h:mm a', 'ar').format(at)}';
          }
          final allotted = t.hoursOf(t.currentUserId) * 60;
          if (t.state == WellTurn.running && allotted > 0) {
            progress = (t.elapsedMinutes() / allotted).clamp(0.0, 1.0);
          }
        }

        return _FloatingCard(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => WellTurnScreen(well: well))),
          child: Row(children: [
            Image.asset('assets/images/icons/well.png', width: 54, height: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: NabaTheme.textSecondary, fontSize: 14)),
                      Text(value,
                          style:
                              NabaTheme.display(19, color: NabaTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: NabaTheme.textSecondary, fontSize: 13)),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: NabaTheme.primaryTint,
                        color: NabaTheme.brand,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Bell with unread count; opens the user's in-app notifications.
class _NotificationsButton extends StatelessWidget {
  final String uid;
  const _NotificationsButton({required this.uid});

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ref.where('isRead', isEqualTo: false).snapshots(),
      builder: (context, snap) {
        final unread = snap.data?.size ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'الإشعارات',
                onPressed: () => _open(context),
                icon: const Icon(Icons.notifications_none_rounded,
                    color: NabaTheme.textPrimary),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: NabaTheme.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text('$unread',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ref
                .orderBy('createdAt', descending: true)
                .limit(30)
                .snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? const [];
              // Opening the list marks everything as read.
              for (final d in docs) {
                if (d.data()['isRead'] == false) {
                  d.reference.update({'isRead': true});
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text('الإشعارات',
                        style: NabaTheme.display(20, weight: 700)),
                  ),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text('مفيش إشعارات لسه',
                                style:
                                    TextStyle(color: NabaTheme.textSecondary)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: NabaTheme.divider),
                            itemBuilder: (_, i) {
                              final n = docs[i].data();
                              final at =
                                  (n['createdAt'] as Timestamp?)?.toDate();
                              return ListTile(
                                title: Text(n['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  [
                                    if ((n['body'] ?? '').toString().isNotEmpty)
                                      n['body'],
                                    if (at != null)
                                      DateFormat('d MMMM • h:mm a', 'ar')
                                          .format(at),
                                  ].join('\n'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
