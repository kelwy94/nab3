import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'models/types.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/job_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/well_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/admin_dashboard.dart';
import 'screens/equipment_owner_dashboard.dart';
import 'screens/farmer_dashboard.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/seller_dashboard.dart';
import 'screens/worker_dashboard.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  try {
    await initializeDateFormatting('ar_SA', null);
  } catch (e) {
    debugPrint('Date formatting initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WellProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(
            create: (_) => JobProvider()), // Added this provider
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    
    return MaterialApp(
      title: 'نبع - Naba',
      theme: NabaTheme.lightTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isAuthenticated) {
      if (auth.user!.status == AccountStatus.pending &&
          auth.user!.role != UserRole.admin) {
        return const PendingApprovalScreen();
      }
      return const DashboardSwitcher();
    } else {
      return const OnboardingScreen();
    }
  }
}

class DashboardSwitcher extends StatelessWidget {
  const DashboardSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إغلاق التطبيق'),
              content: const Text('هل أنت متأكد من رغبتك في إغلاق التطبيق؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        );
        if (shouldPop ?? false) {
          SystemNavigator.pop();
        }
      },
      child: _buildDashboard(user.role),
    );
  }

  Widget _buildDashboard(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return const FarmerDashboard();
      case UserRole.worker:
        return const WorkerDashboard();
      case UserRole.seller:
        return const SellerDashboard();
      case UserRole.equipmentOwner:
        return const EquipmentOwnerDashboard();
      case UserRole.investor:
        return const FarmerDashboard(); // Placeholder until investor flow is enabled
      case UserRole.admin:
        return const AdminDashboard();
    }
  }
}
