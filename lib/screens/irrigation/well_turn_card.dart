import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/types.dart';
import '../../providers/auth_provider.dart';
import '../../services/well_turn_service.dart';
import '../../theme.dart';
import 'well_turn_screen.dart';

/// Compact live summary of a well's rotation for the home screen.
class WellTurnCard extends StatelessWidget {
  final Well well;
  const WellTurnCard({super.key, required this.well});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.id ?? '';
    return StreamBuilder<WellTurn?>(
      stream: WellTurnService.watch(well.id),
      builder: (context, snap) {
        final t = snap.data;
        final String title;
        final String subtitle;
        Color accent = const Color(0xFF265B33);

        if (t == null || t.isEmpty) {
          title = 'دور الري';
          subtitle = well.adminUserId == uid
              ? 'رتّب دور الشركاء على البئر'
              : 'اعرف دورك ومين بيروي دلوقتي';
        } else if (t.currentUserId == uid) {
          title = t.state == WellTurn.running
              ? 'دورك شغال • فاضل ${formatTurnDuration(t.remainingMinutes())}'
              : (t.state == WellTurn.paused ? 'البئر واقف في دورك' : 'دورك جه دلوقتي');
          subtitle = t.state == WellTurn.waiting
              ? 'افتح المية ودوس «بدأت»'
              : (t.pauseReason ?? 'دوس «خلصت» لما تخلص');
          accent = t.state == WellTurn.paused
              ? Colors.orange.shade800
              : NabaTheme.primary;
        } else {
          final current = t.nameOf(t.currentUserId);
          title = t.state == WellTurn.paused
              ? 'البئر واقف • ${t.pauseReason ?? ''}'
              : (t.state == WellTurn.running
                  ? 'بيروي دلوقتي: $current'
                  : 'الدور على: $current');
          final mine = t.upcoming().where((e) => e.uid == uid).firstOrNull;
          subtitle = mine == null
              ? 'شوف ترتيب الدور'
              : 'دورك بعد ${formatTurnDuration(mine.startsInMinutes)} تقريباً';
          if (t.state == WellTurn.paused) accent = Colors.orange.shade800;
        }

        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withOpacity(0.35), width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => WellTurnScreen(well: well))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EBE5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Image.asset('assets/images/icons/well.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: accent)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: NabaTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: NabaTheme.textSecondary),
              ]),
            ),
          ),
        );
      },
    );
  }
}
