import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';

/// Admin side of invites: pay earned rewards, review invites made from the
/// inviter's own device, and set the reward amount.
class AdminReferralsTab extends StatefulWidget {
  const AdminReferralsTab({super.key});

  @override
  State<AdminReferralsTab> createState() => _AdminReferralsTabState();
}

class _AdminReferralsTabState extends State<AdminReferralsTab> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'underReview';

  static const _filters = {
    'underReview': 'مستنية الصرف',
    'flagged': 'مشتبه فيها',
    'pendingActivity': 'مستنية نشاط',
    'paid': 'اتصرفت',
  };

  Future<void> _setStatus(String id, String status) async {
    final admin = context.read<AuthProvider>().user?.id;
    await _db.collection('referrals').doc(id).update({
      'status': status,
      'reviewedBy': admin,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _editReward() async {
    final cfg = await _db.collection('app_config').doc('public').get();
    final ctrl = TextEditingController(
        text: ((cfg.data()?['referralReward'] as num?) ?? 50).toString());
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('قيمة مكافأة الدعوة'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'المبلغ (ج.م)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final v = int.tryParse(ctrl.text);
    if (save == true && v != null && v > 0) {
      await _db
          .collection('app_config')
          .doc('public')
          .set({'referralReward': v}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('المكافأة بقت $v ج.م للدعوات الجديدة')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final e in _filters.entries)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: _filter == e.key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = e.key),
                        ),
                      ),
                  ]),
                ),
              ),
              IconButton(
                tooltip: 'قيمة المكافأة',
                onPressed: _editReward,
                icon: const Icon(Icons.payments_outlined),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('referrals')
                  .where('status', isEqualTo: _filter)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('مفيش دعوات هنا',
                          style: TextStyle(color: NabaTheme.textSecondary)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(docs[i].id, docs[i].data()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String id, Map<String, dynamic> r) {
    final status = r['status'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: status == 'flagged'
                ? Colors.orange.shade300
                : NabaTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('${r['inviterName'] ?? 'مستخدم'} دعا ${r['inviteeName'] ?? 'مستخدم'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text('${r['amount'] ?? 0} ج.م',
                style: const TextStyle(
                    color: NabaTheme.primary, fontWeight: FontWeight.w800)),
          ]),
          if (r['qualifiedBy'] != null)
            Text('النشاط: ${r['qualifiedBy']}',
                style: const TextStyle(
                    color: NabaTheme.textSecondary, fontSize: 12)),
          if (status == 'flagged')
            Text('اتسجّل من نفس موبايل صاحب الكود، غالباً حساب وهمي.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _db.collection('users').doc(r['inviterId']).get(),
            builder: (context, snap) {
              final u = snap.data?.data();
              if (u == null) return const SizedBox.shrink();
              final method = u['paymentMethod'] as String?;
              final details = (u['paymentDetails'] as String?) ?? u['phone'];
              final label = switch (method) {
                'vodafoneCash' => 'فودافون كاش',
                'instaPay' => 'إنستاباي',
                'bankAccount' => 'حساب بنكي',
                _ => 'وسيلة الدفع مش محددة',
              };
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NabaTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$label: ${details ?? '-'}')),
                  if (details != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: details)),
                    ),
                ]),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (status == 'underReview')
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: NabaTheme.primary,
                      foregroundColor: Colors.white),
                  onPressed: () => _setStatus(id, 'paid'),
                  child: const Text('تم الدفع'),
                ),
              ),
            if (status == 'flagged')
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _setStatus(id, 'pendingActivity'),
                  child: const Text('اعتمد الدعوة'),
                ),
              ),
            if (status != 'paid' && status != 'rejected') ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _setStatus(id, 'rejected'),
                child: const Text('رفض'),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
