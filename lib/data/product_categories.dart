import 'package:flutter/material.dart';

/// Marketplace categories, grouped for the "sell a product" picker.
///
/// Each category decides which form fields make sense: units offered,
/// whether item condition (new/used) applies, and whether it is a machine
/// (specs like brand/year/hours, sold per piece, price negotiable).
class ProductCategory {
  final String name;
  final IconData icon;
  final String group;
  final List<String> units;
  final bool showCondition;
  final bool isMachinery;
  final String nameHint;

  const ProductCategory({
    required this.name,
    required this.icon,
    required this.group,
    required this.units,
    this.showCondition = false,
    this.isMachinery = false,
    this.nameHint = '',
  });
}

class ProductGroups {
  static const supplies = 'مستلزمات زراعية';
  static const machinery = 'معدات وآلات';
  static const produce = 'منتجات ومحاصيل';
  static const other = 'أخرى';

  static const all = [supplies, machinery, produce, other];
}

const List<ProductCategory> kProductCategories = [
  // -------------------------------------------------- مستلزمات زراعية
  ProductCategory(
    name: 'بذور',
    icon: Icons.spa_rounded,
    group: ProductGroups.supplies,
    units: ['كيلو', 'جرام', 'عبوة', 'شيكارة'],
    nameHint: 'مثال: بذور قمح جيزة 171',
  ),
  ProductCategory(
    name: 'أسمدة',
    icon: Icons.science_rounded,
    group: ProductGroups.supplies,
    units: ['شيكارة', 'كيلو', 'طن', 'لتر'],
    nameHint: 'مثال: سماد يوريا 46%',
  ),
  ProductCategory(
    name: 'مبيدات',
    icon: Icons.pest_control_rounded,
    group: ProductGroups.supplies,
    units: ['لتر', 'عبوة', 'كيلو', 'جرام'],
    nameHint: 'مثال: مبيد حشري لسوسة النخيل',
  ),
  ProductCategory(
    name: 'شتلات ونباتات',
    icon: Icons.local_florist_rounded,
    group: ProductGroups.supplies,
    units: ['شتلة', 'صينية', 'فسيلة', '100 شتلة'],
    nameHint: 'مثال: فسائل نخيل برحي',
  ),
  ProductCategory(
    name: 'أعلاف',
    icon: Icons.grain_rounded,
    group: ProductGroups.supplies,
    units: ['شيكارة', 'طن', 'كيلو', 'بالة'],
    nameHint: 'مثال: علف تسمين 21% بروتين',
  ),
  ProductCategory(
    name: 'تربة وخامات',
    icon: Icons.landslide_rounded,
    group: ProductGroups.supplies,
    units: ['طن', 'متر مكعب', 'شيكارة', 'نقلة'],
    nameHint: 'مثال: سماد بلدي متخمر',
  ),

  // ----------------------------------------------------- معدات وآلات
  ProductCategory(
    name: 'جرارات',
    icon: Icons.agriculture_rounded,
    group: ProductGroups.machinery,
    units: ['قطعة'],
    showCondition: true,
    isMachinery: true,
    nameHint: 'مثال: جرار ماسي فيرجسون 290',
  ),
  ProductCategory(
    name: 'آلات زراعية',
    icon: Icons.precision_manufacturing_rounded,
    group: ProductGroups.machinery,
    units: ['قطعة'],
    showCondition: true,
    isMachinery: true,
    nameHint: 'مثال: محراث حفار 7 سلاح',
  ),
  ProductCategory(
    name: 'طلمبات ومواتير',
    icon: Icons.settings_input_component_rounded,
    group: ProductGroups.machinery,
    units: ['قطعة'],
    showCondition: true,
    isMachinery: true,
    nameHint: 'مثال: طلمبة غاطسة 10 حصان',
  ),
  ProductCategory(
    name: 'معدات ري',
    icon: Icons.water_rounded,
    group: ProductGroups.machinery,
    units: ['قطعة', 'متر', 'لفة', 'طقم'],
    showCondition: true,
    nameHint: 'مثال: خرطوم تنقيط 16 مم',
  ),
  ProductCategory(
    name: 'طاقة شمسية',
    icon: Icons.solar_power_rounded,
    group: ProductGroups.machinery,
    units: ['لوح', 'قطعة', 'طقم'],
    showCondition: true,
    nameHint: 'مثال: لوح شمسي 550 وات',
  ),
  ProductCategory(
    name: 'عدد وأدوات',
    icon: Icons.handyman_rounded,
    group: ProductGroups.machinery,
    units: ['قطعة', 'طقم'],
    showCondition: true,
    nameHint: 'مثال: مقص تقليم نخيل',
  ),

  // -------------------------------------------------- منتجات ومحاصيل
  ProductCategory(
    name: 'تمور',
    icon: Icons.eco_rounded,
    group: ProductGroups.produce,
    units: ['كيلو', 'كرتونة', 'طن', 'صندوق'],
    nameHint: 'مثال: تمر سيوي نصف جاف',
  ),
  ProductCategory(
    name: 'خضروات وفاكهة',
    icon: Icons.shopping_basket_rounded,
    group: ProductGroups.produce,
    units: ['كيلو', 'صندوق', 'طن', 'قفص'],
    nameHint: 'مثال: طماطم صوب',
  ),
  ProductCategory(
    name: 'منتجات حيوانية',
    icon: Icons.egg_rounded,
    group: ProductGroups.produce,
    units: ['كيلو', 'لتر', 'رأس', 'كرتونة'],
    nameHint: 'مثال: عسل نحل طبيعي',
  ),
  ProductCategory(
    name: 'منتجات عضوية',
    icon: Icons.energy_savings_leaf_rounded,
    group: ProductGroups.produce,
    units: ['كيلو', 'عبوة', 'لتر'],
    nameHint: 'مثال: زيت زيتون عضوي',
  ),

  // ------------------------------------------------------------- أخرى
  ProductCategory(
    name: 'تعبئة وتغليف',
    icon: Icons.inventory_2_rounded,
    group: ProductGroups.other,
    units: ['قطعة', 'رزمة', 'كرتونة', 'كيلو'],
    nameHint: 'مثال: كراتين تمر 5 كيلو',
  ),
  ProductCategory(
    name: 'أخرى',
    icon: Icons.category_rounded,
    group: ProductGroups.other,
    units: ['قطعة', 'كيلو', 'عبوة'],
    showCondition: true,
  ),
];

