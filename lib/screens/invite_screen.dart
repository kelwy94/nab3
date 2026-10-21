import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

/// "ادعي أصحابك": the user's invite code, sharing, and invite history.
///
/// Invites are created and rewarded server-side (functions/index.js):
/// a friend signs up with the code, does a first real action on the app,
/// then an admin pays the reward and it shows in the wallet.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  static const _storeLink =
      'https://play.google.com/store/apps/details?id=com.nabaa.karem';
  static const _statusLabels = {
    'pendingActivity': 'مستني أول عملية',
    'underReview': 'المكافأة قيد الصرف',
    'paid': 'اتصرفت',
    'rejected': 'مرفوضة',
    'flagged': 'قيد المراجعة',
  };

  final _db = FirebaseFirestore.instance;
  String? _code;
  double _reward = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    var code = user.referralCode;
    if (code == null || code.isEmpty) {
      // Older accounts may predate invite codes; create one once.
      final r = Random.secure();
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final tail = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
      final digits = user.phone.length > 4
          ? user.phone.substring(user.phone.length - 4)
          : user.phone;
      code = '$digits-$tail';
      try {
        await _db.collection('users').doc(user.id).update({'referralCode': code});
      } catch (e) {
        debugPrint('Saving invite code failed: $e');
      }
    }
    double reward = _reward;
    try {
      final cfg = await _db.collection('app_config').doc('public').get();
      final v = (cfg.data()?['referralReward'] as num?)?.toDouble();
      if (v != null && v > 0) reward = v;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _code = code;
        _reward = reward;
      });
    }
  }

  String get _rewardText =>
      '${_reward == _reward.roundToDouble() ? _reward.toStringAsFixed(0) : _reward} ج.م';

  String get _message =>
      'أنا بستخدم تطبيق نبع للري والزراعة في الوادي الجديد: مواعيد ري البئر، '
      'بيع المحصول، سوق المعدات والأراضي.\n'
      'حمّله وسجّل بكود الدعوة بتاعي: $_code\n$_storeLink';

  Future<void> _shareWhatsapp() async {
    final ok = await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message)}'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _copy(_message, 'اتنسخت الرسالة، ابعتها لأصحابك');
  }

  void _copy(String text, String done) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.id;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ادعي أصحابك'),
          leading: const NabaBackButton(),
        ),
        body: _code == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _codeCard(),
                  const SizedBox(height: 16),
                  _howItWorks(),
                  const SizedBox(height: 20),
                  const Text('دعواتك',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (uid != null) _history(uid),
                ],
              ),
      ),
    );
  }

  Widget _codeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabaTheme.divider),
      ),
      child: Column(
        children: [
          Text('خد $_rewardText عن كل صاحب يستخدم نبع',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('ابعتله كود الدعوة، ولما يسجّل بيه ويعمل أول عملية تاخد مكافأتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NabaTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _copy(_code!, 'اتنسخ الكود'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EBE5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_code!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          color: Color(0xFF265B33))),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded, color: Color(0xFF265B33)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _shareWhatsapp,
              icon: const Icon(Icons.chat_rounded),
              label: const Text('ابعت الدعوة على واتساب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          TextButton(
            onPressed: () => _copy(_message, 'اتنسخت رسالة الدعوة'),
            child: const Text('نسخ الرسالة'),
          ),
        ],
      ),
    );
  }

  Widget _howItWorks() {
    const steps = [
      (Icons.send_rounded, 'ابعت الكود لصاحبك'),
      (Icons.person_add_alt_1_rounded, 'يسجّل بالكود في خانة «كود الدعوة»'),
      (Icons.check_circle_outline_rounded,
          'يعمل أول عملية: طلب من السوق، أو بيع محصول، أو رية على دور البئر'),
      (Icons.account_balance_wallet_outlined,
          'الإدارة تصرفلك المكافأة على وسيلة الدفع بتاعتك'),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFE2EBE5),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Color(0xFF265B33), fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Icon(steps[i].$1, size: 18, color: NabaTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(steps[i].$2)),
            ]),
          ),
      ],
    );
  }

  Widget _history(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('referrals')
          .where('inviterId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text('لسه ما حدش سجّل بكودك.',
              style: TextStyle(color: NabaTheme.textSecondary));
        }
        final paid = docs
            .where((d) => d.data()['status'] == 'paid')
            .fold<double>(0, (a, d) => a + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${docs.length} سجّلوا بكودك • اتصرفلك ${paid.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                    color: NabaTheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NabaTheme.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < docs.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: NabaTheme.divider),
                    ListTile(
                      title: Text(docs[i].data()['inviteeName'] ?? 'مستخدم'),
                      trailing: Text(
                        _statusLabels[docs[i].data()['status']] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: docs[i].data()['status'] == 'paid'
                              ? NabaTheme.primary
                              : NabaTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
