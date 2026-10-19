import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Land-for-sale listing (collection `land_listings`).
///
/// Lifecycle: pending (awaiting admin review) -> approved (public) -> sold.
/// Any edit by the owner sends the listing back to pending.
/// Ownership documents live in `land_listings/{id}/private/ownership`,
/// readable only by the owner and admins.
class LandListing {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String governorate;
  final String district;
  final String village;
  final double? lat;
  final double? lng;
  final double areaFeddan;
  final double price;
  final bool negotiable;
  final String waterSource;
  final String legalStatus;
  final String soilType;
  final List<String> features;
  final String description;
  final List<String> photos;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  const LandListing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.governorate,
    required this.district,
    required this.village,
    this.lat,
    this.lng,
    required this.areaFeddan,
    required this.price,
    this.negotiable = true,
    required this.waterSource,
    required this.legalStatus,
    this.soilType = 'sandy',
    this.features = const [],
    this.description = '',
    this.photos = const [],
    this.status = LandStatus.pending,
    this.rejectionReason,
    required this.createdAt,
  });

  double get pricePerFeddan => areaFeddan > 0 ? price / areaFeddan : 0;
  bool get hasLocation => lat != null && lng != null;
  String get locationLabel =>
      [village, district].where((s) => s.isNotEmpty).join('، ');

  factory LandListing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final loc = d['location'] as Map<String, dynamic>?;
    return LandListing(
      id: doc.id,
      ownerId: d['ownerId'] ?? '',
      ownerName: d['ownerName'] ?? '',
      title: d['title'] ?? '',
      governorate: d['governorate'] ?? '',
      district: d['district'] ?? '',
      village: d['village'] ?? '',
      lat: (loc?['lat'] as num?)?.toDouble(),
      lng: (loc?['lng'] as num?)?.toDouble(),
      areaFeddan: (d['areaFeddan'] as num?)?.toDouble() ?? 0,
      price: (d['price'] as num?)?.toDouble() ?? 0,
      negotiable: d['negotiable'] ?? true,
      waterSource: d['waterSource'] ?? 'none',
      legalStatus: d['legalStatus'] ?? 'preliminary',
      soilType: d['soilType'] ?? 'sandy',
      features: List<String>.from(d['features'] ?? const []),
      description: d['description'] ?? '',
      photos: List<String>.from(d['photos'] ?? const []),
      status: d['status'] ?? LandStatus.pending,
      rejectionReason: d['rejectionReason'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Fields the owner writes on create/edit. Status is always reset to
  /// pending so every change goes through admin review again.
  Map<String, dynamic> toOwnerWrite() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'title': title,
        'governorate': governorate,
        'district': district,
        'village': village,
        'location': hasLocation ? {'lat': lat, 'lng': lng} : null,
        'areaFeddan': areaFeddan,
        'price': price,
        'pricePerFeddan': pricePerFeddan,
        'negotiable': negotiable,
        'waterSource': waterSource,
        'legalStatus': legalStatus,
        'soilType': soilType,
        'features': features,
        'description': description,
        'photos': photos,
        'status': LandStatus.pending,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class LandStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const sold = 'sold';

  static String label(String s) => switch (s) {
        approved => 'معروضة',
        rejected => 'مرفوضة',
        sold => 'تم البيع',
        _ => 'قيد المراجعة',
      };
}

/// Option sets shown in the form and filters (stored value -> Arabic label).
class LandOptions {
  static const waterSources = {
    'well': 'بئر خاص',
    'shared_well': 'بئر مشترك',
    'canal': 'ري حكومي / ترعة',
    'none': 'بدون مصدر مياه',
  };

  static const legalStatuses = {
    'registered': 'عقد مسجل (شهر عقاري)',
    'preliminary': 'عقد ابتدائي',
    'legalizing': 'جاري التقنين',
    'possession': 'وضع يد',
  };

  static const soilTypes = {
    'sandy': 'رملية',
    'clay': 'طينية',
    'mixed': 'صفراء / مختلطة',
    'rocky': 'صخرية',
  };

  static const features = {
    'electricity': 'كهرباء',
    'road': 'على طريق',
    'fenced': 'مسوّرة',
    'planted': 'مزروعة',
    'house': 'بها سكن',
    'solar': 'طاقة شمسية',
  };
}

/// Formats a price compactly in Arabic, e.g. 1,250,000 -> "1.25 مليون".
String formatLandPrice(double v, {bool withCurrency = true}) {
  final suffix = withCurrency ? ' ج.م' : '';
  if (v >= 1000000) {
    final m = v / 1000000;
    final txt = m == m.roundToDouble()
        ? m.toStringAsFixed(0)
        : m.toStringAsFixed(m >= 10 ? 1 : 2).replaceAll(RegExp(r'0+$'), '');
    return '$txt مليون$suffix';
  }
  if (v >= 1000) {
    return '${NumberFormat('#,##0').format(v / 1000)} ألف$suffix';
  }
  return '${NumberFormat('#,##0').format(v)}$suffix';
}

/// Formats an area in feddan, showing qirat for fractions (1 feddan = 24 qirat).
String formatLandArea(double feddan) {
  final whole = feddan.floor();
  final qirat = ((feddan - whole) * 24).round();
  if (whole == 0) return '$qirat قيراط';
  if (qirat == 0 || qirat == 24) {
    return '${qirat == 24 ? whole + 1 : whole} فدان';
  }
  return '$whole فدان و $qirat قيراط';
}
