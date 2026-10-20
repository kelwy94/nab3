import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// App-wide support settings kept in `app_config/public` (readable by
/// everyone, editable by admins from the admin dashboard).
class SupportService {
  SupportService._();

  static final _doc =
      FirebaseFirestore.instance.collection('app_config').doc('public');

  static Future<String?> supportWhatsapp() async {
    try {
      final d = await _doc.get();
      final n = d.data()?['supportWhatsapp'] as String?;
      return (n == null || n.trim().isEmpty) ? null : n.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSupportWhatsapp(String number) =>
      _doc.set({'supportWhatsapp': number.trim()}, SetOptions(merge: true));

  /// Egyptian mobile 01xxxxxxxxx -> 201xxxxxxxxx for wa.me links.
  static String toInternational(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.startsWith('0') ? '2$digits' : digits;
  }

  static Future<bool> openWhatsapp(String phone, String message) =>
      launchUrl(
        Uri.parse(
            'https://wa.me/${toInternational(phone)}?text=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication,
      );
}
