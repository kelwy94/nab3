import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/types.dart' as naba;

class AppStateProvider with ChangeNotifier {
  final List<naba.Well> _wells = [];
  final List<naba.Job> _jobs = [];
  final List<naba.Order> _orders = [];
  List<naba.CatalogItem> _products = [];
  final List<naba.CatalogItem> _cart = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<naba.Well> get wells => _wells;
  List<naba.Job> get jobs => _jobs;
  List<naba.Order> get orders => _orders;
  List<naba.CatalogItem> get products => _products;
  List<naba.CatalogItem> get cart => _cart;
  bool get isLoading => _isLoading;

  void addToCart(naba.CatalogItem item) {
    _cart.add(item);
    notifyListeners();
  }

  void removeFromCart(naba.CatalogItem item) {
    _cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  AppStateProvider() {
    _listenToCatalog();
  }

  void _listenToCatalog() {
    _isLoading = true;
    notifyListeners();

    _firestore.collection('catalog').snapshots().listen((snapshot) {
      _products = snapshot.docs.map((doc) {
        final data = doc.data();
        return naba.CatalogItem(
          id: doc.id,
          sellerUserId: data['sellerUserId'] ?? '',
          name: data['name'] ?? '',
          category: data['category'] ?? 'أخرى',
          unit: data['unit'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          stockStatus: data['stockStatus'] ?? true,
          photoUrl: data['photoUrl'],
        );
      }).toList();
      _isLoading = false;
      notifyListeners();
    });

    _firestore.collection('orders').snapshots().listen((snapshot) {
      _orders.clear();
      _orders.addAll(snapshot.docs.map((doc) {
        final data = doc.data();
        return naba.Order(
          id: doc.id,
          buyerUserId: data['buyerUserId'] ?? '',
          sellerUserId: data['sellerUserId'] ?? '',
          status: naba.OrderStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
            orElse: () => naba.OrderStatus.placed,
          ),
          total: (data['total'] ?? 0.0).toDouble(),
          deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
          deliveryMethod: data['deliveryMethod'] ?? 'delivery',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }));
      notifyListeners();
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
