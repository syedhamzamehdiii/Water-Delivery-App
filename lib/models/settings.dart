import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  final String id;
  final double salesTaxPercentage; // Sales tax percentage (e.g., 15.0 for 15%)
  final String? companyId; // For company-specific settings
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    required this.salesTaxPercentage,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'salesTaxPercentage': salesTaxPercentage,
      'companyId': companyId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] ?? '',
      salesTaxPercentage: (json['salesTaxPercentage'] ?? 15.0).toDouble(),
      companyId: json['companyId'],
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
    );
  }

  AppSettings copyWith({
    String? id,
    double? salesTaxPercentage,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      salesTaxPercentage: salesTaxPercentage ?? this.salesTaxPercentage,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
