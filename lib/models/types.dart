enum UserRole {
  farmer,
  worker,
  deliveryWorker,
  seller,
  equipmentOwner,
  investor,
  admin,
  engineer,
  generalUser,
}

enum ConsultationStatus {
  pendingEngineerApproval,
  rejected,
  pendingPriceApproval,
  negotiatingTime,
  confirmed,
  completed,
  rated,
}

class ConsultationRequest {
  final String id;
  final String farmerUserId;
  final String farmerName;
  final String engineerUserId;
  final String engineerName;
  final String serviceType;
  final String? problemDescription;
  final ConsultationStatus status;
  final double? agreedPrice;
  final DateTime? proposedDate;
  final DateTime? farmerProposedDate;
  final DateTime? finalAgreedDate;
  final double? rating;
  final DateTime createdAt;

  ConsultationRequest({
    required this.id,
    required this.farmerUserId,
    required this.farmerName,
    required this.engineerUserId,
    required this.engineerName,
    required this.serviceType,
    this.problemDescription,
    this.status = ConsultationStatus.pendingEngineerApproval,
    this.agreedPrice,
    this.proposedDate,
    this.farmerProposedDate,
    this.finalAgreedDate,
    this.rating,
    required this.createdAt,
  });
}

enum WaterOutput { low, medium, high }

enum FairnessRule { proportional, equal, manual }

enum BidStatus {
  pending,
  counterOffered,
  accepted,
  rejected,
}

enum JobStatus {
  requested,
  accepted,
  inProgress,
  completed,
  paid,
  reviewed,
  disputed
}

enum OrderStatus {
  placed,
  deliveryAccepted,
  preparing,
  outForDelivery,
  completed
}

enum SwapStatus { pending, accepted, rejected }

enum AccountStatus { pending, approved, rejected }

enum WellStatus { pending, approved, rejected }

enum RewardStatus { pendingActivity, underReview, paid }

enum PaymentMethod { vodafoneCash, instaPay, bankAccount }

class User {
  final String id;
  final UserRole role;
  final String fullName;
  final String phone;
  final String? email;
  final String nationalIdHash;
  final String address;
  final DateTime createdAt;
  final AccountStatus status;
  final Map<String, dynamic>? extraData;
  final String? profileImageBase64;
  final String? profileImageUrl;
  final PaymentMethod? paymentMethod;
  final String? paymentDetails; // phone number or bank account
  final String? referralCode;
  final String? referredBy;

  User({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.email,
    required this.nationalIdHash,
    required this.address,
    required this.createdAt,
    this.status = AccountStatus.approved,
    this.extraData,
    this.profileImageBase64,
    this.profileImageUrl,
    this.paymentMethod,
    this.paymentDetails,
    this.referralCode,
    this.referredBy,
  });

  User copyWith({
    String? id,
    UserRole? role,
    String? fullName,
    String? phone,
    String? email,
    String? nationalIdHash,
    String? address,
    DateTime? createdAt,
    AccountStatus? status,
    Map<String, dynamic>? extraData,
    String? profileImageBase64,
    String? profileImageUrl,
    PaymentMethod? paymentMethod,
    String? paymentDetails,
    String? referralCode,
    String? referredBy,
  }) {
    return User(
      id: id ?? this.id,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nationalIdHash: nationalIdHash ?? this.nationalIdHash,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      extraData: extraData ?? this.extraData,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'nationalIdHash': nationalIdHash,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'extraData': extraData,
      'profileImageBase64': profileImageBase64,
      'paymentMethod': paymentMethod?.name,
      'paymentDetails': paymentDetails,
      'referralCode': referralCode,
      'referredBy': referredBy,
    };
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.vodafoneCash:
        return 'فودافون كاش';
      case PaymentMethod.instaPay:
        return 'إنستاباي';
      case PaymentMethod.bankAccount:
        return 'حساب بنكي';
      default:
        return 'غير محدد';
    }
  }
}

class FarmerProfile {
  final String userId;
  final double landAreaFeddan;
  final List<String> crops;
  final Map<String, double> farmLocation; // {lat, lng}

  FarmerProfile({
    required this.userId,
    required this.landAreaFeddan,
    required this.crops,
    required this.farmLocation,
  });
}

class WorkerProfile {
  final String userId;
  final List<String> skills;
  final double? hourlyRate;
  final double? dailyRate;
  final String availability; // Simple string or JSON
  final double serviceRadiusKm;
  final double ratingAvg;

  WorkerProfile({
    required this.userId,
    required this.skills,
    this.hourlyRate,
    this.dailyRate,
    required this.availability,
    required this.serviceRadiusKm,
    this.ratingAvg = 0.0,
  });
}

class DeliveryWorkerProfile {
  final String userId;
  final String idCardImageBase64;
  final String vehicleType; // tuktuk, motorcycle, scooter, bicycle
  final double serviceRadiusKm;
  final double ratingAvg;

  DeliveryWorkerProfile({
    required this.userId,
    required this.idCardImageBase64,
    required this.vehicleType,
    required this.serviceRadiusKm,
    this.ratingAvg = 0.0,
  });
}

