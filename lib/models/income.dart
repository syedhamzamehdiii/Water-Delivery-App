import 'package:cloud_firestore/cloud_firestore.dart';

class Income {
  final String id;
  final String title;
  final String description;
  final int amount;
  final String source; // 'automatic' or 'manual'
  final String? orderId; // For automatic income from orders
  final String? customerId; // Customer ID for automatic income from orders
  final String? customerName; // Customer name for display
  final DateTime date;
  final DateTime createdAt;
  final String? companyId; // For company-specific data isolation

  Income({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.source,
    this.orderId,
    this.customerId,
    this.customerName,
    required this.date,
    required this.createdAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'source': source,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      source: json['source'] ?? '',
      orderId: json['orderId'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      date: json['date'] != null 
          ? (json['date'] is Timestamp 
              ? (json['date'] as Timestamp).toDate()
              : DateTime.parse(json['date']))
          : DateTime.now(),
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      companyId: json['companyId'],
    );
  }

  Income copyWith({
    String? id,
    String? title,
    String? description,
    int? amount,
    String? source,
    String? orderId,
    String? customerId,
    String? customerName,
    DateTime? date,
    DateTime? createdAt,
    String? companyId,
  }) {
    return Income(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      companyId: companyId ?? this.companyId,
    );
  }
}
