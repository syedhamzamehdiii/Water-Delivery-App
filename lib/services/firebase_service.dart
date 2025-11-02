import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../models/vendor.dart';
import '../models/vendor_pickup.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/invoice.dart';
import '../models/auto_order.dart';
import '../models/attendance.dart';
import '../models/settings.dart';

class FirebaseService {
  static String? _cachedCompanyId;
  static String? _cachedUid;

  static Future<String?> _getCurrentCompanyId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    if (_cachedUid != uid) {
      _cachedUid = uid;
      _cachedCompanyId = null;
    }
    if (_cachedCompanyId != null) return _cachedCompanyId;
    
    // First check if user is a company admin (in company_admins collection)
    final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(uid).get();
    if (adminDoc.exists) {
      _cachedCompanyId = adminDoc.data()?['companyId'] as String?;
      return _cachedCompanyId;
    }
    
    // Otherwise check if user is a driver/employee (in users collection)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _cachedCompanyId = userDoc.data()?['companyId'] as String?;
    return _cachedCompanyId;
  }

  static Map<String, dynamic> _withCompany(Map<String, dynamic> data, String? companyId) {
    if (data.containsKey('companyId')) return data;
    return {
      ...data,
      if (companyId != null) 'companyId': companyId,
    };
  }

  static CollectionReference<Map<String, dynamic>> _companyCol(String companyId, String collection) {
    if (companyId.isEmpty) {
      throw Exception('Company ID cannot be empty when accessing company-scoped collections');
    }
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection(collection);
  }
  // Authentication
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential?> registerCompanyAdmin({
    required String email,
    required String password,
    String? companyName,
  }) async {
    final credential = await createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential?.user?.uid;
    if (uid != null) {
      // Generate a unique companyId
      final companyDocRef = FirebaseFirestore.instance.collection('companies').doc();
      final companyId = companyDocRef.id;
      
      // Extract name from email or use companyName
      // Email format: name@example.com -> "name"
      String name = '';
      if (companyName != null && companyName.isNotEmpty) {
        name = companyName;
      } else {
        // Extract from email: "john.doe@example.com" -> "John Doe"
        final emailPrefix = email.split('@').first;
        name = emailPrefix
            .replaceAll('.', ' ')
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
                : '')
            .where((word) => word.isNotEmpty)
            .join(' ');
        
        // Fallback if name is still empty
        if (name.isEmpty) {
          name = emailPrefix.isNotEmpty 
              ? emailPrefix[0].toUpperCase() + emailPrefix.substring(1).toLowerCase()
              : 'Admin';
        }
      }
      
      // Create company document in companies collection
      await companyDocRef.set({
        'id': companyId,
        'name': companyName ?? name,
        'adminUid': uid,
        'adminEmail': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Store company admin in company_admins collection (separate from users)
      await FirebaseFirestore.instance.collection('company_admins').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': 'admin',
        'companyId': companyId, // Store the companyId
        'companyName': companyName ?? name,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return credential;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // User profiles - check both company_admins (for admins) and users (for drivers/employees)
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    // First check if user is a company admin (in company_admins collection)
    final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(uid).get();
    if (adminDoc.exists) {
      return adminDoc.data();
    }
    
    // Otherwise check if user is a driver/employee (in users collection)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return userDoc.data();
    }
    
    return null;
  }

  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role,
    String? phone,
    String? address,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'address': address,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    bool? isActive,
    String? phone,
    String? address,
    Map<String, dynamic>? data,
  }) async {
    final Map<String, dynamic> payload = {
      if (name != null) 'name': name,
      if (isActive != null) 'isActive': isActive,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      ...?data,
    };
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
          payload,
          SetOptions(merge: true),
        );
  }

  static Future<void> ensureCompanyAdminSynced(String uid) async {
    // Check if admin exists in company_admins, if not, try to migrate from users
    final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(uid).get();
    if (!adminDoc.exists) {
      // Try to get from users collection (for legacy admins)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        // If it's an admin, migrate to company_admins
        if (userData['role'] == 'admin') {
          await FirebaseFirestore.instance.collection('company_admins').doc(uid).set(userData, SetOptions(merge: true));
        }
      }
    }
  }

  // Collections: Products
  static Stream<List<Product>> getProductsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('products')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Product.fromJson(d.data())).toList());
      }
      // Only return company-specific products, don't fall back to top-level
      return _companyCol(companyId, 'products').snapshots().map((snap) {
        return snap.docs.map((d) => Product.fromJson(d.data())).toList();
      });
    });
  }

  static Stream<List<Product>> getCompanyProductsStream() => getProductsStream();

  static Future<void> createProduct(Product product) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .set(product.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'products')
        .doc(product.id)
        .set(_withCompany(product.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> updateProduct(Product product) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .set(product.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'products')
        .doc(product.id)
        .set(_withCompany(product.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> deleteProduct(String productId) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      return;
    }
    await _companyCol(companyId, 'products').doc(productId).delete();
  }

  // Collections: Customers (kept as maps; UI maps to models)
  static Stream<List<Map<String, dynamic>>> getCustomersStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('customers')
            .snapshots()
            .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      }
      // Listen to company-scoped collection with real-time updates
      return _companyCol(companyId, 'customers').snapshots().map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    });
  }

  static Stream<List<Map<String, dynamic>>> getCompanyCustomersStream() {
    return getCustomersStream();
  }

  static Future<String> createCustomer(Map<String, dynamic> customerData) async {
    final companyId = await _getCurrentCompanyId();
    final providedId = customerData['id'] as String?;
    final hasValidId = providedId != null && providedId.isNotEmpty;
    
    if (companyId == null) {
      final doc = hasValidId
          ? FirebaseFirestore.instance.collection('customers').doc(providedId)
          : FirebaseFirestore.instance.collection('customers').doc();
      final id = doc.id;
      await doc.set({
        ...customerData,
        'id': id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return id;
    }
    final doc = hasValidId
        ? _companyCol(companyId, 'customers').doc(providedId)
        : _companyCol(companyId, 'customers').doc();
    final id = doc.id;
    await doc.set(_withCompany({
      ...customerData,
      'id': id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, companyId), SetOptions(merge: true));
    return id;
  }

  static Future<void> updateCustomer(String customerId, Map<String, dynamic> data) async {
    if (customerId.isEmpty) {
      throw Exception('Customer ID cannot be empty');
    }
    final companyId = await _getCurrentCompanyId();
    final payload = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('customers').doc(customerId).set(
            payload,
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'customers').doc(customerId).set(
          _withCompany(payload, companyId),
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteCustomer(String customerId) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('customers').doc(customerId).delete();
      return;
    }
    await _companyCol(companyId, 'customers').doc(customerId).delete();
  }

  // Collections: Orders (kept as maps; UI maps to models)
  static Stream<List<Map<String, dynamic>>> getOrdersStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('orders')
            .snapshots()
            .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      }
      // Listen to company-scoped collection with real-time updates
      return _companyCol(companyId, 'orders').snapshots().map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    });
  }

  static Stream<List<Map<String, dynamic>>> getCompanyOrdersStream() {
    return getOrdersStream();
  }

  static Future<String> createOrder(Map<String, dynamic> orderData) async {
    String? resultId;
    try {
      final companyId = await _getCurrentCompanyId();
      final providedId = orderData['id'] as String?;
      final hasValidId = providedId != null && providedId.isNotEmpty;
      
      if (companyId == null || companyId.isEmpty) {
        final doc = hasValidId 
            ? FirebaseFirestore.instance.collection('orders').doc(providedId)
            : FirebaseFirestore.instance.collection('orders').doc();
        resultId = doc.id;
        
        if (resultId.isEmpty) {
          throw Exception('Firestore generated an empty document ID in top-level collection');
        }
        
        await doc.set({
          ...orderData,
          'id': resultId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return resultId;
      }
      
      // Double-check companyId is valid before calling _companyCol
      if (companyId.isEmpty) {
        throw Exception('Company ID is empty - cannot create company-scoped order');
      }
      
      final doc = hasValidId
          ? _companyCol(companyId, 'orders').doc(providedId)
          : _companyCol(companyId, 'orders').doc();
      resultId = doc.id;
      
      if (resultId.isEmpty) {
        throw Exception('Firestore generated an empty document ID in company-scoped collection');
      }
      
      await doc.set(_withCompany({
        ...orderData,
        'id': resultId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, companyId), SetOptions(merge: true));
      return resultId;
    } catch (e) {
      // Always throw - never return empty string
      throw Exception('createOrder failed: $e');
    } finally {
      // Final validation - resultId is checked, but no console output
      if (resultId != null && resultId.isEmpty) {
        // Result ID validation - handled by exception above
      }
    }
  }

  static Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    if (orderId.isEmpty) {
      throw Exception('Order ID cannot be empty');
    }
    final companyId = await _getCurrentCompanyId();
    final payload = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    if (companyId == null || companyId.isEmpty) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set(
            payload,
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'orders').doc(orderId).set(
          _withCompany(payload, companyId),
          SetOptions(merge: true),
        );
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    if (orderId.isEmpty) {
      throw Exception('Order ID cannot be empty');
    }
    final companyId = await _getCurrentCompanyId();
    final payload = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (companyId == null || companyId.isEmpty) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set(
            payload,
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'orders').doc(orderId).set(
          payload,
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteOrder(String orderId) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
      return;
    }
    await _companyCol(companyId, 'orders').doc(orderId).delete();
  }

  // Collections: Payments (kept as maps; UI maps to models)
  static Stream<List<Map<String, dynamic>>> getPaymentsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('payments')
            .snapshots()
            .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      }
      // Listen to company-scoped collection with real-time updates
      return _companyCol(companyId, 'payments').snapshots().map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    });
  }

  static Stream<List<Map<String, dynamic>>> getCompanyPaymentsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('payments')
            .snapshots()
            .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      }
      // Listen to company-scoped collection with real-time updates
      return _companyCol(companyId, 'payments').snapshots().map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    });
  }

  static Future<void> createPaymentWithOrder({
    required String orderId,
    required int amount,
    required String paymentMethod,
    required String customerId,
    required int quantity,
    required int price,
    String? collectedBy,
    String? notes,
    String? customerName,
  }) async {
    if (orderId.isEmpty) {
      throw Exception('Order ID cannot be empty when creating payment');
    }
    final companyId = await _getCurrentCompanyId();
    if (companyId == null || companyId.isEmpty) {
      final doc = FirebaseFirestore.instance.collection('payments').doc();
      await doc.set({
        'id': doc.id,
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'customerId': customerId,
        'quantity': quantity,
        'price': price,
        'collectedBy': collectedBy,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror positive payments to income and update order's collected shortcut
      if (amount > 0) {
        final now = DateTime.now();
        // Use provided customerName or try to get from order
        String? finalCustomerName = customerName;
        if (finalCustomerName == null || finalCustomerName.isEmpty) {
          try {
            final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
            final orderData = orderDoc.data();
            finalCustomerName = orderData?['customerName'] as String? ?? '';
          } catch (e) {
          }
        }
        
        final incomeDoc = FirebaseFirestore.instance.collection('income').doc();
        await incomeDoc.set({
          'id': incomeDoc.id,
          'title': finalCustomerName?.isNotEmpty == true ? 'Payment from $finalCustomerName' : 'Payment from Order',
          'description': notes ?? 'Payment collected via $paymentMethod${quantity > 0 ? " ($quantity bottles)" : ""}',
          'amount': amount,
          'source': 'automatic',
          'orderId': orderId,
          'customerId': customerId,
          'customerName': finalCustomerName,
          'date': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
          'amountCollected': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }
    final doc = _companyCol(companyId, 'payments').doc();
    await doc.set(_withCompany({
      'id': doc.id,
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'quantity': quantity,
      'price': price,
      'collectedBy': collectedBy,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, companyId), SetOptions(merge: true));

    // Mirror positive payments to income and update order's collected shortcut (company scoped)
    if (amount > 0) {
      final now = DateTime.now();
      // Use provided customerName or try to get from order
      String? finalCustomerName = customerName;
      bool isOnDemand = false;
      
      if (finalCustomerName == null || finalCustomerName.isEmpty) {
        try {
          final orderDoc = await _companyCol(companyId, 'orders').doc(orderId).get();
          final orderData = orderDoc.data();
          finalCustomerName = orderData?['customerName'] as String? ?? '';
          isOnDemand = orderData?['notes']?.toString().toLowerCase().contains('on-demand') ?? false;
        } catch (e) {
          // Error fetching customer name from order
        }
      } else {
        // Check if notes indicate on-demand
        isOnDemand = notes?.toLowerCase().contains('on-demand') ?? false;
      }
      
      final incomeDoc = _companyCol(companyId, 'income').doc();
      await incomeDoc.set(_withCompany({
        'id': incomeDoc.id,
        'title': finalCustomerName?.isNotEmpty == true ? 'Payment from $finalCustomerName' : 'Payment from Order',
        'description': notes ?? 'Payment collected via $paymentMethod${quantity > 0 ? " ($quantity bottles${isOnDemand ? " - On Demand" : ""})" : ""}',
        'amount': amount,
        'source': 'automatic',
        'orderId': orderId,
        'customerId': customerId,
        'customerName': finalCustomerName,
        'date': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, companyId), SetOptions(merge: true));

      await _companyCol(companyId, 'orders').doc(orderId).set({
        'amountCollected': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Vendors
  static Stream<List<Vendor>> getVendorsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('vendors')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Vendor.fromJson(d.data())).toList());
      }
      return _companyCol(companyId, 'vendors').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => Vendor.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('vendors').get();
        return top.docs.map((d) => Vendor.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> createVendor(Vendor vendor) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('vendors').doc(vendor.id).set(
            vendor.toJson(),
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'vendors').doc(vendor.id).set(
          _withCompany(vendor.toJson(), companyId),
          SetOptions(merge: true),
        );
  }

  static Future<void> updateVendor(Vendor vendor) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('vendors').doc(vendor.id).set(
            vendor.toJson(),
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'vendors').doc(vendor.id).set(
          _withCompany(vendor.toJson(), companyId),
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteVendor(String vendorId) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('vendors').doc(vendorId).delete();
      return;
    }
    await _companyCol(companyId, 'vendors').doc(vendorId).delete();
  }

  // Vendor pickups
  static Stream<List<VendorPickup>> getVendorPickupsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('vendor_pickups')
            .snapshots()
            .map((snap) => snap.docs.map((d) => VendorPickup.fromJson(d.data())).toList());
      }
      return _companyCol(companyId, 'vendor_pickups').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => VendorPickup.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('vendor_pickups').get();
        return top.docs.map((d) => VendorPickup.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> createVendorPickup(VendorPickup pickup) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('vendor_pickups').doc(pickup.id).set(
            pickup.toJson(),
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'vendor_pickups').doc(pickup.id).set(
          _withCompany(pickup.toJson(), companyId),
          SetOptions(merge: true),
        );
  }

  // Expenses
  static Stream<List<Expense>> getExpensesStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('expenses')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Expense.fromJson(d.data())).toList());
      }
      return _companyCol(companyId, 'expenses').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => Expense.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('expenses').get();
        return top.docs.map((d) => Expense.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> createExpense(Expense expense) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'expenses')
        .doc(expense.id)
        .set(_withCompany(expense.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> deleteExpense(String expenseId) async {
    await FirebaseFirestore.instance.collection('expenses').doc(expenseId).delete();
  }

  // Income
  static Stream<List<Income>> getIncomeStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('income')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Income.fromJson({'id': d.id, ...d.data()})).toList());
      }
      // Listen to company-scoped collection with real-time updates
      return _companyCol(companyId, 'income').snapshots().map((snap) {
        return snap.docs.map((d) => Income.fromJson({'id': d.id, ...d.data()})).toList();
      });
    });
  }

  static Future<void> createIncome(Income income) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('income')
          .doc(income.id)
          .set(income.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'income')
        .doc(income.id)
        .set(_withCompany(income.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> deleteIncome(String incomeId) async {
    await FirebaseFirestore.instance.collection('income').doc(incomeId).delete();
  }

  // Invoices
  static Stream<List<Invoice>> getInvoicesStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('invoices')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Invoice.fromJson(d.data())).toList());
      }
      return _companyCol(companyId, 'invoices').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => Invoice.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('invoices').get();
        return top.docs.map((d) => Invoice.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> createInvoice(Invoice invoice) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(invoice.id)
          .set(invoice.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'invoices')
        .doc(invoice.id)
        .set(_withCompany(invoice.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> deleteInvoice(String invoiceId) async {
    await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).delete();
  }

  // Attendance
  static Stream<List<Attendance>> getCompanyAttendanceStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('attendance')
            .snapshots()
            .map((snap) => snap.docs.map((d) => Attendance.fromJson(d.data())).toList());
      }
      return _companyCol(companyId, 'attendance').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => Attendance.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('attendance').get();
        return top.docs.map((d) => Attendance.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> saveAttendance(Attendance attendance) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendance.id)
          .set(attendance.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'attendance')
        .doc(attendance.id)
        .set(_withCompany(attendance.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> deleteAttendance(String attendanceId) async {
    await FirebaseFirestore.instance.collection('attendance').doc(attendanceId).delete();
  }

  static Future<List<Attendance>> getEmployeeAttendanceForMonth(
    String employeeId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final companyId = await _getCurrentCompanyId();
    final col = companyId == null
        ? FirebaseFirestore.instance.collection('attendance')
        : _companyCol(companyId, 'attendance');
    final snap = await col
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => Attendance.fromJson({'id': d.id, ...d.data()})).toList();
  }

  static Stream<List<Attendance>> getEmployeeAttendanceForMonthStream(
    String employeeId,
    int year,
    int month,
  ) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      final col = companyId == null
          ? FirebaseFirestore.instance.collection('attendance')
          : _companyCol(companyId, 'attendance');
      return col
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .snapshots()
          .map((snap) => snap.docs.map((d) => Attendance.fromJson({'id': d.id, ...d.data()})).toList());
    });
  }

  // Today bottle sells metric
  static Stream<Map<String, dynamic>> getTodayBottleSellsStream() {
    return FirebaseFirestore.instance
        .collection('metrics')
        .doc('todayBottleSells')
        .snapshots()
        .map((doc) => doc.data() ?? <String, dynamic>{});
  }

  // Auto orders
  static Stream<List<AutoOrder>> getAutoOrdersStream(String? companyId) {
    return Stream.fromFuture(companyId != null ? Future.value(companyId) : _getCurrentCompanyId()).asyncExpand((cid) {
      if (cid == null) {
        return FirebaseFirestore.instance
            .collection('auto_orders')
            .snapshots()
            .map((snap) => snap.docs.map((d) => AutoOrder.fromJson(d.data())).toList());
      }
      return _companyCol(cid, 'auto_orders').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => AutoOrder.fromJson(d.data())).toList();
        final top = await FirebaseFirestore.instance.collection('auto_orders').get();
        return top.docs.map((d) => AutoOrder.fromJson(d.data())).toList();
      });
    });
  }

  static Future<void> createAutoOrder(AutoOrder autoOrder) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('auto_orders')
          .doc(autoOrder.id)
          .set(autoOrder.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'auto_orders')
        .doc(autoOrder.id)
        .set(_withCompany(autoOrder.toJson(), companyId), SetOptions(merge: true));
  }

  static Future<void> updateAutoOrder(String autoOrderId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('auto_orders').doc(autoOrderId).set(
          data..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteAutoOrder(String autoOrderId) async {
    await FirebaseFirestore.instance.collection('auto_orders').doc(autoOrderId).delete();
  }

  static Future<void> cancelAutoOrderAndCreatePending(String autoOrderId) async {
    // Minimal placeholder: mark canceled
    await FirebaseFirestore.instance.collection('auto_orders').doc(autoOrderId).set(
      {
        'status': 'canceled',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> processAutoOrdersForToday(String? companyId) async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final cid = companyId ?? await _getCurrentCompanyId();
    final autosCol = cid == null
        ? FirebaseFirestore.instance.collection('auto_orders')
        : _companyCol(cid, 'auto_orders');
    final ordersCol = cid == null
        ? FirebaseFirestore.instance.collection('orders')
        : _companyCol(cid, 'orders');

    // Fetch today's active auto orders
    final snap = await autosCol
        .where('isActive', isEqualTo: true)
        .where('nextDeliveryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('nextDeliveryDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();

      // Prevent duplicates: if an order already exists today for this customer, skip
      final existing = await ordersCol
          .where('customerId', isEqualTo: data['customerId'])
          .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('orderDate', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        continue;
      }

      final orderDoc = ordersCol.doc();
      await orderDoc.set({
        'id': orderDoc.id,
        'customerId': data['customerId'],
        'customerName': data['customerName'],
        'quantity': data['quantity'] ?? 0,
        'price': data['price'] ?? 0,
        'salesTax': data['salesTax'] ?? 0,
        'status': 'Pending',
        'orderDate': FieldValue.serverTimestamp(),
        'notes': 'Auto order for ${data['dayOfWeek']}',
        'assignedDriver': data['assignedDriver'],
        if (cid != null) 'companyId': cid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Advance nextDeliveryDate by 7 days
      final nextDateTs = data['nextDeliveryDate'];
      DateTime nextDate;
      if (nextDateTs is Timestamp) {
        nextDate = nextDateTs.toDate().add(const Duration(days: 7));
      } else if (nextDateTs is String) {
        nextDate = DateTime.parse(nextDateTs).add(const Duration(days: 7));
      } else {
        nextDate = endOfDay.add(const Duration(days: 7));
      }
      await doc.reference.set({
        'nextDeliveryDate': Timestamp.fromDate(nextDate),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Routes (stored as generic maps)
  static Stream<List<Map<String, dynamic>>> getRoutesStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('routes')
            .snapshots()
            .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      }
      return _companyCol(companyId, 'routes').snapshots().asyncMap((snap) async {
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        final top = await FirebaseFirestore.instance.collection('routes').get();
        return top.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    });
  }

  static Stream<List<Map<String, dynamic>>> getCompanyRoutesStream() {
    return getRoutesStream();
  }

  static Future<void> createRoute(String routeId, Map<String, dynamic> data) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('routes').doc(routeId).set(
            {...data, 'createdAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
      return;
    }
    await _companyCol(companyId, 'routes').doc(routeId).set(
          _withCompany({...data, 'createdAt': FieldValue.serverTimestamp()}, companyId),
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteRoute(String routeId) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance.collection('routes').doc(routeId).delete();
      return;
    }
    await _companyCol(companyId, 'routes').doc(routeId).delete();
  }

  // Settings
  static Stream<AppSettings?> getSettingsStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) {
      if (companyId == null) {
        return FirebaseFirestore.instance
            .collection('settings')
            .doc('app_settings')
            .snapshots()
            .map((doc) => doc.data() != null ? AppSettings.fromJson(doc.data()!) : null);
      }
      return _companyCol(companyId, 'settings')
          .doc('app_settings')
          .snapshots()
          .asyncMap((doc) async {
            if (doc.data() != null) return AppSettings.fromJson(doc.data()!);
            final fallback = await FirebaseFirestore.instance.collection('settings').doc('app_settings').get();
            return fallback.data() != null ? AppSettings.fromJson(fallback.data()!) : null;
          });
    });
  }

  static Future<void> updateSettings(AppSettings settings) async {
    final companyId = await _getCurrentCompanyId();
    if (companyId == null) {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(settings.id)
          .set(settings.toJson(), SetOptions(merge: true));
      return;
    }
    await _companyCol(companyId, 'settings')
        .doc(settings.id)
        .set(_withCompany(settings.toJson(), companyId), SetOptions(merge: true));
  }

  // Employees
  static Stream<List<Map<String, dynamic>>> getCompanyEmployeesStream() {
    return Stream.fromFuture(_getCurrentCompanyId()).asyncExpand((companyId) async* {
      try {
        // Verify the current user is an admin before querying
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          yield <Map<String, dynamic>>[];
          return;
        }
        
        // Check if current user is admin (from company_admins collection)
        final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(currentUser.uid).get();
        final isAdmin = adminDoc.exists && adminDoc.data()?['role'] == 'admin';
        
        if (!isAdmin) {
          // Not an admin - return empty stream (employees shouldn't see other employees)
          yield <Map<String, dynamic>>[];
          return;
        }
        
        if (companyId == null) {
          // For legacy admin without companyId, use top-level collection
          yield* FirebaseFirestore.instance
              .collection('users')
              .where('role', whereIn: ['employee', 'driver'])
              .snapshots()
              .handleError((error) {
                // Log error but don't break the stream
                print('Error in getCompanyEmployeesStream (legacy): $error');
              })
              .map((snap) => snap.docs.map((d) => d.data()).toList());
        } else {
          // For company-scoped queries, add companyId to the query to match Firestore security rules
          // This ensures the security rules can properly validate the query
          yield* FirebaseFirestore.instance
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .where('role', whereIn: ['employee', 'driver'])
              .snapshots()
              .handleError((error) {
                // Log error but don't break the stream
                print('Error in getCompanyEmployeesStream (company-scoped): $error');
              })
              .map((snap) => snap.docs.map((d) => d.data()).toList());
        }
      } catch (e) {
        // Catch any errors during stream setup and return empty list
        print('Error setting up getCompanyEmployeesStream: $e');
        yield <Map<String, dynamic>>[];
      }
    });
  }

  static Future<String?> createEmployee({
    required String name,
    String? email,
    String? password,
    required String role,
    String? phone,
    String? address,
    String? cnic,
    String? contactNumber,
    String? driverAddress,
    String? salary,
    String? designation,
    String? salaryType,
  }) async {
    // IMPORTANT: Get the admin's companyId and UID FIRST (before any operations)
    // because createUserWithEmailAndPassword will automatically sign us in as the new user
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    
    if (adminUid == null) {
      throw Exception('Admin not authenticated. Please sign in as admin first.');
    }
    
    // Validate email and password are provided together
    if ((email == null || email.isEmpty) != (password == null || password.isEmpty)) {
      throw Exception('Email and password must both be provided or both left empty');
    }

    // If email/password are provided, validate them
    if (email != null && email.isNotEmpty) {
      // More strict email validation
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      final trimmedEmail = email.trim();
      if (!emailRegex.hasMatch(trimmedEmail)) {
        throw Exception('Invalid email format. Please enter a valid email address (e.g., user@example.com).');
      }
      if (password == null || password.isEmpty) {
        throw Exception('Password is required when email is provided');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      // Trim email for actual use
      email = trimmedEmail;
    }
    
    // Get admin's companyId from company_admins collection BEFORE we sign in as the new user
    String? adminCompanyId;
    final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(adminUid).get();
    if (adminDoc.exists) {
      adminCompanyId = adminDoc.data()?['companyId'] as String?;
    } else {
      // Fallback: check users collection (for legacy admins)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(adminUid).get();
      adminCompanyId = userDoc.data()?['companyId'] as String?;
    }
    
    if (adminCompanyId == null) {
      throw Exception('Admin companyId not found. Please ensure you are logged in as a company admin.');
    }
    
    // If email/password are not provided, create employee without Firebase Auth account
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      // Create employee profile directly in Firestore without Firebase Auth account
      final docRef = FirebaseFirestore.instance.collection('users').doc();
      await docRef.set({
        'uid': docRef.id,
        'email': email ?? '',
        'name': name,
        'role': role,
        'phone': phone,
        'address': address,
        'isActive': true,
        'cnic': cnic,
        'contactNumber': contactNumber,
        'driverAddress': driverAddress,
        'salary': salary,
        'designation': designation,
        'salaryType': salaryType,
        'companyId': adminCompanyId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Return admin UID since we didn't sign out (no auth account created)
      return adminUid;
    }
    
    // Create Firebase Auth account for employee
    // This will automatically sign us in as the new user
    try {
      final credential = await createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential?.user?.uid;
      if (uid != null) {
        // Create basic user profile first (new user can write their own profile per Firestore rules)
        await createUserProfile(
          uid: uid,
          email: email,
          name: name,
          role: role,
          phone: phone,
          address: address,
        );
        
        // Now merge extended fields including companyId (new user can write their own profile)
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'cnic': cnic,
          'contactNumber': contactNumber,
          'driverAddress': driverAddress,
          'salary': salary,
          'designation': designation,
          'salaryType': salaryType,
          'companyId': adminCompanyId, // Use admin's companyId that we stored before creating user
        }, SetOptions(merge: true));
        
        // Sign out the newly created employee immediately
        // Wait a moment for the profile writes to complete
        await Future.delayed(const Duration(milliseconds: 200));
        await FirebaseAuth.instance.signOut();
        
        // Wait for sign out to propagate
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Return the admin UID so the caller can verify/administer re-authentication
        return adminUid;
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      // Provide user-friendly error messages
      String errorMessage = 'Failed to create employee account';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please use a different email or leave email/password empty.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please enter a valid email address (e.g., user@example.com).';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password (at least 6 characters).';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password authentication is not enabled. Please contact support.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials provided. Please check your email and password.';
          break;
        default:
          errorMessage = 'Failed to create employee account: ${e.message ?? e.code}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Catch any other errors and provide helpful context
      String errorMessage = 'Failed to create employee';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('email-already-in-use') || errorString.contains('already registered')) {
        errorMessage = 'This email is already registered. Please use a different email or leave email/password empty.';
      } else if (errorString.contains('invalid-email') || errorString.contains('invalid email')) {
        errorMessage = 'Invalid email format. Please enter a valid email address (e.g., user@example.com).';
      } else if (errorString.contains('weak-password') || errorString.contains('password')) {
        errorMessage = 'Password is too weak. Please use a stronger password (at least 6 characters).';
      } else if (errorString.contains('bad request') || errorString.contains('400')) {
        errorMessage = 'Invalid request. Please check that email is valid and password is at least 6 characters.';
      } else {
        errorMessage = 'Failed to create employee: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  static Future<void> deleteEmployee(String uid) async {
    // Cannot delete FirebaseAuth users from client SDK; remove Firestore profile only
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  static Future<void> cleanupOrphanedEmployees() async {
    // Placeholder: no-op
    return;
  }

  // Helpers for company/admin
  static Future<String?> getCompanyNameByCompanyId(String? companyId) async {
    if (companyId == null) return null;
    final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
    return doc.data()?['name'] as String?;
  }

  static Future<dynamic> getCompanyAdmin(String uid) async {
    // Check company_admins collection first
    final adminDoc = await FirebaseFirestore.instance.collection('company_admins').doc(uid).get();
    if (adminDoc.exists) {
      return adminDoc.data();
    }
    
    // Fallback: check users collection (for legacy admins)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data();
  }
}


