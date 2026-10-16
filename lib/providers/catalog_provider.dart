import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/types.dart';

class CatalogProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<CatalogItem> _sellerProducts = [];
  List<Order> _sellerOrders = [];
  bool _isLoading = false;

  List<CatalogItem> get sellerProducts => _sellerProducts;
  List<Order> get sellerOrders => _sellerOrders;
  bool get isLoading => _isLoading;

  void listenToSellerData(String sellerId) {
    _isLoading = true;
    notifyListeners();

    // Listen to Products
    _firestore
        .collection('catalog')
        .where('sellerUserId', isEqualTo: sellerId)
        .snapshots()
        .listen((snapshot) {
      _sellerProducts = snapshot.docs.map((doc) {
        final data = doc.data();
        return CatalogItem(
          id: doc.id,
          sellerUserId: data['sellerUserId'] ?? '',
          name: data['name'] ?? '',
          category: data['category'] ?? 'أخرى',
          unit: data['unit'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          stockStatus: data['stockStatus'] ?? true,
          photoUrl: data['photoUrl'],
          isApproved: data['isApproved'] ?? true,
          discountPercentage: (data['discountPercentage'] ?? 0.0).toDouble(),
          additionalPhotos: List<String>.from(data['additionalPhotos'] ?? []),
          quantity: (data['quantity'] ?? 0.0).toDouble(),
          address: data['address'] ?? '',
          condition: data['condition'] ?? 'جديد',
          minOrderQuantity: (data['minOrderQuantity'] ?? 1.0).toDouble(),
          deliveryAvailable: data['deliveryAvailable'] ?? false,
        );
      }).toList();
      _isLoading = false;
      notifyListeners();
    });

    // Listen to Orders
    _firestore
        .collection('orders')
        .where('sellerUserId', isEqualTo: sellerId)
        .snapshots()
        .listen((snapshot) {
      _sellerOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        return Order(
          id: doc.id,
          buyerUserId: data['buyerUserId'] ?? '',
          sellerUserId: data['sellerUserId'] ?? '',
          status: OrderStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
            orElse: () => OrderStatus.placed,
          ),
          total: (data['total'] ?? 0.0).toDouble(),
          deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
          deliveryMethod: data['deliveryMethod'] ?? 'delivery',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
    });
  }

  Future<void> addOrUpdateProduct(CatalogItem item) async {
    final data = {
      'sellerUserId': item.sellerUserId,
      'name': item.name,
      'category': item.category,
      'unit': item.unit,
      'price': item.price,
      'stockStatus': item.stockStatus,
      'photoUrl': item.photoUrl,
      'description': item.description,
      'isApproved': item.isApproved,
      'discountPercentage': item.discountPercentage,
      'additionalPhotos': item.additionalPhotos,
      'quantity': item.quantity,
      'address': item.address,
      'condition': item.condition,
      'minOrderQuantity': item.minOrderQuantity,
      'deliveryAvailable': item.deliveryAvailable,
    };

    if (item.id.startsWith('new_')) {
      await _firestore.collection('catalog').add(data);
    } else {
      await _firestore.collection('catalog').doc(item.id).update(data);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('catalog').doc(id).delete();
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status.toString(),
    });
  }
}
