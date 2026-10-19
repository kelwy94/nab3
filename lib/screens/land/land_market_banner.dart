import 'package:flutter/material.dart';

import '../../models/land_listing.dart';
import '../../services/land_service.dart';
import 'land_market_screen.dart';

/// Home-screen entry card for the land market, showing a live listing count.
class LandMarketBanner extends StatelessWidget {
  const LandMarketBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LandMarketScreen())),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8D6E3F), Color(0xFFC49A5A)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -20,
                bottom: -24,
                child: Icon(Icons.landscape_rounded,
                    size: 130, color: Colors.white.withOpacity(0.15)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.terrain_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سوق الأراضي',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          StreamBuilder<List<LandListing>>(
                            stream: LandService.approvedListings(),
                            builder: (context, snap) {
                              final n = snap.data?.length ?? 0;
                              return Text(
                                n > 0
                                    ? '$n أرض معروضة • اشتري أو اعرض أرضك'
                                    : 'اشتري أو اعرض أرضك للبيع بأمان',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