class InvestorProfile {
  final String userId;
  final String companyName;
  final double totalAreaFeddan;
  final double plantedAreaFeddan;
  final List<String> crops;
  final List<String> irrigationMethods;
  final List<Map<String, double>> farmLocations;

  InvestorProfile({
    required this.userId,
    required this.companyName,
    required this.totalAreaFeddan,
    required this.plantedAreaFeddan,
    required this.crops,
    required this.irrigationMethods,
    required this.farmLocations,
  });
}

class SellerProfile {
  final String userId;
  final String shopName;
  final String commercialRegisterImageUrl;
  final Map<String, double> shopLocation;
  final bool deliveryAvailable;
  final List<String> categories;
  final bool verificationStatus;

  SellerProfile({
    required this.userId,
    required this.shopName,
    required this.commercialRegisterImageUrl,
    required this.shopLocation,
    required this.deliveryAvailable,
    required this.categories,
    this.verificationStatus = false,
  });
}

class EquipmentOwnerProfile {
  final String userId;
  final double serviceRadiusKm;

  EquipmentOwnerProfile({
    required this.userId,
    required this.serviceRadiusKm,
  });
}

class Equipment {
  final String id;
  final String ownerUserId;
  final String type;
  final String specs;
  final String? photoUrl;
  final double? hourlyRate;
  final double? dailyRate;
  final String availability;

  Equipment({
    required this.id,
    required this.ownerUserId,
    required this.type,
    required this.specs,
    this.photoUrl,
    this.hourlyRate,
    this.dailyRate,
    required this.availability,
  });
}

class Well {
  final String id;
  final String adminUserId;
  final String wellName;
  final String? district;
  final Map<String, double> location;
  final double depthMeters;
  final double irrigatedAreaFeddan;
  final WaterOutput? waterOutput;
  final int participantCount;
  final double? flowRateM3PerHour;
  final List<String> allowedDays;
  final Map<String, String> allowedHours; // {start: "HH:mm", end: "HH:mm"}
  final int slotDuration;
  final double hoursPerPerson;
  final int irrigationFrequencyDays;
  final FairnessRule fairnessRule;
  final WellStatus status;
  final Map<String, dynamic>? pendingEdits;
  final DateTime? nextIrrigationDate;

  Well({
    required this.id,
    required this.adminUserId,
    required this.wellName,
    this.district,
    required this.location,
    required this.depthMeters,
    required this.irrigatedAreaFeddan,
    this.waterOutput,
    this.participantCount = 1,
    this.flowRateM3PerHour,
    required this.allowedDays,
    required this.allowedHours,
    required this.slotDuration,
    this.hoursPerPerson = 1.0,
    this.irrigationFrequencyDays = 1,
    required this.fairnessRule,
    this.status = WellStatus.approved,
    this.pendingEdits,
    this.nextIrrigationDate,
  });
}

class WellMember {
  final String id;
  final String wellId;
  final String userId;
  final String status; // pending, approved, rejected
  final double landAreaFeddan;
  final List<String> crops;
  final Map<String, dynamic>? manualSchedule;
  final DateTime? nextIrrigationDate;

  WellMember({
    required this.id,
    required this.wellId,
    required this.userId,
    required this.status,
    required this.landAreaFeddan,
    required this.crops,
    this.manualSchedule,
    this.nextIrrigationDate,
  });
}

class IrrigationSchedule {
  final String id;
  final String wellId;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final String publishedBy;
  final DateTime publishedAt;

  IrrigationSchedule({
    required this.id,
    required this.wellId,
    required this.cycleStart,
    required this.cycleEnd,
    required this.publishedBy,
    required this.publishedAt,
  });
}

class IrrigationSlot {
  final String id;
  final String scheduleId;
  final String wellId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // planned, swapped, completed

  IrrigationSlot({
    required this.id,
    required this.scheduleId,
    required this.wellId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });
}

class SwapRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String slotId;
  final String? proposedSlotId;
  final SwapStatus status;

  SwapRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.slotId,
    this.proposedSlotId,
    required this.status,
  });
}

class JobBid {
  final String id;
  final String jobId;
  final String workerUserId;
  final String workerName;
  final double currentPrice;
  final BidStatus status;
  final String lastProposedByUserId;
  final DateTime createdAt;

  JobBid({
    required this.id,
    required this.jobId,
    required this.workerUserId,
    required this.workerName,
    required this.currentPrice,
    required this.status,
    required this.lastProposedByUserId,
    required this.createdAt,
  });
}

class Job {
  final String id;
  final String requesterUserId;
  final String? assignedUserId;
  final String type; // worker, equipment
  final String serviceType;
  final Map<String, double> location;
  final DateTime startTime;
  final DateTime endTime;
  final JobStatus status;
  final double? price;
  final String notes;
  final String? address;
  final double? workerRating;
  final String? disputeNote;
  final String? paymentRequestDetails;

  Job({
    required this.id,
    required this.requesterUserId,
    this.assignedUserId,
    required this.type,
    required this.serviceType,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.price,
    required this.notes,
    this.address,
    this.workerRating,
    this.disputeNote,
    this.paymentRequestDetails,
  });
}

