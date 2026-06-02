import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';

/// Reusable dialog for submitting payment transfer proof.
/// Used in checkout (for sellers) and job_details (for workers/equipment owners).
class PaymentProofDialog extends StatefulWidget {
  final String recipientName;
  final String paymentMethodLabel;
  final String paymentDetails;
  final double amount;
  final Future<void> Function(String senderNumber, String? screenshotBase64) onSubmit;

  const PaymentProofDialog({
    super.key,
    required this.recipientName,
    required this.paymentMethodLabel,
    required this.paymentDetails,
    required this.amount,
    required this.onSubmit,
  });

  @override
  State<PaymentProofDialog> createState() => _PaymentProofDialogState();
}

class _PaymentProofDialogState extends State<PaymentProofDialog> {
  final _senderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Uint8List? _screenshotBytes;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  bool get _isBankPayment => widget.paymentMethodLabel.contains('بنكي');

  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _screenshotBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error picking screenshot: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Require screenshot
    if (_screenshotBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يجب رفع صورة إثبات التحويل'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? base64Screenshot;
      if (_screenshotBytes != null) {
        base64Screenshot = base64Encode(_screenshotBytes!);
      }
      await widget.onSubmit(_senderController.text, base64Screenshot);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _senderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NabaTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payment, color: NabaTheme.primary, size: 36),
                ),
                const SizedBox(height: 12),
                const Text('تأكيد التحويل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'حوّل المبلغ ثم أرسل الإثبات',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),

                const SizedBox(height: 20),

                // Recipient Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      Text('حوّل لـ: ${widget.recipientName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.paymentMethodLabel,
                            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.paymentDetails,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: NabaTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'المبلغ: ${widget.amount.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sender Info Field — dynamic label based on payment method
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _isBankPayment ? 'رقم الحساب المحول منه' : 'الرقم اللي حولت منه',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _senderController,
                  textAlign: TextAlign.right,
                  keyboardType: _isBankPayment ? TextInputType.number : TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: _isBankPayment ? 'أدخل رقم الحساب البنكي' : '01xxxxxxxxx',
                    prefixIcon: Icon(_isBankPayment ? Icons.account_balance : Icons.phone_android, color: NabaTheme.primary),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                    if (!_isBankPayment && v.length < 11) return 'أدخل رقم صحيح';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Screenshot Upload
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('سكرين شوت التحويل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickScreenshot,
                  child: Container(
                    width: double.infinity,
                    height: _screenshotBytes != null ? 200 : 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _screenshotBytes != null ? NabaTheme.primary : Colors.grey.shade300,
                        width: _screenshotBytes != null ? 2 : 1,
                      ),
                    ),
                    child: _screenshotBytes != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_screenshotBytes!, width: double.infinity, height: 200, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_circle, color: NabaTheme.primary, size: 24),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _screenshotBytes = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade400, size: 32),
                              const SizedBox(height: 6),
                              Text('اضغط لرفع صورة إثبات التحويل', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NabaTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('إرسال إثبات التحويل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
