import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/land_listing.dart';
import '../theme.dart';

const Map<String, IconData> kLandFeatureIcons = {
  'electricity': Icons.bolt_rounded,
  'road': Icons.add_road_rounded,
  'fenced': Icons.fence_rounded,
  'planted': Icons.grass_rounded,
  'house': Icons.home_rounded,
  'solar': Icons.solar_power_rounded,
};

const Map<String, IconData> kWaterIcons = {
  'well': Icons.water_drop_rounded,
  'shared_well': Icons.water_drop_outlined,
  'canal': Icons.waves_rounded,
  'none': Icons.format_color_reset_rounded,
};

/// Shows an image stored either as a URL or as inline base64.
class LandImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;

  const LandImage(this.source, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final s = source;
    if (s == null || s.isEmpty) return const _LandPlaceholder();
    if (s.startsWith('http')) {
      return Image.network(
        s,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (c, child, progress) =>
            progress == null ? child : const _LandPlaceholder(loading: true),
        errorBuilder: (_, __, ___) => const _LandPlaceholder(),
      );
    }
    try {
      final raw = s.startsWith('base64,') ? s.substring(7) : s.split(',').last;
      return Image.memory(
        base64Decode(raw.trim()),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _LandPlaceholder(),
      );
    } catch (_) {
      return const _LandPlaceholder();
    }
  }
}

class _LandPlaceholder extends StatelessWidget {
  final bool loading;
  const _LandPlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE8D9B5), Colors.brown.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.landscape_rounded,
                size: 44, color: Colors.brown.shade300),
      ),
    );
  }
}

class LandStatusBadge extends StatelessWidget {
  final String status;
  const LandStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LandStatus.approved => Colors.green.shade600,
      LandStatus.rejected => Colors.red.shade600,
      LandStatus.sold => Colors.blueGrey.shade600,
      _ => Colors.orange.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(LandStatus.label(status),
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

/// Small icon + text pill used for area, water, legal status, etc.
class LandFact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const LandFact(this.icon, this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? NabaTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Listing card for the market feed.
class LandCard extends StatelessWidget {
  final LandListing listing;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

  const LandCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x141B1F1D), blurRadius: 28, offset: Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 190,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'land_${l.id}',
                      child: LandImage(l.photos.isNotEmpty ? l.photos.first : null),
                    ),
                    // Bottom gradient so the price stays readable on any photo.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1],
                          colors: [Color(0x000A1410), Color(0xB80A1410)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatLandPrice(l.price),
                              style: NabaTheme.display(24, color: Colors.white)),
                          Text(
                              '${formatLandPrice(l.pricePerFeddan)} / فدان'
                              '${l.negotiable ? ' • قابل للتفاوض' : ''}',
                              style: const TextStyle(
                                  color: Color(0xFFF3EBDD), fontSize: 13)),
                        ],
                      ),
                    ),
                    if (l.photos.length > 1)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _pill(Icons.photo_library_rounded,
                            '${l.photos.length}'),
                      ),
                    if (onToggleSave != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleSave,
                            icon: Icon(
                              saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: saved ? Colors.red : Colors.grey.shade600,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    if (l.status == LandStatus.sold)
                      const Positioned(
                          right: 10, top: 10, child: LandStatusBadge(LandStatus.sold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: NabaTheme.textPrimary)),
                    const SizedBox(height: 6),
                    LandFact(Icons.location_on_rounded, l.locationLabel,
                        color: NabaTheme.primary),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: LandFact(Icons.straighten_rounded,
                                formatLandArea(l.areaFeddan))),
                        Expanded(
                          child: LandFact(
                              kWaterIcons[l.waterSource] ??
                                  Icons.water_drop_rounded,
                              LandOptions.waterSources[l.waterSource] ?? ''),
                        ),
                        if (l.legalStatus == 'registered')
                          LandFact(Icons.verified_rounded, 'مسجلة',
                              color: Colors.green.shade700),
                      ],
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

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );
}
