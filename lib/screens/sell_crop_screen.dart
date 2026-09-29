import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'map_picker_screen.dart';
import 'user_crop_sales_tracking_screen.dart';

class SellCropScreen extends StatefulWidget {
  const SellCropScreen({super.key});

  @override
  State<SellCropScreen> createState() => _SellCropScreenState();
}

class _SellCropScreenState extends State<SellCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedCrop = 'بلح';
  String _selectedGrade = 'درجة أولى (النخبة)';
  LatLng? _selectedLocation;
  Uint8List? _cropImageBytes;
  String? _cropImagePath;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _cropImageBytes = bytes;
          _cropImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cropImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء رفع صورة للمحصول (إجبارية)')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد الموقع الجغرافي للمحصول')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user!;

      String photoUrl = '';
      try {
        final String imageId = const Uuid().v4();
        final Reference ref = FirebaseStorage.instance
            .ref()
            .child('equipment_images/crop_$imageId.jpg');

        final SettableMetadata metadata =
            SettableMetadata(contentType: 'image/jpeg');
        UploadTask uploadTask;

        if (kIsWeb || _cropImagePath == null) {
          uploadTask = ref.putData(_cropImageBytes!, metadata);
        } else {
          uploadTask = ref.putFile(File(_cropImagePath!), metadata);
        }

        final TaskSnapshot snapshot = await uploadTask;
        photoUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Storage failed, using base64 fallback: $e");
        photoUrl = "base64,${base64Encode(_cropImageBytes!)}";
      }

      // Save order to Firestore
      await FirebaseFirestore.instance.collection('crop_sale_orders').add({
        'userId': user.id,
        'submitterName': user.fullName,
        'accountType': user.role.name,
        'phone': user.phone,
        'cropType': _selectedCrop,
        'quantity': _quantityController.text.trim(),
        'grade': _selectedGrade,
        'address': _addressController.text.trim(),
        'location': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude
        },
        'photoUrl': photoUrl,
        'status': 'قيد المراجعة', // Changed from جديد to align with new stages
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال الطب بنجاح! سيتم التواصل معك قريباً.'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الإرسال: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'بيع محصولك'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Tracking Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('سجل طلباتي وتتبعها',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: NabaTheme.primary,
                          elevation: 0,
                          side: const BorderSide(color: NabaTheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UserCropSalesTrackingScreen()));
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                        'مرحباً بك في خدمة بيع المحاصيل، يمكنك الآن بيع محصولك من خلالنا بأفضل الأسعار!',
                        style: TextStyle(
                            fontSize: 16, color: NabaTheme.textSecondary),
                        textDirection: TextDirection.rtl),
                    const SizedBox(height: 24),

                    // Crop Photo (Mandatory)
                    const Text('صورة المحصول (مطلوب)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _cropImageBytes != null
                              ? Colors.green.shade50
                              : Colors.white,
                          border: Border.all(
                              color: _cropImageBytes != null
                                  ? Colors.green
                                  : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _cropImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(_cropImageBytes!,
                                    fit: BoxFit.cover))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'اضغط لرفع صورة فوتوغرافية للمحصول',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      decoration:
                          _inputDecoration('نوع المحصول', Icons.grass_rounded),
                      value: _selectedCrop,
                      items: ['بلح'] // more can be added later
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, textDirection: TextDirection.rtl)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCrop = v!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.text,
                      validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                      decoration: _inputDecoration(
                          'الكمية التقريبية (بالكيلو أو الطن)',
                          Icons.scale_rounded),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(
                          'الصنف / الدرجة', Icons.star_border_rounded),
                      value: _selectedGrade,
                      items: [
                        'درجة أولى (النخبة)',
                        'درجة ثانية (جيد)',
                        'درجة ثالثة (متوسط)'
                      ]
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, textDirection: TextDirection.rtl)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGrade = v!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                      decoration: _inputDecoration('العنوان التفصيلي للتحميل',
                          Icons.location_city_rounded),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.pin_drop_rounded,
                            color: NabaTheme.primary),
                        label: Text(
                            _selectedLocation == null
                                ? 'تحديد الموقع بالـ GPS'
                                : 'تم تحديد الموقع بنجاح ✓',
                            style: TextStyle(
                                color: _selectedLocation == null
                                    ? NabaTheme.primary
                                    : Colors.green,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color: _selectedLocation == null
                                  ? NabaTheme.primary
                                  : Colors.green),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final LatLng? result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => MapPickerScreen(
                                    initialLocation: _selectedLocation)),
                          );
                          if (result != null)
                            setState(() => _selectedLocation = result);
                        },
                      ),
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NabaTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('إرسال طلب البيع',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      suffixIcon: Icon(icon, color: NabaTheme.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: true,
    );
  }
}
