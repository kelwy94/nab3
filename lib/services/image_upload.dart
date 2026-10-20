import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Uploads an image to Firebase Storage and returns its download URL.
/// Falls back to inline base64 if the upload fails (e.g. offline), so the
/// item can still be saved; [SmartImage] can display either form.
Future<String> uploadImageOrInline(Uint8List bytes, String path) async {
  try {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
        .timeout(const Duration(seconds: 25));
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint('Image upload fell back to base64 ($path): $e');
    return 'base64,${base64Encode(bytes)}';
  }
}
