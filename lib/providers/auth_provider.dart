import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

import '../models/types.dart';
import '../services/notification_service.dart';
import '../services/device_info_helper.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  List<User> _allUsers = [];
  bool _isLoading = false;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  StreamSubscription? _usersSubscription;

  User? get user => _user;
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool _isGuest = false;
  bool get isGuest => _isGuest;

  /// Set after an admin issues a temporary password; the user must pick a
  /// new one before using the app.
  bool _mustChangePassword = false;
  bool get mustChangePassword => _mustChangePassword;

  Future<void> enterGuestMode() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Guest login failed: $e');
    }
    _isGuest = true;
    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    _isGuest = false;
    try {
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Guest sign out error: $e');
    }
    notifyListeners();
  }

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((fb_auth.User? fbUser) async {
      if (fbUser == null) {
        _user = null;
        _stopListeningToUsers();
        notifyListeners();
      } else {
        await _fetchUserProfile(fbUser.uid);
        await NotificationService.updateToken(fbUser.uid);
      }
    });
  }

  void _stopListeningToUsers() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _allUsers = [];
  }

  // The full user list is only needed (and only readable) by admins.
  void _listenToUsers() {
    // Cancel previous subscription if any
    _usersSubscription?.cancel();
    _usersSubscription =
        _firestore.collection('users').snapshots().listen((snapshot) {
      _allUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        final extraD = data['extraData'];
        if (extraD != null &&
            extraD is Map &&
            extraD['pendingSpecialization'] != null) {
          debugPrint(
              'Found a user with pendingSpecialization! User: ${data['fullName']}, Spec: ${extraD['pendingSpecialization']}');
        }
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
          extraData: extraD,
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
        _mustChangePassword = data['mustChangePassword'] == true;
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
        if (_user!.role == UserRole.admin) {
          if (_usersSubscription == null) _listenToUsers();
        } else {
          _stopListeningToUsers();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Save credentials for quick biometric login next time
      await _secureStorage.write(key: 'saved_email', value: email);
      await _secureStorage.write(key: 'saved_password', value: password);
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
      
      final deviceId = await DeviceInfoHelper.getDeviceId();
      // The invite code is resolved server-side (onUserCreated Function),
      // which also flags invites made from the inviter's own device.
      final inviteCode = (user.referredBy ?? '').trim().toUpperCase();

      final randomStr = String.fromCharCodes(Iterable.generate(
          4,
          (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
              .codeUnitAt(Random().nextInt(36))));
      final generatedReferralCode =
          '${user.phone.substring(user.phone.length > 4 ? user.phone.length - 4 : 0)}-$randomStr';

      // Farmers start approved; other roles need admin review.
      AccountStatus initialStatus = AccountStatus.approved;
      if (user.role != UserRole.farmer && user.role != UserRole.admin) {
        initialStatus = AccountStatus.pending;
      }

      final extraData = user.extraData ?? {};
      extraData['deviceId'] = deviceId;

      await _firestore.collection('users').doc(uid).set({
        'role': user.role.toString(),
        'fullName': user.fullName,
        'phone': user.phone,
        'nationalIdHash': user.nationalIdHash,
        'address': user.address,
        'status': initialStatus.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'extraData': extraData,
        'profileImageBase64': user.profileImageBase64,
        'profileImageUrl': user.profileImageUrl,
        'paymentMethod': user.paymentMethod?.name,
        'paymentDetails': user.paymentDetails,
        'referralCode': generatedReferralCode,
        'referredBy': null,
        if (inviteCode.isNotEmpty) 'referredByCode': inviteCode,
      });

      if (user.role == UserRole.equipmentOwner && user.extraData != null) {
        final eName = user.extraData!['equipmentName'];
        final eType = user.extraData!['equipmentType'];
        if (eName != null || eType != null) {
          await _firestore.collection('equipment').add({
            'ownerId': uid,
            'name': eName ?? eType ?? 'معدة',
            'type': eType ?? 'جرار',
            'model': user.extraData!['model'] ?? '',
            'attachments': user.extraData!['attachments'] ?? [],
            'hourlyRate': double.tryParse(
                    user.extraData!['hourlyRate']?.toString() ?? '0') ??
                0.0,
            'priceUnit': user.extraData!['priceUnit'] ?? 'ساعة',
            'isAvailable': true,
            'createdAt': FieldValue.serverTimestamp(),
            'rating': 5.0,
            'reviewCount': 0,
            if (user.extraData!['equipmentImageBase64'] != null)
              'photoBase64': user.extraData!['equipmentImageBase64'],
          });
        }
      }

      _user = user.copyWith(
        id: uid,
        status: initialStatus,
        referralCode: generatedReferralCode,
        referredBy: null,
        extraData: extraData,
      );
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

  Future<void> uploadProfileImageToStorage(
      Uint8List imageBytes, String extension) async {
    if (_user == null) return;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${_user!.id}.$extension');
      await ref.putData(
          imageBytes, SettableMetadata(contentType: 'image/$extension'));
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(_user!.id).update({
        'profileImageUrl': url,
        'profileImageBase64':
            FieldValue.delete(), // optional: clean up old base64
      });
      _user = _user!.copyWith(profileImageUrl: url, profileImageBase64: null);
      notifyListeners();
    } catch (e) {
      debugPrint('Error uploading profile picture to storage: $e');
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

  /// Called after the user replaces a temporary password.
  Future<void> clearMustChangePassword() async {
    if (_user == null) return;
    await _firestore
        .collection('users')
        .doc(_user!.id)
        .update({'mustChangePassword': false});
    _mustChangePassword = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    final isBioEnabled = await _secureStorage.read(key: 'biometric_enabled');
    if (isBioEnabled != 'true') {
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
    }
    _user = null;
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
          referralCode: data['referralCode'],
          referredBy: data['referredBy'],
        );
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
    return null;
  }

  Future<void> seedDemoData() async {
    // Deprecated: No longer using mock data in AuthProvider
  }

  Future<void> reloadUser() async {
    if (_user != null) {
      await _fetchUserProfile(_user!.id);
      notifyListeners();
    }
  }
}
