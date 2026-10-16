import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class NabaTopHeader extends StatelessWidget {
  final String? title;
  final Widget? trailing;

  const NabaTopHeader({super.key, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final userName = user?.fullName ?? 'ضيف';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          CircleAvatar(
            backgroundColor: NabaTheme.primary.withOpacity(0.2),
            radius: 22,
            backgroundImage: (user != null && user.profileImageUrl != null)
                ? NetworkImage(user.profileImageUrl!) as ImageProvider
                : (user != null && user.profileImageBase64 != null)
                    ? MemoryImage(base64Decode(user.profileImageBase64!))
                    : null,
            child: (user == null || (user.profileImageUrl == null && user.profileImageBase64 == null))
                ? const Icon(Icons.person, color: NabaTheme.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title ?? 'أهلاً بك 👋', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          if (trailing != null) trailing!
        ],
      ),
    );
  }
}
