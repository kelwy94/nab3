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
  StreamSubscription? _ordersSub;
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
    _ordersSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _listenToCatalog() {
    _catalogSub?.cancel();
    _ordersSub?.cancel();
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _catalogSub = _firestore.collection('catalog').snapshots().listen((snapshot) {
      List<naba.CatalogItem> parsed = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          parsed.add(naba.CatalogItem(
            id: doc.id,
            sellerUserId: data['sellerUserId'] ?? '',
            name: data['name'] ?? '',
            category: data['category'] ?? 'أخرى',
            unit: data['unit'] ?? '',
            price: (data['price'] ?? 0.0).toDouble(),
            stockStatus: data['stockStatus'] ?? true,
            photoUrl: data['photoUrl'],
          ));
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

    _ordersSub = _firestore.collection('orders').snapshots().listen((snapshot) {
      _orders.clear();
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          _orders.add(naba.Order(
            id: doc.id,
            buyerUserId: data['buyerUserId'] ?? '',
            sellerUserId: data['sellerUserId'] ?? '',
            status: naba.OrderStatus.values.firstWhere(
              (e) => e.toString() == data['status'] || e.toString().split('.').last == (data['status'] ?? ''),
              orElse: () => naba.OrderStatus.placed,
            ),
            total: (data['total'] ?? 0.0).toDouble(),
            deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
            deliveryMethod: data['deliveryMethod'] ?? 'delivery',
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        } catch (e) {
          debugPrint('ORDERS: Error parsing order ${doc.id}: $e');
        }
      }
      if (!_disposed) notifyListeners();
    }, onError: (e) {
      debugPrint('ORDERS: Error: $e');
    });
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
