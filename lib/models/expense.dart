import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final String description;
  final int amount;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String? companyId; // For company-specific data isolation

  Expense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
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
      'category': category,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      category: json['category'] ?? '',
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

  Expense copyWith({
    String? id,
    String? title,
    String? description,
    int? amount,
    String? category,
    DateTime? date,
    DateTime? createdAt,
    String? companyId,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      companyId: companyId ?? this.companyId,
    );
  }
}