/// Older products may use category names from before this list existed.
const Map<String, String> _legacyCategoryNames = {
  'معدات وآلات زراعية': 'آلات زراعية',
  'أدوات زراعية': 'عدد وأدوات',
  'أدوات يدوية زراعية': 'عدد وأدوات',
  'أدوات ري بالتنقيط': 'معدات ري',
  'أعلاف وتغذية حيوانية': 'أعلاف',
  'أجهزة وقياس': 'عدد وأدوات',
  'مواد تعبئة وتغليف': 'تعبئة وتغليف',
  'خدمات زراعية': 'أخرى',
  'معدات': 'آلات زراعية',
};

ProductCategory categoryByName(String? name) {
  final resolved = _legacyCategoryNames[name] ?? name;
  return kProductCategories.firstWhere(
    (c) => c.name == resolved,
    orElse: () => kProductCategories.last,
  );
}

const List<String> kProductConditions = [
  'جديد',
  'مستعمل - كالجديد',
  'مستعمل - ممتاز',
  'مستعمل - جيد',
  'مستعمل - يحتاج صيانة',
];

bool isUsedCondition(String condition) => condition.startsWith('مستعمل');

/// Spec fields shown for machinery (stored under `specs` on the product).
const Map<String, String> kMachinerySpecs = {
  'brand': 'الماركة',
  'model': 'الموديل',
  'year': 'سنة الصنع',
  'hours': 'ساعات التشغيل',
  'power': 'القدرة (حصان)',
};
