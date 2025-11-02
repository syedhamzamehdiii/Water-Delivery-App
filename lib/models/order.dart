import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerId;
  final String? customerName;
  final int quantity;
  final int price;
  final int? salesTax; // Sales tax amount (nullable for backward compatibility)
  final String status; // 'Pending', 'Delivered'
  final DateTime orderDate;
  final String? handledBy;
  final String? notes;
  final String? assignedDriver; // Driver assigned to this order
  final String? paymentMethod; // Payment method used when delivered
  final int? amountCollected; // Total amount collected (sum of positive payments)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId; // For company-specific data isolation

  OrderModel({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.quantity,
    required this.price,
    this.salesTax,
    required this.status,
    required this.orderDate,
    this.handledBy,
    this.notes,
    this.assignedDriver,
    this.paymentMethod,
    this.amountCollected,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'quantity': quantity,
      'price': price,
      'salesTax': salesTax,
      'status': status,
      'orderDate': orderDate.toIso8601String(),
      'handledBy': handledBy,
      'notes': notes,
      'assignedDriver': assignedDriver,
      'paymentMethod': paymentMethod,
      'amountCollected': amountCollected,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'],
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
      salesTax: json['salesTax'] ?? 0,
      status: json['status'] ?? 'Pending',
      orderDate: _parseDateTime(json['orderDate']),
      handledBy: json['handledBy'],
      notes: json['notes'],
      assignedDriver: json['assignedDriver'],
      paymentMethod: json['paymentMethod'],
      amountCollected: json['amountCollected'] != null ? (json['amountCollected'] is int ? json['amountCollected'] : int.tryParse(json['amountCollected'].toString())) : null,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      companyId: json['companyId'],
    );
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }
    
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    
    if (dateValue is DateTime) {
      return dateValue;
    }
    
    return DateTime.now();
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    int? quantity,
    int? price,
    int? salesTax,
    String? status,
    DateTime? orderDate,
    String? handledBy,
    String? notes,
    String? assignedDriver,
    String? paymentMethod,
    int? amountCollected,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      salesTax: salesTax ?? this.salesTax,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      handledBy: handledBy ?? this.handledBy,
      notes: notes ?? this.notes,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountCollected: amountCollected ?? this.amountCollected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }
}
