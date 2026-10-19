import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/land_listing.dart';

/// Firestore access for the land marketplace.
///
/// Queries use a single equality filter each and are sorted on the client,
/// so no composite indexes are needed.
class LandService {
  LandService._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection('land_listings');
  static CollectionReference<Map<String, dynamic>> get _inquiries =>
      _db.collection('land_inquiries');

  /// Max photos per listing. Images fall back to inline base64 when Firebase
  /// Storage isn't available, and a Firestore doc is capped at 1 MB.
  static const maxPhotos = 6;
  static const maxOwnershipDocs = 3;

  // ------------------------------------------------------------- listings

  static Stream<List<LandListing>> approvedListings() => _listings
      .where('status', isEqualTo: LandStatus.approved)
      .snapshots()
      .map(_toSortedList);

  static Stream<List<LandListing>> myListings(String ownerId) => _listings
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map(_toSortedList);

  static Stream<List<LandListing>> pendingListings() => _listings
      .where('status', isEqualTo: LandStatus.pending)
      .snapshots()
      .map(_toSortedList);

  static Stream<LandListing?> listing(String id) => _listings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? LandListing.fromDoc(d) : null);

  static List<LandListing> _toSortedList(
      QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map(LandListing.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Creates or updates a listing. New listings get a fresh id; [existingId]
  /// keeps the original createdAt. Either way the listing returns to review.
  static Future<String> saveListing(LandListing listing,
      {String? existingId, List<String>? ownershipDocs}) async {
    final ref = existingId != null ? _listings.doc(existingId) : _listings.doc();
    final data = listing.toOwnerWrite();
    if (existingId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(data);
    } else {
      data['rejectionReason'] = FieldValue.delete();
      await ref.update(data);
    }
    if (ownershipDocs != null) {
      await ref.collection('private').doc('ownership').set({
        'ownerId': listing.ownerId,
        'documents': ownershipDocs,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return ref.id;
  }

  static Future<void> markSold(String id, {bool sold = true}) =>
      _listings.doc(id).update({
        'status': sold ? LandStatus.sold : LandStatus.approved,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteListing(String id) async {
    await _listings.doc(id).collection('private').doc('ownership').delete();
    await _listings.doc(id).delete();
  }

  static Future<List<String>> ownershipDocs(String listingId) async {
    final doc = await _listings
        .doc(listingId)
        .collection('private')
        .doc('ownership')
        .get();
    return List<String>.from(doc.data()?['documents'] ?? const []);
  }

  // ---------------------------------------------------------------- admin

  static Future<void> review(LandListing listing,
      {required bool approve, String? reason}) async {
    await _listings.doc(listing.id).update({
      'status': approve ? LandStatus.approved : LandStatus.rejected,
      'rejectionReason': approve ? FieldValue.delete() : (reason ?? ''),
      if (approve) 'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection('users')
        .doc(listing.ownerId)
        .collection('notifications')
        .add({
      'title': approve ? 'تم نشر أرضك 🎉' : 'لم يتم قبول إعلان الأرض',
      'body': approve
          ? 'إعلان "${listing.title}" ظاهر الآن في سوق الأراضي.'
          : 'إعلان "${listing.title}" يحتاج تعديل: ${reason ?? ''}',
      'type': 'land_review',
      'listingId': listing.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------ inquiries

  static Future<void> sendInquiry({
    required LandListing listing,
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
    required String message,
    DateTime? visitDate,
  }) async {
    await _inquiries.add({
      'listingId': listing.id,
      'listingTitle': listing.title,
      'ownerId': listing.ownerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'message': message,
      'visitDate': visitDate != null ? Timestamp.fromDate(visitDate) : null,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection('users')
        .doc(listing.ownerId)
        .collection('notifications')
        .add({
      'title': 'طلب معاينة جديد على أرضك',
      'body': '$buyerName مهتم بـ "${listing.title}"',
      'type': 'land_inquiry',
      'listingId': listing.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<LandInquiry>> inquiriesForOwner(String ownerId) =>
      _inquiries
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map(_toInquiries);

  static Stream<List<LandInquiry>> inquiriesByBuyer(String buyerId) =>
      _inquiries
          .where('buyerId', isEqualTo: buyerId)
          .snapshots()
          .map(_toInquiries);

  static List<LandInquiry> _toInquiries(
      QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map(LandInquiry.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> setInquiryStatus(String id, String status) =>
      _inquiries.doc(id).update({'status': status});

  // ------------------------------------------------------------- favorites

  static CollectionReference<Map<String, dynamic>> _saved(String uid) =>
      _db.collection('users').doc(uid).collection('saved_lands');

  static Stream<Set<String>> savedIds(String uid) => _saved(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  static Future<void> toggleSaved(String uid, String listingId, bool save) =>
      save
          ? _saved(uid)
              .doc(listingId)
              .set({'savedAt': FieldValue.serverTimestamp()})
          : _saved(uid).doc(listingId).delete();

  // ---------------------------------------------------------------- images

  /// Uploads to Firebase Storage, falling back to inline base64 (the same
  /// fallback the rest of the app uses) when Storage isn't set up.
  static Future<String> uploadImage(Uint8List bytes, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 25));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Land image upload fell back to base64: $e');
      return 'base64,${base64Encode(bytes)}';
    }
  }

  /// Rough size of inline images, used to keep docs under Firestore's 1 MB.
  static int inlineBytes(List<String> images) => images
      .where((s) => !s.startsWith('http'))
      .fold(0, (total, s) => total + s.length);
}

class LandInquiry {
  final String id;
  final String listingId;
  final String listingTitle;
  final String ownerId;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String message;
  final DateTime? visitDate;
  final String status;
  final DateTime createdAt;

  const LandInquiry({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.ownerId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.message,
    this.visitDate,
    required this.status,
    required this.createdAt,
  });

  factory LandInquiry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LandInquiry(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      ownerId: d['ownerId'] ?? '',
      buyerId: d['buyerId'] ?? '',
      buyerName: d['buyerName'] ?? '',
      buyerPhone: d['buyerPhone'] ?? '',
      message: d['message'] ?? '',
      visitDate: (d['visitDate'] as Timestamp?)?.toDate(),
      status: d['status'] ?? 'new',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
