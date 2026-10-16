import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

class AdminCropSalesTab extends StatefulWidget {
  const AdminCropSalesTab({super.key});

  @override
  State<AdminCropSalesTab> createState() => _AdminCropSalesTabState();
}

class _AdminCropSalesTabState extends State<AdminCropSalesTab> {
  String _statusFilter = 'الكل';
  String _searchQuery = '';
  bool _showMap = false;
  int _selectedTab = 0;

  final List<String> _statuses = [
    'الكل',
    'قيد المراجعة',
    'تم التأكيد',
    'في الطريق للتجميع',
    'تم التجميع',
    'تم البيع/الدفع'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedTab == 0 ? NabaTheme.primary : Colors.grey.shade300,
                    foregroundColor: _selectedTab == 0 ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => setState(() => _selectedTab = 0),
                  child: const Text('محاصيل المزارعين'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedTab == 1 ? NabaTheme.primary : Colors.grey.shade300,
                    foregroundColor: _selectedTab == 1 ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => setState(() => _selectedTab = 1),
                  child: const Text('منتجات السوق (مراجعة)'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedTab == 0 ? _buildCropSales() : _buildMarketProducts(),
        ),
      ],
    );
  }

  Widget _buildCropSales() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('crop_sale_orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('خطأ: ${snapshot.error}',
                  textDirection: TextDirection.rtl));
        }

        List<DocumentSnapshot> docs = snapshot.data?.docs ?? [];

        // Map legacy 'جديد' to 'قيد المراجعة' just for filtering consistency
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String s = data['status'] as String? ?? 'قيد المراجعة';
          if (s == 'جديد') s = 'قيد المراجعة';

          if (_statusFilter != 'الكل' && s != _statusFilter) return false;

          if (_searchQuery.isNotEmpty) {
            String address = data['address']?.toString().toLowerCase() ?? '';
            String crop = data['cropType']?.toString().toLowerCase() ?? '';
            String submitter =
                data['submitterName']?.toString().toLowerCase() ?? '';
            if (!address.contains(_searchQuery.toLowerCase()) &&
                !crop.contains(_searchQuery.toLowerCase()) &&
                !submitter.contains(_searchQuery.toLowerCase())) {
              return false;
            }
          }
          return true;
        }).toList();

        // Calculate total quantity
        double totalQuantity = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          double? qty = double.tryParse(data['quantity']?.toString() ?? '0');
          totalQuantity += (qty ?? 0);
        }

        return Column(
          children: [
            // Filters and Totals Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            hintText: 'ابحث بالعنوان، الاسم، أو المحصول...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            items: _statuses
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        textDirection: TextDirection.rtl)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _statusFilter = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(_showMap ? Icons.list : Icons.map),
                        label: Text(
                            _showMap ? 'عرض القائمة' : 'تحريك على الخريطة'),
                        onPressed: () => setState(() => _showMap = !_showMap),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: NabaTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'إجمالي الكميات: $totalQuantity (فلتر)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: NabaTheme.primary),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content (Map or List)
            Expanded(
              child: _showMap ? _buildMap(docs) : _buildList(docs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(List<DocumentSnapshot> docs) {
    List<Marker> markers = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final loc = data['location'];
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        markers.add(
          Marker(
            point: LatLng(loc['lat'], loc['lng']),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'محصول: ${data['cropType']} | ${data['quantity']}')));
              },
              child: const Icon(Icons.location_on,
                  color: NabaTheme.primary, size: 40),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(27.0544, 27.9739),
        initialZoom: 12.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildList(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Center(
          child: Text('لا توجد طلبات',
              style: TextStyle(fontSize: 18, color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final cId = docs[index].id;

        String s = data['status'] as String? ?? 'قيد المراجعة';
        if (s == 'جديد') s = 'قيد المراجعة';

        Color statusColor = Colors.grey;
        if (s == 'قيد المراجعة') statusColor = Colors.blue;
        if (s == 'تم التأكيد') statusColor = Colors.orange;
        if (s == 'تم التجميع') statusColor = Colors.green;
        if (s == 'تم البيع/الدفع') statusColor = Colors.purple;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(s,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      backgroundColor: statusColor,
                    ),
                    Text(
                      'محصول: ${data['cropType']} - ${data['grade']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                    'الكمية: ${data['quantity']} | العنوان: ${data['address']}',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                    'مقدم الطلب: ${data['submitterName']} (${data['accountType']}) | ت: ${data['submitterPhone'] ?? ''}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                if (data['agreedPrice'] != null)
                  Text('السعر: ${data['agreedPrice']} جنيه',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (data['photoUrl'] != null &&
                    (data['photoUrl'] as String).isNotEmpty)
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (data['photoUrl'] as String).startsWith('base64,')
                          ? Image.memory(
                              base64Decode(
                                  (data['photoUrl'] as String).substring(7)),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image))
                          : Image.network(data['photoUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image)),
                    ),
                  ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: s,
                      items: _statuses
                          .where((st) => st != 'الكل')
                          .map((st) =>
                              DropdownMenuItem(value: st, child: Text(st)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          if (val == 'تم التأكيد') {
                            _showPriceDialog(cId, data);
                          } else {
                            FirebaseFirestore.instance
                                .collection('crop_sale_orders')
                                .doc(cId)
                                .update({'status': val});
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم تحديث حالة الطلب')));
                          }
                        }
                      },
                    ),
                    const Text('تغيير الحالة:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPriceDialog(String cId, Map<String, dynamic> currentData) {
    final TextEditingController _priceCtrl = TextEditingController(
        text: currentData['agreedPrice']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديد السعر المتفق عليه',
            textDirection: TextDirection.rtl),
        content: TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.rtl,
          decoration:
              const InputDecoration(hintText: 'السعر بالجنيه (مثال: 5000)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('crop_sale_orders')
                  .doc(cId)
                  .update({
                'status': 'تم التأكيد',
                'agreedPrice': _priceCtrl.text.trim(),
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تأكيد الطلب وتحديد السعر')));
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketProducts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('catalog').where('isApproved', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد منتجات قيد المراجعة حالياً', style: TextStyle(fontSize: 16)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final price = data['price'] ?? 0.0;
            final sellerIdValue = data['sellerUserId'] as String?;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Image
                    if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: data['photoUrl'].toString().startsWith('http')
                            ? Image.network(data['photoUrl'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40))
                            : Image.memory(base64Decode(data['photoUrl'].toString().contains(',') ? data['photoUrl'].toString().split(',').last : data['photoUrl']), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40)),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                      ),
                    const SizedBox(height: 12),

                    // Additional Photos
                    if (data['additionalPhotos'] != null && (data['additionalPhotos'] as List).isNotEmpty)
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (data['additionalPhotos'] as List).length,
                          itemBuilder: (context, i) {
                            final photo = (data['additionalPhotos'] as List)[i].toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: photo.startsWith('http')
                                  ? Image.network(photo, width: 70, height: 70, fit: BoxFit.cover)
                                  : Image.memory(base64Decode(photo.contains(',') ? photo.split(',').last : photo), width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                              ),
                            );
                          },
                        ),
                      ),
                    if (data['additionalPhotos'] != null && (data['additionalPhotos'] as List).isNotEmpty)
                      const SizedBox(height: 12),

                    // Product Name & Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(data['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                        Text('$price ج.م', style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Info Chips Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _infoChip(Icons.category_outlined, data['category'] ?? ''),
                        _infoChip(Icons.straighten, 'الوحدة: ${data['unit'] ?? ''}'),
                        if ((data['quantity'] ?? 0) > 0)
                          _infoChip(Icons.inventory_2_outlined, 'الكمية: ${data['quantity']}'),
                        if ((data['discountPercentage'] ?? 0) > 0)
                          _infoChip(Icons.discount_outlined, 'خصم: ${data['discountPercentage']}%'),
                        _infoChip(Icons.fiber_new_outlined, data['condition'] ?? 'جديد'),
                        if ((data['minOrderQuantity'] ?? 0) > 1)
                          _infoChip(Icons.shopping_bag_outlined, 'أقل طلب: ${data['minOrderQuantity']}'),
                        _infoChip(
                          data['deliveryAvailable'] == true ? Icons.local_shipping : Icons.no_transfer,
                          data['deliveryAvailable'] == true ? 'توصيل متاح' : 'بدون توصيل',
                        ),
                        _infoChip(
                          data['stockStatus'] == true ? Icons.check_circle_outline : Icons.remove_circle_outline,
                          data['stockStatus'] == true ? 'متوفر' : 'غير متوفر',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Address
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text('العنوان: ${data['address']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                        ],
                      ),

                    // Description
                    if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الوصف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(data['description'], style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                      const Divider(height: 16),
                      if (sellerIdValue != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(sellerIdValue).get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                            final user = userSnap.data!.data() as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('البائع: ${user['fullName'] ?? 'غير معروف'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('الهاتف: ${user['phone'] ?? '---'}',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await doc.reference.update({'isApproved': true});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول المنتج وإضافته للسوق')));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: NabaTheme.primary, foregroundColor: Colors.white),
                          icon: const Icon(Icons.check),
                          label: const Text('قبول'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('رفض المنتج'),
                                content: const Text('هل أنت متأكد من رفض وحذف هذا المنتج؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض', style: TextStyle(color: Colors.red))),
                                ],
                              )
                            );
                            if (confirm == true) {
                              await doc.reference.delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنتج')));
                              }
                            }
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('رفض', style: TextStyle(color: Colors.red)),
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
