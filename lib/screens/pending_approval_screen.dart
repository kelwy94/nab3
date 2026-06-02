import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Hero(
                tag: 'logo',
                child: Text(
                  'نبع',
                  style: TextStyle(
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    color: NabaTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  size: 64,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'حسابك قيد المراجعة',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NabaTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'شكراً لتسجيلك في نبع. يتم حالياً مراجعة بياناتك من قبل الإدارة لضمان جودة الخدمة. ستتمكن من استخدام التطبيق فور الموافقة على حسابك.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              NabaButton(
                text: 'تسجيل الخروج',
                isPrimary: false,
                onPressed: () =>
                    Provider.of<AuthProvider>(context, listen: false).logout(),
                icon: Icons.logout_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
