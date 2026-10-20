import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/types.dart' as naba;

class AppStateProvider with ChangeNotifier {
  final List<naba.Well> _wells = [];
  final List<naba.Job> _jobs = [];
  final List<naba.Order> _orders = [];
  List<naba.CatalogItem> _products = [];
  final Map<String, naba.CatalogItem> _cartItems = {};
  final Map<String, int> _cartQuantities = {};
  bool _isLoading = false;

  // Address management
  final List<String> _savedAddresses = [];
  String? _selectedAddress;
  bool _disposed = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _catalogSub;
  StreamSubscription? _profileSub;
  final List<StreamSubscription> _orderQuerySubs = [];
  final Map<int, Map<String, naba.Order>> _orderResults = {};
  String? _orderRole;
  StreamSubscription? _authSub;

  List<naba.Well> get wells => _wells;
  List<naba.Job> get jobs => _jobs;
  List<naba.Order> get orders => _orders;
  List<naba.CatalogItem> get products => _products;
  List<naba.CatalogItem> get cart => _cartItems.values.toList();
  bool get isLoading => _isLoading;
  List<String> get savedAddresses => _savedAddresses;
  String? get selectedAddress => _selectedAddress;

  int getQuantity(String itemId) => _cartQuantities[itemId] ?? 0;

  void addToCart(naba.CatalogItem item) {
    _cartItems[item.id] = item;
    _cartQuantities[item.id] = (_cartQuantities[item.id] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(naba.CatalogItem item) {
    if ((_cartQuantities[item.id] ?? 0) > 1) {
      _cartQuantities[item.id] = _cartQuantities[item.id]! - 1;
    } else {
      _cartQuantities.remove(item.id);
      _cartItems.remove(item.id);
    }
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _cartQuantities.clear();
    notifyListeners();
  }

  /// Initialize addresses from user profile
  void initAddressesFromUser(String? userAddress) {
    if (_savedAddresses.isEmpty && userAddress != null && userAddress.isNotEmpty) {
      _savedAddresses.add(userAddress);
      _selectedAddress = userAddress;
    }
  }

  void addAddress(String address) {
    if (address.isNotEmpty && !_savedAddresses.contains(address)) {
      _savedAddresses.add(address);
      _selectedAddress = address;
      notifyListeners();
    }
  }

  void selectAddress(String address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void removeAddress(String address) {
    _savedAddresses.remove(address);
    if (_selectedAddress == address) {
      _selectedAddress = _savedAddresses.isNotEmpty ? _savedAddresses.first : null;
    }
    notifyListeners();
  }

  AppStateProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_disposed) {
        _listenToCatalog();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _catalogSub?.cancel();
    _profileSub?.cancel();
    _cancelOrderQueries();
    _authSub?.cancel();
    super.dispose();
  }

  void _listenToCatalog() {
    _catalogSub?.cancel();
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _catalogSub = _firestore.collection('catalog').snapshots().listen((snapshot) {
      List<naba.CatalogItem> parsed = [];
      for (var doc in snapshot.docs) {
        try {
          parsed.add(naba.CatalogItem.fromMap(doc.id, doc.data()));
        } catch (e) {
          debugPrint('CATALOG: Error parsing product ${doc.id}: $e');
        }
      }
      _products = parsed;
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }, onError: (e) {
      debugPrint('CATALOG: Error: $e');
      _isLoading = false;
      if (!_disposed) notifyListeners();
    });

    _listenToOrders();
  }

  /// Orders are only readable by the parties involved (see firestore.rules),
  /// so instead of the whole collection we listen to role-scoped queries:
  /// everyone sees what they bought; sellers what they sold; delivery
  /// workers what they carry plus unclaimed orders; admins everything.
  /// The user's profile is watched so the queries follow role changes and
  /// start once a freshly signed-up profile exists.
  void _listenToOrders() {
    _profileSub?.cancel();
    _cancelOrderQueries();
    _orderRole = null;
    _orders.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (!_disposed) notifyListeners();
      return;
    }

    _profileSub = _firestore.collection('users').doc(user.uid).snapshots().listen(
        (profile) {
      final role = profile.exists ? (profile.data()?['role'] as String? ?? '') : null;
      if (role == _orderRole && _orderQuerySubs.isNotEmpty) return;
      _orderRole = role;
      _cancelOrderQueries();
      _orders.clear();
      if (role == null) {
        if (!_disposed) notifyListeners();
        return;
      }

      final orders = _firestore.collection('orders');
      final List<Query<Map<String, dynamic>>> queries;
      if (_roleIs(role, 'admin')) {
        queries = [orders];
      } else {
        queries = [orders.where('buyerUserId', isEqualTo: user.uid)];
        if (_roleIs(role, 'seller')) {
          queries.add(orders.where('sellerUserId', isEqualTo: user.uid));
        }
        if (_roleIs(role, 'deliveryWorker')) {
          queries.add(orders.where('deliveryWorkerId', isEqualTo: user.uid));
          // Ready for pickup: placed delivery orders nobody has claimed yet
          // (claiming sets deliveryWorkerId and moves the status on).
          queries.add(orders
              .where('status', isEqualTo: naba.OrderStatus.placed.toString())
              .where('deliveryMethod', isEqualTo: 'delivery'));
        }
      }

      for (var i = 0; i < queries.length; i++) {
        _orderQuerySubs.add(queries[i].snapshots().listen((snapshot) {
          _orderResults[i] = {
            for (final doc in snapshot.docs)
              if (_parseOrder(doc) case final order?) doc.id: order,
          };
          _rebuildOrders();
        }, onError: (e) {
          debugPrint('ORDERS: Error: $e');
        }));
      }
    }, onError: (e) {
      debugPrint('ORDERS: Error loading profile: $e');
    });
  }

  static bool _roleIs(String role, String name) =>
      role == 'UserRole.$name' || role == name;

  void _cancelOrderQueries() {
    for (final sub in _orderQuerySubs) {
      sub.cancel();
    }
    _orderQuerySubs.clear();
    _orderResults.clear();
  }

  void _rebuildOrders() {
    final merged = <String, naba.Order>{};
    for (final results in _orderResults.values) {
      merged.addAll(results);
    }
    _orders
      ..clear()
      ..addAll(merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    if (!_disposed) notifyListeners();
  }

  naba.Order? _parseOrder(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data()!;
      return naba.Order(
        id: doc.id,
        buyerUserId: data['buyerUserId'] ?? '',
        sellerUserId: data['sellerUserId'] ?? '',
        deliveryWorkerId: data['deliveryWorkerId'],
        status: naba.OrderStatus.values.firstWhere(
          (e) => e.toString() == data['status'] || e.toString().split('.').last == (data['status'] ?? ''),
          orElse: () => naba.OrderStatus.placed,
        ),
        total: (data['total'] ?? 0.0).toDouble(),
        deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
        deliveryMethod: data['deliveryMethod'] ?? 'delivery',
        paymentMethod: data['paymentMethod'],
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('ORDERS: Error parsing order ${doc.id}: $e');
      return null;
    }
  }

  void addWell(naba.Well well) {
    _wells.add(well);
    notifyListeners();
  }

  void addJob(naba.Job job) {
    _jobs.add(job);
    notifyListeners();
  }

  void addOrder(naba.Order order) {
    _orders.add(order);
    notifyListeners();
  }
}
