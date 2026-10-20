import 'package:flutter/material.dart';

import '../../models/types.dart';
import '../../services/well_turn_service.dart';
import '../../theme.dart';
import '../../widgets/naba_widgets.dart';

/// Well manager arranges the rotation: who is in it, in what order, and how
/// many hours each partner gets per turn.
class WellTurnSetupScreen extends StatefulWidget {
  final Well well;
  final WellTurn? existing;
  const WellTurnSetupScreen({super.key, required this.well, this.existing});

  @override
  State<WellTurnSetupScreen> createState() => _WellTurnSetupScreenState();
}

class _Row {
  final String uid;
  final String name;
  final double area;
  double hours;
  bool included;
  _Row(this.uid, this.name, this.area, this.hours, this.included);
}

class _WellTurnSetupScreenState extends State<WellTurnSetupScreen> {
  List<_Row>? _rows;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _defaultHours(double area, double avgArea) {
    final double base =
        widget.well.hoursPerPerson > 0 ? widget.well.hoursPerPerson : 3.0;
    if (widget.well.fairnessRule == FairnessRule.proportional &&
        area > 0 &&
        avgArea > 0) {
      final h = base * area / avgArea;
      return ((h * 2).round() / 2).clamp(0.5, 24).toDouble();
    }
    return base;
  }

  Future<void> _load() async {
    try {
      final candidates = await WellTurnService.candidates(
          widget.well.id, widget.well.adminUserId);
      final areas = candidates.where((c) => c.areaFeddan > 0).map((c) => c.areaFeddan);
      final avg = areas.isEmpty ? 0.0 : areas.reduce((a, b) => a + b) / areas.length;
      final ex = widget.existing;

      final rows = <_Row>[];
      // Keep the saved order first, then anyone who joined since.
      if (ex != null) {
        for (final uid in ex.memberIds) {
          final c = candidates.where((c) => c.uid == uid).firstOrNull;
          rows.add(_Row(uid, c?.name ?? ex.nameOf(uid), c?.areaFeddan ?? 0,
              ex.hoursOf(uid), true));
        }
      }
      for (final c in candidates) {
        if (rows.any((r) => r.uid == c.uid)) continue;
        rows.add(_Row(c.uid, c.name, c.areaFeddan,
            _defaultHours(c.areaFeddan, avg), ex == null));
      }
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      debugPrint('Load turn candidates failed: $e');
      if (mounted) setState(() => _error = 'تعذّر تحميل الشركاء');
    }
  }

  Future<void> _save() async {
    final rows = _rows!.where((r) => r.included).toList();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لازم شريك واحد على الأقل في الدور')));
      return;
    }
    setState(() => _saving = true);
    try {
      await WellTurnService.saveSetup(
        wellId: widget.well.id,
        wellName: widget.well.wellName,
        managerId: widget.well.adminUserId,
        order: [for (final r in rows) r.uid],
        names: {for (final r in rows) r.uid: r.name},
        hours: {for (final r in rows) r.uid: r.hours},
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save turn setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّر الحفظ، حاول تاني'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final total = rows == null
        ? 0.0
        : rows.where((r) => r.included).fold<double>(0, (a, r) => a + r.hours);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ترتيب الدور'),
          leading: const NabaBackButton(),
        ),
        bottomNavigationBar: rows == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الدورة الكاملة: ${formatTurnHours(total)}'
                        '${total > 24 ? ' (حوالي ${(total / 24).toStringAsFixed(1)} يوم)' : ''}',
                        style: const TextStyle(color: NabaTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NabaTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الدور',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        body: _error != null
            ? Center(child: Text(_error!))
            : rows == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          'اسحب الاسم من العلامة ☰ لتغيير الترتيب، وحدد ساعات كل شريك في الدور.',
                          style: TextStyle(
                              color: NabaTheme.textSecondary, height: 1.5),
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          itemCount: rows.length,
                          buildDefaultDragHandles: false,
                          onReorder: (from, to) => setState(() {
                            if (to > from) to -= 1;
                            rows.insert(to, rows.removeAt(from));
                          }),
                          itemBuilder: (context, i) => _rowTile(rows[i], i),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _rowTile(_Row r, int i) {
    final position = _rows!.take(i + 1).where((x) => x.included).length;
    return Container(
      key: ValueKey(r.uid),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: r.included ? Colors.white : const Color(0xFFF4F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NabaTheme.divider),
      ),
      child: Row(children: [
        ReorderableDragStartListener(
          index: i,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.drag_indicator_rounded,
                color: NabaTheme.textSecondary),
          ),
        ),
        Checkbox(
          value: r.included,
          activeColor: NabaTheme.primary,
          onChanged: (v) => setState(() => r.included = v ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.included ? '$position. ${r.name}' : r.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: r.included
                      ? NabaTheme.textPrimary
                      : NabaTheme.textSecondary,
                ),
              ),
              Text(
                [
                  if (r.uid == widget.well.adminUserId) 'صاحب البئر',
                  if (r.area > 0) '${_trim(r.area)} فدان',
                  if (!r.included) 'خارج الدور',
                ].join(' • '),
                style: const TextStyle(
                    color: NabaTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        if (r.included) ...[
          _stepButton(Icons.remove_rounded, () {
            if (r.hours > 0.5) setState(() => r.hours -= 0.5);
          }),
          SizedBox(
            width: 58,
            child: Text(formatTurnHours(r.hours),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _stepButton(Icons.add_rounded, () {
            if (r.hours < 24) setState(() => r.hours += 0.5);
          }),
        ],
      ]),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) => Material(
        color: const Color(0xFFE2EBE5),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: const Color(0xFF265B33)),
          ),
        ),
      );

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
