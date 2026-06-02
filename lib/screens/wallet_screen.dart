import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWallet();
  }

  Future<void> _initWallet() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final walletRef =
        FirebaseFirestore.instance.collection('wallets').doc(user.id);
    final doc = await walletRef.get();
    if (!doc.exists) {
      await walletRef.set({'balance': 0.0, 'userId': user.id});
    }
    if (mounted) {
      setState(() {
        _balance = ((doc.data() ?? {})['balance'] ?? 0.0).toDouble();
        _isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot> _transactionsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Stream<DocumentSnapshot> _balanceStream(String userId) {
    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .snapshots();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff < 7) return 'قبل $diff أيام';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'محفظتي', showBackButton: true),
      body: user == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Live balance card
                      StreamBuilder<DocumentSnapshot>(
                        stream: _balanceStream(user.id),
                        builder: (context, snap) {
                          double bal = _balance;
                          if (snap.hasData && snap.data!.exists) {
                            bal = ((snap.data!.data()
                                        as Map<String, dynamic>)['balance'] ??
                                    0.0)
                                .toDouble();
                          }
                          return _BalanceCard(balance: bal);
                        },
                      ),
                      const SizedBox(height: 28),
                      const Text('آخر المعاملات',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      // Live transactions
                      StreamBuilder<QuerySnapshot>(
                        stream: _transactionsStream(user.id),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined,
                                        size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text('لا توجد معاملات بعد',
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 15)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final isIncoming =
                                  (d['type'] ?? '') == 'incoming';
                              final amount = (d['amount'] ?? 0.0).toDouble();
                              final note = d['note'] ??
                                  (isIncoming ? 'استقبال' : 'تحويل');
                              final ts = d['createdAt'] as Timestamp?;
                              final date =
                                  ts != null ? _formatDate(ts.toDate()) : '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TransactionItem(
                                  title: note,
                                  date: date,
                                  amount: isIncoming
                                      ? '+${amount.toStringAsFixed(2)} ج.م'
                                      : '-${amount.toStringAsFixed(2)} ج.م',
                                  color: isIncoming ? Colors.green : Colors.red,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NabaTheme.primary, NabaTheme.primary.withOpacity(0.75)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: NabaTheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('رصيد المحفظة',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            '${balance.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('نشط',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
class _TransactionItem extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final Color color;

  const _TransactionItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NabaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              color == Colors.green
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text(date,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
