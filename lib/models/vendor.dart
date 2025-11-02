import 'package:cloud_firestore/cloud_firestore.dart';

class Vendor {
  final String id;
  final String name;
  final int totalBottles;
  final int totalPrice;
  final int perBottleRate; // Per bottle rate
  final DateTime dateAdded; // Date when vendor was added
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId; // For company-specific data isolation

  Vendor({
    required this.id,
    required this.name,
    required this.totalBottles,
    required this.totalPrice,
    required this.perBottleRate,
    required this.dateAdded,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'totalBottles': totalBottles,
      'totalPrice': totalPrice,
      'perBottleRate': perBottleRate,
      'dateAdded': dateAdded.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      totalBottles: json['totalBottles'] ?? 0,
      totalPrice: json['totalPrice'] ?? 0,
      perBottleRate: json['perBottleRate'] ?? 0,
      dateAdded: json['dateAdded'] != null 
          ? (json['dateAdded'] is Timestamp 
              ? (json['dateAdded'] as Timestamp).toDate()
              : DateTime.parse(json['dateAdded']))
          : DateTime.now(),
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

  Vendor copyWith({
    String? id,
    String? name,
    int? totalBottles,
    int? totalPrice,
    int? perBottleRate,
    DateTime? dateAdded,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      totalBottles: totalBottles ?? this.totalBottles,
      totalPrice: totalPrice ?? this.totalPrice,
      perBottleRate: perBottleRate ?? this.perBottleRate,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }
}