class Order {
  final String id;
  final String buyerUserId;
  final String sellerUserId;
  final String? deliveryWorkerId;
  final OrderStatus status;
  final double total;
  final double deliveryFee;
  final String deliveryMethod; // delivery, pickup
  final String? paymentMethod;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerUserId,
    required this.sellerUserId,
    this.deliveryWorkerId,
    required this.status,
    required this.total,
    required this.deliveryFee,
    required this.deliveryMethod,
    this.paymentMethod,
    required this.createdAt,
  });
}

class OrderItem {
  final String id;
  final String orderId;
  final String itemName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
  });
}

class CatalogItem {
  final String id;
  final String sellerUserId;
  final String name;
  final String category;
  final String unit;
  final double price;
  final bool stockStatus;
  final String? photoUrl;
  final String? description;
  final double ratingAvg;
  final int ratingCount;
  final bool isApproved;
  final double discountPercentage;
  final List<String> additionalPhotos; // up to 5 photos
  final double quantity; // stock quantity
  final String address; // product location/address
  final String condition; // new / used
  final double minOrderQuantity;
  final bool deliveryAvailable;
  final bool negotiable;
  final Map<String, String> specs; // machinery: brand, model, year, hours, power

  CatalogItem({
    required this.id,
    required this.sellerUserId,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.stockStatus,
    this.photoUrl,
    this.description,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.isApproved = true,
    this.discountPercentage = 0.0,
    this.additionalPhotos = const [],
    this.quantity = 0.0,
    this.address = '',
    this.condition = 'جديد',
    this.minOrderQuantity = 1.0,
    this.deliveryAvailable = false,
    this.negotiable = false,
    this.specs = const {},
  });

  /// Builds an item from a `catalog` document. Shared by every screen and
  /// provider that reads the catalog so no field is silently dropped.
  factory CatalogItem.fromMap(String id, Map<String, dynamic> data) {
    final rawSpecs = data['specs'];
    return CatalogItem(
      id: id,
      sellerUserId: data['sellerUserId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? 'أخرى',
      unit: data['unit'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      stockStatus: data['stockStatus'] ?? true,
      photoUrl: data['photoUrl'],
      description: data['description'],
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      isApproved: data['isApproved'] ?? true,
      discountPercentage:
          (data['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      additionalPhotos: List<String>.from(data['additionalPhotos'] ?? []),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      address: data['address'] ?? '',
      condition: data['condition'] ?? 'جديد',
      minOrderQuantity: (data['minOrderQuantity'] as num?)?.toDouble() ?? 1.0,
      deliveryAvailable: data['deliveryAvailable'] ?? false,
      negotiable: data['negotiable'] ?? false,
      specs: rawSpecs is Map
          ? rawSpecs.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  List<String> get allPhotos => [
        if (photoUrl != null && photoUrl!.isNotEmpty) photoUrl!,
        ...additionalPhotos.where((p) => p.isNotEmpty),
      ];
}

class Payment {
  final String id;
  final String payerUserId;
  final String payeeUserId;
  final double amount;
  final String status;
  final String relatedType; // job, order
  final String relatedId;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.payerUserId,
    required this.payeeUserId,
    required this.amount,
    required this.status,
    required this.relatedType,
    required this.relatedId,
    required this.createdAt,
  });
}

class Review {
  final String id;
  final String reviewerUserId;
  final String reviewedUserId;
  final int stars;
  final String comment;
  final String relatedType;
  final String relatedId;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.reviewerUserId,
    required this.reviewedUserId,
    required this.stars,
    required this.comment,
    required this.relatedType,
    required this.relatedId,
    required this.createdAt,
  });
}

enum ComplaintStatus { newComplaint, reviewing, resolved }

class Complaint {
  final String id;
  final String
      type; // e.g., 'irrigation_conflict', 'service_unpaid', 'bad_service'
  final String fromUserId;
  final String? targetUserId;
  final String? relatedId; // wellId, jobId, etc.
  final String details;
  final ComplaintStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? extraData; // e.g. conflictingDate

  Complaint({
    required this.id,
    required this.type,
    required this.fromUserId,
    this.targetUserId,
    this.relatedId,
    required this.details,
    this.status = ComplaintStatus.newComplaint,
    required this.createdAt,
    this.extraData,
  });
}

const List<String> kWorkerSpecializations = [
  'عامل ري',
  'عامل نخيل',
  'عامل تقليم وتنظيف حشائش',
  'عامل جني محصول',
  'عامل بناء حظائر',
  'عامل لأعمال البرسيم (حش - لم)',
  'عامل تقطيع حطب',
  'عامل جني البلح',
];

class ReferralReward {
  final String id;
  final String inviterId;
  final String inviteeId;
  final double amount;
  final RewardStatus status;
  final DateTime createdAt;

  ReferralReward({
    required this.id,
    required this.inviterId,
    required this.inviteeId,
    required this.amount,
    this.status = RewardStatus.pendingActivity,
    required this.createdAt,
  });
}
