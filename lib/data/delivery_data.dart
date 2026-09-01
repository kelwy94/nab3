/// بيانات المحافظات والمراكز والقرى وأسعار التوصيل
/// يمكن نقل هذه البيانات لاحقاً إلى Firestore أو لوحة تحكم
library;

/// المحافظات المتاحة
const List<String> kGovernorates = [
  'الوادي الجديد',
];

/// المراكز حسب كل محافظة
const Map<String, List<String>> kDistrictsByGovernorate = {
  'الوادي الجديد': [
    'الفرافرة',
    'الداخلة',
    'الخارجة',
  ],
};

/// القرى حسب كل مركز
const Map<String, List<String>> kVillagesByDistrict = {
  'الفرافرة': [
    'النهضة',
    'اللواء صبيح',
    'عثمان بن عفان',
    'الرواد',
    'أبوبكر الصديق',
    'خالد بن الوليد',
    'أبوهريرة',
    'أبومنقار',
    'مدينة الفرافرة',
  ],
  'الداخلة': [
    'غرب الموهوب',
    'القصر وعزب القصر',
    'بدخلو والراشدة',
    'الدهوس والهنداو',
    'مدينة موط',
  ],
  'الخارجة': [],
};

/// أسعار التوصيل بالجنيه المصري حسب المركز ثم القرية
const Map<String, Map<String, double>> kDeliveryFees = {
  'الفرافرة': {
    'النهضة': 20,
    'اللواء صبيح': 20,
    'عثمان بن عفان': 30,
    'الرواد': 30,
    'أبوبكر الصديق': 30,
    'خالد بن الوليد': 45,
    'أبوهريرة': 45,
    'أبومنقار': 65,
    'مدينة الفرافرة': 15,
  },
  'الداخلة': {
    'غرب الموهوب': 65,
    'القصر وعزب القصر': 50,
    'بدخلو والراشدة': 25,
    'الدهوس والهنداو': 20,
    'مدينة موط': 15,
  },
  'الخارجة': {},
};

/// المراكز المتاحة (flat list for marketplace dropdown)
List<String> get kDistricts {
  final districts = <String>[];
  for (final govDistricts in kDistrictsByGovernorate.values) {
    districts.addAll(govDistricts);
  }
  return districts;
}

/// استرجاع سعر التوصيل لقرية معينة في مركز معين
/// يرجع null لو المركز أو القرية مش موجودين
double? getDeliveryFee(String? district, String? village) {
  if (district == null || village == null) return null;
  return kDeliveryFees[district]?[village];
}

/// التحقق إذا كان المركز يدعم القرى (جاهز ولا لسه)
bool isDistrictReady(String district) {
  final villages = kVillagesByDistrict[district];
  return villages != null && villages.isNotEmpty;
}

/// إيجاد المحافظة التابع لها مركز معين
String? getGovernorateForDistrict(String district) {
  for (final entry in kDistrictsByGovernorate.entries) {
    if (entry.value.contains(district)) return entry.key;
  }
  return null;
}
