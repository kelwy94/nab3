import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../models/types.dart';
import '../../providers/auth_provider.dart';
import '../../services/well_turn_service.dart';
import '../../theme.dart';
import '../../widgets/naba_widgets.dart';
import 'well_turn_setup_screen.dart';

/// Live irrigation rotation for one well: who is irrigating now, who is
/// next and when, plus the actual-hours log and bill splitting.
class WellTurnScreen extends StatefulWidget {
  final Well well;
  const WellTurnScreen({super.key, required this.well});

  @override
  State<WellTurnScreen> createState() => _WellTurnScreenState();
}

class _WellTurnScreenState extends State<WellTurnScreen> {
  Timer? _tick;
  bool _busy = false;

  static const _pauseReasons = [
    'الكهرباء قطعت',
    'السولار خلص',
    'عطل في الطلمبة',
    'سبب تاني',
  ];

  @override
  void initState() {
    super.initState();
    // Refresh countdowns while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _uid => context.read<AuthProvider>().user?.id ?? '';
  bool get _isManager => widget.well.adminUserId == _uid;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      if (done != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      debugPrint('Turn action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّر التحديث، تأكد من الإنترنت وحاول تاني'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSetup(WellTurn? turn) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => WellTurnSetupScreen(well: widget.well, existing: turn)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<WellTurn?>(
        stream: WellTurnService.watch(widget.well.id),
        builder: (context, snap) {
          final turn = snap.data;
          return Scaffold(
            appBar: AppBar(
              title: Text('دور الري • ${widget.well.wellName}'),
              leading: const NabaBackButton(),
              actions: [
                if (_isManager && turn != null)
                  IconButton(
                    tooltip: 'ترتيب الدور والساعات',
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => _openSetup(turn),
                  ),
              ],
            ),
            body: () {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (turn == null || turn.isEmpty) return _notSetUp();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _statusCard(turn),
                  const SizedBox(height: 12),
                  _actions(turn),
                  if (turn.currentUserId != _uid &&
                      turn.memberIds.contains(_uid)) ...[
                    const SizedBox(height: 12),
                    _myNextTurn(turn),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('ترتيب الدور'),
                  _queue(turn),
                  const SizedBox(height: 20),
                  _sectionTitle('آخر الريّات'),
                  _log(turn),
                  const SizedBox(height: 20),
                  _billsSection(turn),
                ],
              );
            }(),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- not set up

  Widget _notSetUp() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EBE5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset('assets/images/icons/well.png'),
            ),
            const SizedBox(height: 16),
            Text(
              _isManager ? 'جهّز دور الري للبئر' : 'دور الري لسه ما اتجهزش',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _isManager
                  ? 'رتّب الشركاء وحدد ساعات كل واحد، وكل شريك هيعرف دوره وهيوصله تنبيه قبله.'
                  : 'صاحب البئر لسه ما رتبش الدور. أول ما يرتبه هتلاقي ميعادك هنا.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: NabaTheme.textSecondary, height: 1.6),
            ),
            if (_isManager) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    foregroundColor: Colors.white),
                onPressed: () => _openSetup(null),
                icon: const Icon(Icons.format_list_numbered_rtl_rounded),
                label: const Text('ترتيب الدور',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- status

  Widget _statusCard(WellTurn t) {
    final current = t.currentUserId;
    final me = current == _uid;
    final who = me ? 'أنت' : t.nameOf(current);
    final allotted = (t.hoursOf(current) * 60).round();

    late final Color color;
    late final IconData icon;
    late final String label;
    late final String headline;
    late final String detail;
    double? progress;

    switch (t.state) {
      case WellTurn.running:
        color = NabaTheme.primary;
        icon = Icons.water_drop_rounded;
        label = 'شغال دلوقتي';
        headline = me ? 'دورك شغال' : 'بيروي دلوقتي: $who';
        final elapsed = t.elapsedMinutes();
        progress = allotted == 0 ? 0 : (elapsed / allotted).clamp(0.0, 1.0);
        detail = t.remainingMinutes() > 0
            ? 'فاضل ${formatTurnDuration(t.remainingMinutes())} من ${formatTurnHours(t.hoursOf(current))}'
            : 'خلّص حصته (${formatTurnHours(t.hoursOf(current))})';
      case WellTurn.paused:
        color = Colors.orange.shade800;
        icon = Icons.power_off_rounded;
        label = 'البئر واقف';
        headline = t.pauseReason ?? 'البئر واقف';
        final since = t.pausedAt == null
            ? null
            : DateTime.now().difference(t.pausedAt!).inMinutes;
        detail = 'دور $who متوقف'
            '${since != null ? ' من ${formatTurnDuration(since)}' : ''}'
            '، وكل المواعيد هتتأخر لحد ما يرجع.';
      default:
        color = const Color(0xFF265B33);
        icon = Icons.hourglass_top_rounded;
        label = 'مستني يبدأ';
        headline = me ? 'دورك جه' : 'الدور على: $who';
        detail = me
            ? 'افتح المية ودوس «بدأت» علشان الوقت يتحسب.'
            : 'حصته ${formatTurnHours(t.hoursOf(current))}، ولسه ما بدأش.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('الدورة ${t.cycle + 1}',
                style: const TextStyle(
                    color: NabaTheme.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Text(headline,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: NabaTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(detail,
              style: const TextStyle(
                  color: NabaTheme.textSecondary, height: 1.5)),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2EBE5),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Widget _actions(WellTurn t) {
    final canAct = t.currentUserId == _uid || _isManager;
    if (!canAct) return const SizedBox.shrink();

    final primary = ElevatedButton.styleFrom(
      backgroundColor: NabaTheme.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
    final buttons = <Widget>[];

    switch (t.state) {
      case WellTurn.waiting:
        buttons.add(Expanded(
          child: ElevatedButton.icon(
            style: primary,
            onPressed: _busy
                ? null
                : () => _run(() => WellTurnService.start(t),
                    done: 'بدأ الحساب، بالتوفيق'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('بدأت الري',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ));
      case WellTurn.running:
        buttons.addAll([
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: primary,
              onPressed: _busy ? null : () => _confirmFinish(t),
              icon: const Icon(Icons.check_rounded),
              label: const Text('خلصت',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade800),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _busy ? null : () => _askPause(t),
              icon: const Icon(Icons.power_off_rounded),
              label: const Text('البئر واقف'),
            ),
          ),
        ]);
      case WellTurn.paused:
        buttons.addAll([
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: primary,
              onPressed: _busy
                  ? null
                  : () => _run(() => WellTurnService.resume(t),
                      done: 'البئر رجع، والوقت كمل'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('رجع يشتغل',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _busy ? null : () => _confirmFinish(t),
              child: const Text('خلصت'),
            ),
          ),
        ]);
    }

    return Column(
      children: [
        Row(children: buttons),
        if (_isManager && t.currentUserId != _uid)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _confirmSkip(t),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: Text('تخطي دور ${t.nameOf(t.currentUserId)}'),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmFinish(WellTurn t) async {
    final used = t.elapsedMinutes();
    final ok = await _confirm(
      'إنهاء الدور',
      'هيتسجل إنك رويت ${formatTurnDuration(used)}، والدور هينتقل لـ${t.nameOf(t.memberIds[t.nextIndex])}.',
      'تمام، خلصت',
    );
    if (ok) {
      await _run(() => WellTurnService.finish(t),
          done: 'الدور انتقل لـ${t.nameOf(t.memberIds[t.nextIndex])}');
    }
  }

  Future<void> _confirmSkip(WellTurn t) async {
    final ok = await _confirm(
      'تخطي الدور',
      'دور ${t.nameOf(t.currentUserId)} هيتسجل إنه اتخطى، والدور هينتقل للي بعده.',
      'تخطي',
    );
    if (ok) await _run(() => WellTurnService.finish(t, skipped: true));
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(body, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('رجوع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: NabaTheme.primary,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _askPause(WellTurn t) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('البئر وقف ليه؟',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              for (final r in _pauseReasons)
                ListTile(
                  leading: const Icon(Icons.chevron_left_rounded),
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (reason != null) {
      await _run(() => WellTurnService.pause(t, reason),
          done: 'اتسجل إن البئر واقف، والشركاء هيوصلهم تنبيه');
    }
  }

  // ---------------------------------------------------------------- my turn

  Widget _myNextTurn(WellTurn t) {
    final mine = t.upcoming().where((e) => e.uid == _uid).firstOrNull;
    if (mine == null) return const SizedBox.shrink();
    final at = DateTime.now().add(Duration(minutes: mine.startsInMinutes));
    final paused = t.state == WellTurn.paused;
    final notStarted = t.state == WellTurn.waiting;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE2EBE5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.event_available_rounded, color: Color(0xFF265B33)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            paused
                ? 'دورك بعد ما البئر يرجع بـ ${formatTurnDuration(mine.startsInMinutes)} تقريباً'
                : 'دورك بعد ${formatTurnDuration(mine.startsInMinutes)}'
                    '${notStarted ? ' من بداية الدور الحالي' : ''}، حوالي ${DateFormat('EEEE h:mm a', 'ar').format(at)}',
            style: const TextStyle(
                color: Color(0xFF265B33), fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ queue

  Widget _queue(WellTurn t) {
    final now = DateTime.now();
    final entries = [
      (uid: t.currentUserId, startsInMinutes: -1),
      ...t.upcoming(now),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabaTheme.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: NabaTheme.divider),
            _queueRow(t, entries[i].uid, entries[i].startsInMinutes, i, now),
          ],
        ],
      ),
    );
  }

  Widget _queueRow(
      WellTurn t, String uid, int startsIn, int position, DateTime now) {
    final isCurrent = position == 0;
    final me = uid == _uid;
    final String when;
    if (isCurrent) {
      when = t.state == WellTurn.running
          ? 'بيروي دلوقتي'
          : (t.state == WellTurn.paused ? 'متوقف' : 'مستني يبدأ');
    } else if (t.state == WellTurn.paused) {
      when = 'بعد رجوع البئر';
    } else {
      when = DateFormat('h:mm a', 'ar')
          .format(now.add(Duration(minutes: startsIn)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? NabaTheme.primary : const Color(0xFFF1F3F2),
            shape: BoxShape.circle,
          ),
          child: Text('${position + 1}',
              style: TextStyle(
                  color: isCurrent ? Colors.white : NabaTheme.textSecondary,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(me ? '${t.nameOf(uid)} (أنت)' : t.nameOf(uid),
                  style: TextStyle(
                      fontWeight: me || isCurrent
                          ? FontWeight.w800
                          : FontWeight.w500)),
              Text(formatTurnHours(t.hoursOf(uid)),
                  style: const TextStyle(
                      color: NabaTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Text(when,
            style: TextStyle(
              color: isCurrent ? NabaTheme.primary : NabaTheme.textSecondary,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            )),
      ]),
    );
  }

  // -------------------------------------------------------------------- log

  Widget _log(WellTurn t) {
    return StreamBuilder<List<TurnLogEntry>>(
      stream: WellTurnService.log(t.wellId, limit: 10),
      builder: (context, snap) {
        final entries = snap.data ?? const <TurnLogEntry>[];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('لسه مفيش ريّات متسجلة.',
                style: TextStyle(color: NabaTheme.textSecondary)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NabaTheme.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: NabaTheme.divider),
                _logRow(entries[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _logRow(TurnLogEntry e) {
    final diff = e.minutes - e.allottedMinutes;
    final String note;
    final Color noteColor;
    if (e.skipped) {
      note = 'اتخطى';
      noteColor = NabaTheme.textSecondary;
    } else if (diff.abs() <= 10) {
      note = 'في الميعاد';
      noteColor = NabaTheme.primary;
    } else if (diff > 0) {
      note = 'زيادة ${formatTurnDuration(diff)}';
      noteColor = Colors.orange.shade800;
    } else {
      note = 'أقل بـ ${formatTurnDuration(-diff)}';
      noteColor = Colors.blueGrey;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                e.endedAt != null
                    ? DateFormat('EEEE d MMMM • h:mm a', 'ar').format(e.endedAt!)
                    : '',
                style: const TextStyle(
                    color: NabaTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(e.skipped ? '-' : formatTurnDuration(e.minutes),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(note, style: TextStyle(color: noteColor, fontSize: 12)),
          ],
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ bills

  Widget _billsSection(WellTurn t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _sectionTitle('المصاريف')),
          if (_isManager)
            TextButton.icon(
              onPressed: () => _askBill(t),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('قسّم فاتورة'),
            ),
        ]),
        StreamBuilder<List<TurnBill>>(
          stream: WellTurnService.bills(t.wellId),
          builder: (context, snap) {
            final bills = snap.data ?? const <TurnBill>[];
            if (bills.isEmpty) {
              return Text(
                _isManager
                    ? 'لما تيجي فاتورة كهرباء أو سولار، دوس «قسّم فاتورة» وهتتقسم على الشركاء حسب الساعات اللي رواها كل واحد.'
                    : 'مفيش فواتير متقسمة لسه.',
                style: const TextStyle(
                    color: NabaTheme.textSecondary, height: 1.6),
              );
            }
            return Column(
                children: [for (final b in bills) _billCard(t, b)]);
          },
        ),
      ],
    );
  }

  Widget _billCard(WellTurn t, TurnBill b) {
    final myShare = b.shares[_uid];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabaTheme.divider),
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${b.title} • ${_money(b.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (b.createdAt != null)
              DateFormat('d MMMM yyyy', 'ar').format(b.createdAt!),
            if (myShare != null) 'نصيبك ${_money(myShare)}',
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          for (final e in b.shares.entries)
            ListTile(
              dense: true,
              title: Text(t.nameOf(e.key)),
              subtitle: Text(formatTurnDuration(b.minutes[e.key] ?? 0)),
              trailing: Text(_money(e.value),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (_isManager)
            TextButton(
              onPressed: () => WellTurnService.deleteBill(t.wellId, b.id),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف الفاتورة'),
            ),
        ],
      ),
    );
  }

  Future<void> _askBill(WellTurn t) async {
    final amountCtrl = TextEditingController();
    var title = 'كهرباء';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('قسّم فاتورة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final o in ['كهرباء', 'سولار', 'صيانة', 'أخرى'])
                      ChoiceChip(
                        label: Text(o),
                        selected: title == o,
                        showCheckmark: false,
                        onSelected: (_) => setD(() => title = o),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'المبلغ (ج.م)'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هتتقسم حسب الساعات اللي رواها كل واحد من آخر فاتورة.',
                  style:
                      TextStyle(fontSize: 12, color: NabaTheme.textSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('قسّم'),
              ),
            ],
          ),
        ),
      ),
    );
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (result == true && amount > 0) {
      await _run(
          () => WellTurnService.addBill(t, title: title, amount: amount),
          done: 'الفاتورة اتقسمت على الشركاء');
    }
  }

  static String _money(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} ج.م';

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}
