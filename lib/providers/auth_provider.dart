import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../models/types.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  List<User> _allUsers = [];
  bool _isLoading = false;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _usersSubscription;

  User? get user => _user;
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
    _listenToUsers();
  }

  void _init() {
    _auth.authStateChanges().listen((fb_auth.User? fbUser) async {
      if (fbUser == null) {
        if (_user?.role != UserRole.admin) {
          _user = null;
          notifyListeners();
        }
      } else {
        await _fetchUserProfile(fbUser.uid);
      }
    });
  }

  void _listenToUsers() {
    // Cancel previous subscription if any
    _usersSubscription?.cancel();
    _usersSubscription =
        _firestore.collection('users').snapshots().listen((snapshot) {
      _allUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        return User(
          id: doc.id,
          role: UserRole.values.firstWhere(
            (e) =>
                e.toString() == data['role'] ||
                e.toString().split('.').last == data['role'],
            orElse: () => UserRole.worker,
          ),
          fullName: data['fullName'] ?? '',
          phone: data['phone'] ?? '',
          nationalIdHash: data['nationalIdHash'] ?? '',
          address: data['address'] ?? '',
          status: AccountStatus.values.firstWhere(
            (e) =>
                e.toString() == data['status'] ||
                e.toString().split('.').last == data['status'],
            orElse: () => AccountStatus.approved,
          ),
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          extraData: data['extraData'],
          profileImageBase64: data['profileImageBase64'],
          paymentMethod: data['paymentMethod'] != null
              ? PaymentMethod.values.firstWhere(
                  (e) => e.name == data['paymentMethod'],
                  orElse: () => PaymentMethod.vodafoneCash,
                )
              : null,
          paymentDetails: data['paymentDetails'],
        );
      }).toList();
      debugPrint(
          'AUTH_PROVIDER: Received ${_allUsers.length} users from Firestore');
      // Defer to avoid setState during build
      Future.microtask(notifyListeners);
    }, onError: (error) {
      debugPrint('AUTH_PROVIDER: Firestore Error: $error');
    });
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _user = User(
          id: uid,
          role: UserRole.values.firstWhere(
            (e) =>
                e.toString() == data['role'] ||
                e.toString().split('.').last == data['role'],
            orElse: () => UserRole.worker,
          ),
          fullName: data['fullName'] ?? '',
          phone: data['phone'] ?? '',
          nationalIdHash: data['nationalIdHash'] ?? '',
          address: data['address'] ?? '',
          status: AccountStatus.values.firstWhere(
            (e) =>
                e.toString() == data['status'] ||
                e.toString().split('.').last == data['status'],
            orElse: () => AccountStatus.approved,
          ),
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          extraData: data['extraData'],
          profileImageBase64: data['profileImageBase64'],
          paymentMethod: data['paymentMethod'] != null
              ? PaymentMethod.values.firstWhere(
                  (e) => e.name == data['paymentMethod'],
                  orElse: () => PaymentMethod.vodafoneCash,
                )
              : null,
          paymentDetails: data['paymentDetails'],
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup(User user, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final email = "${user.phone}@naba.app";
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // Determine initial status based on role
      final initialStatus = (user.role == UserRole.worker ||
              user.role == UserRole.seller ||
              user.role == UserRole.equipmentOwner)
          ? AccountStatus.pending
          : AccountStatus.approved;

      await _firestore.collection('users').doc(uid).set({
        'role': user.role.toString(),
        'fullName': user.fullName,
        'phone': user.phone,
        'nationalIdHash': user.nationalIdHash,
        'address': user.address,
        'status': initialStatus.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'extraData': user.extraData,
        'profileImageBase64': user.profileImageBase64,
        'paymentMethod': user.paymentMethod?.name,
        'paymentDetails': user.paymentDetails,
      });
      _user = user.copyWith(id: uid, status: initialStatus);
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserStatus(String uid, Map<String, dynamic> updates,
      {String? adminNote}) async {
    try {
      if (adminNote != null && adminNote.isNotEmpty) {
        // Fetch current extraData to append the note
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final extraData = Map<String, dynamic>.from(data['extraData'] ?? {});
          extraData['adminNote'] = adminNote;
          updates['extraData'] = extraData;
        }
      }
      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(
      String fullName, String phone, String address) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.id).update({
        'fullName': fullName,
        'phone': phone,
        'address': address,
      });
      _user =
          _user!.copyWith(fullName: fullName, phone: phone, address: address);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfileImage(String base64Image) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.id).update({
        'profileImageBase64': base64Image,
      });
      _user = _user!.copyWith(profileImageBase64: base64Image);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_user?.role == UserRole.admin) {
      _user = null;
    } else {
      await _auth.signOut();
    }
    notifyListeners();
  }

  Future<void> toggleAvailability(bool isAvailable) async {
    if (_user == null) return;
    try {
      final extraData = Map<String, dynamic>.from(_user!.extraData ?? {});
      extraData['isAvailable'] = isAvailable;
      await _firestore.collection('users').doc(_user!.id).update({
        'extraData': extraData,
      });
      _user = _user!.copyWith(extraData: extraData);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling availability: $e');
    }
  }

  Future<User?> fetchUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return User(
          id: uid,
          role: UserRole.values.firstWhere((e) => e.toString() == data['role']),
          fullName: data['fullName'] ?? '',
          phone: data['phone'] ?? '',
          nationalIdHash: data['nationalIdHash'] ?? '',
          address: data['address'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          extraData: data['extraData'],
          profileImageBase64: data['profileImageBase64'],
          paymentMethod: data['paymentMethod'] != null
              ? PaymentMethod.values.firstWhere(
                  (e) => e.name == data['paymentMethod'],
                  orElse: () => PaymentMethod.vodafoneCash,
                )
              : null,
          paymentDetails: data['paymentDetails'],
        );
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
    return null;
  }

  Future<void> loginAsAdmin() async {
    try {
      await _auth.signInAnonymously();

      _user = User(
        id: 'admin_123',
        role: UserRole.admin,
        fullName: 'مدير النظام',
        phone: '01000000000',
        nationalIdHash: 'admin_hash',
        address: 'المقر الرئيسي',
        createdAt: DateTime.now(),
      );
      debugPrint('AUTH_PROVIDER: Logged in as Admin (Anonymous Session).');
      notifyListeners();
      // Re-establish Firestore listener now that we have auth
      _listenToUsers();
    } catch (e) {
      debugPrint('AUTH_PROVIDER: Anonymous Sign-in failed: $e');
      _user = User(
        id: 'admin_123',
        role: UserRole.admin,
        fullName: 'مدير النظام',
        phone: '01000000000',
        nationalIdHash: 'admin_hash',
        address: 'المقر الرئيسي',
        createdAt: DateTime.now(),
      );
      notifyListeners();
      _listenToUsers();
    }
  }

  Future<void> seedDemoData() async {
    // Deprecated: No longer using mock data in AuthProvider
  }
}
