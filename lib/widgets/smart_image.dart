import 'dart:convert';

import 'package:flutter/material.dart';

/// Shows an image stored as a Firebase Storage URL or as inline base64
/// (older items, or uploads made while Storage was unavailable).
class SmartImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final IconData placeholderIcon;

  const SmartImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final s = source;
    if (s == null || s.isEmpty) return _placeholder();
    if (s.startsWith('http')) {
      return Image.network(
        s,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : Container(
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
        errorBuilder: (_, __, ___) => _placeholder(broken: true),
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
        errorBuilder: (_, __, ___) => _placeholder(broken: true),
      );
    } catch (_) {
      return _placeholder(broken: true);
    }
  }

  Widget _placeholder({bool broken = false}) => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(broken ? Icons.broken_image_outlined : placeholderIcon,
            color: Colors.grey.shade400, size: 40),
      );
}
