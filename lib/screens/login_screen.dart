import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/biometric_helper.dart';
import '../services/support_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _hasBiometricCreds = false;
  final _secureStorage = const FlutterSecureStorage();
  final _bioHelper = BiometricHelper();

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _checkBiometricCreds();
  }

  Future<void> _checkBiometricCreds() async {
    final email = await _secureStorage.read(key: 'saved_email');
    final pass = await _secureStorage.read(key: 'saved_password');
    final isBioEnabled = await _secureStorage.read(key: 'biometric_enabled');

    if (email != null && pass != null && isBioEnabled == 'true') {
      final canBio = await _bioHelper.hasBiometrics();
      if (canBio) {
        if (mounted) {
          setState(() {
            _hasBiometricCreds = true;
          });
        }
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authenticated = await _bioHelper.authenticate();
    if (authenticated) {
      final email = await _secureStorage.read(key: 'saved_email');
      final pass = await _secureStorage.read(key: 'saved_password');
      if (email != null && pass != null) {
        setState(() => _isLoading = true);
        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.login(email, pass);
          if (!mounted) return;
          Navigator.of(context).pop();
        } catch (e) { print('Login error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'فشل الدخول بالبصمة أو انتهت الجلسة، الرجاء تسجيل الدخول بكلمة المرور')),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);

        final email = "${_phoneController.text}@naba.app";
        await auth.login(email, _passwordController.text);
        if (!mounted) return;
        Navigator.of(context).pop();
        // AuthWrapper will handle transition to dashboard
      } catch (e) { print('Login error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('خطأ في تسجيل الدخول، تأكد من البيانات')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Accounts use placeholder emails, so reset links can't be delivered.
  /// Users contact support, and an admin issues a temporary password.
  Future<void> _showForgotPassword() async {
    final support = await SupportService.supportWhatsapp();
    if (!mounted) return;
    final phone = _phoneController.text.trim();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نسيت كلمة المرور؟'),
          content: Text(
            support != null
                ? 'كلّم الدعم على واتساب، وبعد ما نتأكد إن الحساب بتاعك هنبعتلك كلمة مرور مؤقتة تدخل بيها وتغيّرها.'
                : 'تواصل مع إدارة التطبيق، وبعد ما يتأكدوا إن الحساب بتاعك هيبعتولك كلمة مرور مؤقتة تدخل بيها وتغيّرها.',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق')),
            if (support != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  SupportService.openWhatsapp(
                    support,
                    'السلام عليكم، نسيت كلمة المرور بتاعة حسابي على تطبيق نبع'
                    '${phone.isNotEmpty ? ' (رقم الحساب: $phone)' : ''}.',
                  );
                },
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('كلّم الدعم'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'تسجيل الدخول'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Hero(
                  tag: 'logo',
                  child: Center(
                    child: Text(
                      'نبع',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: NabaTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _buildFieldLabel('رقم الهاتف'),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: '01xxxxxxxxx'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('كلمة المرور'),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(hintText: '********'),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 48),
                NabaButton(
                  text: _isLoading ? 'جاري التحميل...' : 'دخول',
                  onPressed: _isLoading ? null : _handleLogin,
                  icon: _isLoading ? null : Icons.login_rounded,
                ),
                if (_hasBiometricCreds) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleBiometricLogin,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text(
                      'الدخول بالبصمة / الوجه',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: NabaTheme.primary,
                      side: const BorderSide(
                          color: NabaTheme.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _showForgotPassword,
                  child: const Text('نسيت كلمة المرور؟',
                      style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ليس لدي حساب؟ سجل الآن',
                      style: TextStyle(
                          color: NabaTheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

