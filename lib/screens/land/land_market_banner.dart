import 'package:flutter/material.dart';

import '../../models/land_listing.dart';
import '../../services/land_service.dart';
import '../../theme.dart';
import 'land_market_screen.dart';

/// Home-screen entry card for the land market, showing a live listing count.
class LandMarketBanner extends StatelessWidget {
  const LandMarketBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NabaTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LandMarketScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EDE2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/images/icons/lands_v2.png'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سوق الأراضي',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: NabaTheme.textPrimary)),
                    const SizedBox(height: 2),
                    StreamBuilder<List<LandListing>>(
                      stream: LandService.approvedListings(),
                      builder: (context, snap) {
                        final n = snap.data?.length ?? 0;
                        return Text(
                          n > 0
                              ? '$n أرض معروضة للبيع'
                              : 'اشتري أو اعرض أرضك للبيع',
                          style: const TextStyle(
                              color: NabaTheme.textSecondary, fontSize: 13),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: NabaTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
