import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyAdmin {
  final String uid;
  final String email;
  final String password; // Note: In production, this should be hashed
  final String? companyName;
  final String companyId; // Unique identifier for company data isolation
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyAdmin({
    required this.uid,
    required this.email,
    required this.password,
    this.companyName,
    required this.companyId,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'password': password,
      'companyName': companyName,
      'companyId': companyId,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CompanyAdmin.fromJson(Map<String, dynamic> json) {
    return CompanyAdmin(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      companyName: json['companyName'],
      companyId: json['companyId'] ?? '',
      role: json['role'] ?? 'admin',
      isActive: json['isActive'] ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
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

  CompanyAdmin copyWith({
    String? uid,
    String? email,
    String? password,
    String? companyName,
    String? companyId,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyAdmin(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      password: password ?? this.password,
      companyName: companyName ?? this.companyName,
      companyId: companyId ?? this.companyId,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
