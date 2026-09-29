import 'package:flutter/material.dart';

import '../screens/onboarding_screen.dart';
import '../theme.dart';

class GuestUtils {
  static void showGuestLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: NabaTheme.primary),
              SizedBox(width: 8),
              Text('سجّل للمتابعة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'هذه الميزة متاحة للمستخدمين المسجّلين فقط.\nسجّل الآن مجاناً وابدأ في استخدام خدمات نبع.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                OnboardingScreen.showRoleSelection(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('سجّل الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
