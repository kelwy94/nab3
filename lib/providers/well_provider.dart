import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/types.dart';

class WellProvider with ChangeNotifier {
  List<Well> _allWells = [];
  List<Well> _myWells = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Well> get allWells => _allWells;
  List<Well> get myWells => _myWells;
  
  // Keep get wells to point to allWells for backward compatibility if needed, 
  // but preferably screens should use myWells for Farmer, allWells for Admin.
  List<Well> get wells => _allWells; 

  bool get isLoading => _isLoading;

  WellProvider() {
    _listenToWells();
  }

  bool _forceAdminMode = false;

  void enableAdminMode() {
    _forceAdminMode = true;
    _listenToWells();
  }

  void disableAdminMode() {
    if (_forceAdminMode) {
      _forceAdminMode = false;
      _listenToWells();
    }
  }

  void _listenToWells() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _allWells = [];
      _myWells = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Check if user is admin
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((userDoc) {
      final data = userDoc.data();
      final isAdmin = _forceAdminMode || (data != null && data['role'] == UserRole.admin.toString());

      // Always listen to farmer wells to populate myWells correctly
      _listenToFarmerWells(user.uid);

      if (isAdmin) {
        _firestore.collection('wells').snapshots().listen((snapshot) {
          _allWells = snapshot.docs.map(_parseWell).toList();
          _isLoading = false;
          notifyListeners();
        });
      } else {
        _allWells = []; // Not an admin, empty allWells
      }
    });
  }

  bool _hasPendingCreation = false;
  bool get hasPendingCreation => _hasPendingCreation;

  bool _hasPendingJoin = false;
  bool get hasPendingJoin => _hasPendingJoin;

  void _listenToFarmerWells(String userId) {
    _firestore
        .collection('wells')
        .where('adminUserId', isEqualTo: userId)
        .snapshots()
        .listen((adminSnap) {
      
      _firestore
          .collection('well_members')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((memberSnap) async {
        
        List<Well> activeWellsList = [];
        bool pendingCreation = false;

        // Admin Wells
        for (var doc in adminSnap.docs) {
          final w = _parseWell(doc);
          if (w.status == WellStatus.approved) {
            activeWellsList.add(w);
          } else if (w.status == WellStatus.pending) {
            pendingCreation = true;
          }
        }

        bool pendingJoin = false;
        List<String> approvedMemberWellIds = [];
        
        for (var doc in memberSnap.docs) {
          final data = doc.data();
          if (data['status'] == 'approved') {
            approvedMemberWellIds.add(data['wellId']);
          } else if (data['status'] == 'pending') {
            pendingJoin = true;
          }
        }

        if (approvedMemberWellIds.isNotEmpty) {
          if (approvedMemberWellIds.length > 10) {
            approvedMemberWellIds = approvedMemberWellIds.sublist(0, 10);
          }
          final memberWellsSnap = await _firestore
              .collection('wells')
              .where(FieldPath.documentId, whereIn: approvedMemberWellIds)
              .get();
          activeWellsList.addAll(memberWellsSnap.docs.map(_parseWell));
        }

        // Deduplicate
        final seen = <String>{};
        activeWellsList.retainWhere((w) {
          if (seen.contains(w.id)) return false;
          seen.add(w.id);
          return true;
        });

        _myWells = activeWellsList;
        _hasPendingCreation = pendingCreation;
        _hasPendingJoin = pendingJoin;
        _isLoading = false;
        notifyListeners();
      });
    });
  }

  Well _parseWell(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Well(
      id: doc.id,
      adminUserId: data['adminUserId'] ?? '',
      wellName: data['wellName'] ?? '',
      location: Map<String, double>.from(data['location'] ?? {}),
      depthMeters: (data['depthMeters'] ?? 0.0).toDouble(),
      irrigatedAreaFeddan: (data['irrigatedAreaFeddan'] ?? 0.0).toDouble(),
      waterOutput: WaterOutput.values.firstWhere(
        (e) => e.toString() == data['waterOutput'],
        orElse: () => WaterOutput.medium,
      ),
      participantCount: data['participantCount'] ?? 1,
      flowRateM3PerHour: data['flowRateM3PerHour']?.toDouble(),
      fairnessRule: FairnessRule.values.firstWhere(
        (e) => e.toString() == data['fairnessRule'],
        orElse: () => FairnessRule.proportional,
      ),
      allowedDays: List<String>.from(data['allowedDays'] ?? []),
      allowedHours: Map<String, String>.from(data['allowedHours'] ?? {}),
      slotDuration: data['slotDuration'] ?? 0,
      hoursPerPerson: (data['hoursPerPerson'] ?? 1.0).toDouble(),
      irrigationFrequencyDays: data['irrigationFrequencyDays'] ?? 1,
      status: WellStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => WellStatus.approved,
      ),
      pendingEdits: data['pendingEdits'] != null ? Map<String, dynamic>.from(data['pendingEdits']) : null,
    );
  }

  Future<void> updateWellStatus(String wellId, WellStatus status) async {
    try {
      await _firestore.collection('wells').doc(wellId).update({
        'status': status.toString(),
      });
    } catch (e) {
      debugPrint('Error updating well status: $e');
      rethrow;
    }
  }

  Future<void> requestWellEdit(String wellId, Map<String, dynamic> edits) async {
    try {
      await _firestore.collection('wells').doc(wellId).update({
        'pendingEdits': edits,
      });
    } catch (e) {
      debugPrint('Error requesting well edit: $e');
      rethrow;
    }
  }

  Future<void> approveWellEdit(String wellId, Map<String, dynamic> edits) async {
    try {
      final updates = Map<String, dynamic>.from(edits);
      updates['pendingEdits'] = FieldValue.delete();
      await _firestore.collection('wells').doc(wellId).update(updates);
    } catch (e) {
      debugPrint('Error approving well edit: $e');
      rethrow;
    }
  }

  Future<void> rejectWellEdit(String wellId) async {
    try {
      await _firestore.collection('wells').doc(wellId).update({
        'pendingEdits': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error rejecting well edit: $e');
      rethrow;
    }
  }

  Future<bool> inviteParticipantByPhone(String wellId, String phone) async {
    try {
      final query = await _firestore.collection('users').where('phone', isEqualTo: phone).get();
      if (query.docs.isEmpty) return false;
      
      final userId = query.docs.first.id;
      
      // Check if already requested
      final existing = await _firestore.collection('well_members')
        .where('wellId', isEqualTo: wellId)
        .where('userId', isEqualTo: userId)
        .get();
        
      if (existing.docs.isNotEmpty) return true; // Already invited/member
      
      await _firestore.collection('well_members').add({
        'wellId': wellId,
        'userId': userId,
        'status': 'pending',
        'landAreaFeddan': 0.0,
        'crops': [],
      });
      return true;
    } catch (e) {
      debugPrint('Error inviting participant: $e');
      rethrow;
    }
  }

  Future<void> addWell(Well well) async {
    try {
      await _firestore.collection('wells').add({
        'adminUserId': well.adminUserId,
        'wellName': well.wellName,
        'location': well.location,
        'depthMeters': well.depthMeters,
        'irrigatedAreaFeddan': well.irrigatedAreaFeddan,
        'waterOutput': well.waterOutput.toString(),
        'participantCount': well.participantCount,
        'flowRateM3PerHour': well.flowRateM3PerHour,
        'fairnessRule': well.fairnessRule.toString(),
        'allowedDays': well.allowedDays,
        'allowedHours': well.allowedHours,
        'slotDuration': well.slotDuration,
        'hoursPerPerson': well.hoursPerPerson,
        'irrigationFrequencyDays': well.irrigationFrequencyDays,
        'status': WellStatus.pending.toString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding well: $e');
      rethrow;
    }
  }
}
