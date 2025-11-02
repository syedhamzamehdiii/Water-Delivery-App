import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  final String customerId;
  final String customerName;
  final List<String> orderIds;
  final int subtotal;
  final int salesTax; // Sales tax amount
  final double salesTaxRate; // Sales tax rate (e.g., 0.15 for 15%)
  final int total;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String status; // 'pending', 'paid', 'overdue'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId; // For company-specific data isolation

  Invoice({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.orderIds,
    required this.subtotal,
    required this.salesTax,
    required this.salesTaxRate,
    required this.total,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'orderIds': orderIds,
      'subtotal': subtotal,
      'salesTax': salesTax,
      'salesTaxRate': salesTaxRate,
      'total': total,
      'invoiceDate': invoiceDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      orderIds: List<String>.from(json['orderIds'] ?? []),
      subtotal: json['subtotal'] ?? 0,
      salesTax: json['salesTax'] ?? 0,
      salesTaxRate: (json['salesTaxRate'] ?? 0.0).toDouble(),
      total: json['total'] ?? 0,
      invoiceDate: json['invoiceDate'] != null 
          ? (json['invoiceDate'] is Timestamp 
              ? (json['invoiceDate'] as Timestamp).toDate()
              : DateTime.parse(json['invoiceDate']))
          : DateTime.now(),
      dueDate: json['dueDate'] != null 
          ? (json['dueDate'] is Timestamp 
              ? (json['dueDate'] as Timestamp).toDate()
              : DateTime.parse(json['dueDate']))
          : DateTime.now().add(const Duration(days: 30)),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] is Timestamp 
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt']))
          : DateTime.now(),
      companyId: json['companyId'],
    );
  }

  Invoice copyWith({
    String? id,
    String? customerId,
    String? customerName,
    List<String>? orderIds,
    int? subtotal,
    int? salesTax,
    double? salesTaxRate,
    int? total,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return Invoice(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderIds: orderIds ?? this.orderIds,
      subtotal: subtotal ?? this.subtotal,
      salesTax: salesTax ?? this.salesTax,
      salesTaxRate: salesTaxRate ?? this.salesTaxRate,
      total: total ?? this.total,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }

  // Helper method to calculate sales tax
  static int calculateSalesTax(int subtotal, double taxRate) {
    return (subtotal * taxRate).round();
  }

  // Helper method to calculate total with tax
  static int calculateTotal(int subtotal, double taxRate) {
    return subtotal + calculateSalesTax(subtotal, taxRate);
  }
}
