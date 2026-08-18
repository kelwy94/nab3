import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
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
      } catch (e) {
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
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (_phoneController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال رقم الهاتف أولاً لإرسال رابط الاستعادة')),
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text('استعادة كلمة المرور'),
                          content: Text('هل تريد إرسال رابط استعادة كلمة المرور إلى الحساب المرتبط برقم ${_phoneController.text}؟\n(ملاحظة: النظام يستخدم بريداً افتراضياً)'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await Provider.of<AuthProvider>(context, listen: false).resetPassword("${_phoneController.text}@naba.app");
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تم إرسال طلب استعادة كلمة المرور بنجاح!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('حدث خطأ، تأكد من أن الرقم مسجل')),
                                    );
                                  }
                                }
                              },
                              child: const Text('إرسال'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.grey)),
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
