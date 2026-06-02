import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/types.dart';

class WellProvider with ChangeNotifier {
  List<Well> _allWells = [];
  List<Well> _ownedWells = [];
  List<Well> _joinedWells = [];
  bool _hasPendingCreation = false;
  bool _hasPendingJoin = false;

  List<Well> get allWells => _allWells;
  List<Well> get myWells => [..._ownedWells, ..._joinedWells];
  List<Well> get wells => _allWells;

  bool _isLoading = false;
  bool _disposed = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _adminWellsSub;
  StreamSubscription? _myAdminWellsSub;
  StreamSubscription? _myMemberWellsSub;
  StreamSubscription? _authStateSub;

  bool get isLoading => _isLoading;
  bool get hasPendingCreation => _hasPendingCreation;
  bool get hasPendingJoin => _hasPendingJoin;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    _cancelAllSubs();
    _authStateSub?.cancel();
    super.dispose();
  }

  void _cancelAllSubs() {
    _adminWellsSub?.cancel();
    _myAdminWellsSub?.cancel();
    _myMemberWellsSub?.cancel();
    _adminWellsSub = null;
    _myAdminWellsSub = null;
    _myMemberWellsSub = null;
  }

  WellProvider() {
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_disposed) {
        _listenToWells();
      }
    });
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
    _cancelAllSubs();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _allWells = [];
      _ownedWells = [];
      _joinedWells = [];
      _isLoading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    _isLoading = true;
    if (!_disposed) notifyListeners();

    // 1. Listen to OWN wells (as Admin)
    _myAdminWellsSub = _firestore
        .collection('wells')
        .where('adminUserId', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
      _ownedWells = snap.docs.map(_parseWell).where((w) => w.status == WellStatus.approved).toList();
      _hasPendingCreation = snap.docs.any((doc) => _parseWell(doc).status == WellStatus.pending);
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }, onError: (e) => _handleError(e));

    // 2. Listen to MEMBERSHIPS
    _myMemberWellsSub = _firestore
        .collection('well_members')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) => _updateJoinedWells(snap, user.uid), onError: (e) => _handleError(e));

    // 3. Admin logic (All Wells) - Use a more reliable and faster initialization
    if (_forceAdminMode) {
      _startAdminListener();
    } else {
      _firestore.collection('users').doc(user.uid).get().then((userDoc) {
        if (_disposed || _forceAdminMode) return;
        final data = userDoc.data();
        final isAdmin = data != null && (data['role'] == 'admin' || data['role'] == 'UserRole.admin');
        if (isAdmin) {
          _startAdminListener();
        }
      });
    }
  }

  void _startAdminListener() {
    if (_adminWellsSub != null) return;
    _adminWellsSub = _firestore.collection('wells').snapshots().listen((snapshot) {
      List<Well> parsedWells = [];
      for (var doc in snapshot.docs) {
        try {
          parsedWells.add(_parseWell(doc));
        } catch (e) {
          debugPrint('Error parsing well ${doc.id}: $e');
        }
      }
      _allWells = parsedWells;
      if (!_disposed) notifyListeners();
    }, onError: (e) => _handleError(e));
  }

  // Handle joined wells separately to manage details fetch
  Future<void> _updateJoinedWells(QuerySnapshot membershipSnap, String userId) async {
    try {
      List<String> approvedWellIds = [];
      bool pendingFlag = false;

      for (var doc in membershipSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        if (status == 'approved') {
          approvedWellIds.add(data['wellId']);
        } else if (status == 'pending') {
          pendingFlag = true;
        }
      }

      _hasPendingJoin = pendingFlag;

      if (approvedWellIds.isEmpty) {
        _joinedWells = [];
        if (!_disposed) notifyListeners();
        return;
      }

      // Fetch well details for the joins
      final wellsSnap = await _firestore
          .collection('wells')
          .where(FieldPath.documentId, whereIn: approvedWellIds.take(10).toList())
          .get(const GetOptions(source: Source.serverAndCache));

      _joinedWells = wellsSnap.docs.map(_parseWell).toList();
      if (!_disposed) notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(dynamic e) {
    debugPrint('WELL_PROVIDER: Error: $e');
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }

  // Robust parser for Enums that handles both full (toString) and short (name) strings
  T _parseEnum<T>(List<T> values, dynamic dataValue, T defaultValue) {
    if (dataValue == null) return defaultValue;
    final String valStr = dataValue.toString();
    return values.firstWhere(
      (e) {
        final String eStr = e.toString();
        return eStr == valStr || eStr.split('.').last == valStr;
      },
      orElse: () => defaultValue,
    );
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
      waterOutput: _parseEnum(WaterOutput.values, data['waterOutput'], WaterOutput.medium),
      participantCount: data['participantCount'] ?? 1,
      flowRateM3PerHour: data['flowRateM3PerHour']?.toDouble(),
      fairnessRule: _parseEnum(FairnessRule.values, data['fairnessRule'], FairnessRule.proportional),
      allowedDays: List<String>.from(data['allowedDays'] ?? []),
      allowedHours: Map<String, String>.from(data['allowedHours'] ?? {}),
      slotDuration: data['slotDuration'] ?? 0,
      hoursPerPerson: (data['hoursPerPerson'] ?? 1.0).toDouble(),
      irrigationFrequencyDays: data['irrigationFrequencyDays'] ?? 1,
      status: _parseEnum(WellStatus.values, data['status'], WellStatus.approved),
      pendingEdits: data['pendingEdits'] != null
          ? Map<String, dynamic>.from(data['pendingEdits'])
          : null,
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

  Future<void> requestWellEdit(
      String wellId, Map<String, dynamic> edits) async {
    try {
      await _firestore.collection('wells').doc(wellId).update({
        'pendingEdits': edits,
      });
    } catch (e) {
      debugPrint('Error requesting well edit: $e');
      rethrow;
    }
  }

  Future<void> approveWellEdit(
      String wellId, Map<String, dynamic> edits) async {
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
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();
      if (query.docs.isEmpty) return false;

      final userId = query.docs.first.id;

      // Check if already requested
      final existing = await _firestore
          .collection('well_members')
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
