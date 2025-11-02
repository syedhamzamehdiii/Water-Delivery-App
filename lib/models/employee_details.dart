import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDetails {
  final String id;
  final String staffName;
  final String phoneNumber;
  final String? cnicNumber;
  final SalaryType salaryType;
  final int staffSalary;
  final int workingHours;
  final DateTime joiningDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId;

  EmployeeDetails({
    required this.id,
    required this.staffName,
    required this.phoneNumber,
    this.cnicNumber,
    required this.salaryType,
    required this.staffSalary,
    required this.workingHours,
    required this.joiningDate,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffName': staffName,
      'phoneNumber': phoneNumber,
      'cnicNumber': cnicNumber,
      'salaryType': salaryType.name,
      'staffSalary': staffSalary,
      'workingHours': workingHours,
      'joiningDate': joiningDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory EmployeeDetails.fromJson(Map<String, dynamic> json) {
    return EmployeeDetails(
      id: json['id'] ?? '',
      staffName: json['staffName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      cnicNumber: json['cnicNumber'],
      salaryType: SalaryType.values.firstWhere(
        (e) => e.name == json['salaryType'],
        orElse: () => SalaryType.monthly,
      ),
      staffSalary: json['staffSalary'] ?? 0,
      workingHours: json['workingHours'] ?? 0,
      joiningDate: _parseDateTime(json['joiningDate']),
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

  EmployeeDetails copyWith({
    String? id,
    String? staffName,
    String? phoneNumber,
    String? cnicNumber,
    SalaryType? salaryType,
    int? staffSalary,
    int? workingHours,
    DateTime? joiningDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return EmployeeDetails(
      id: id ?? this.id,
      staffName: staffName ?? this.staffName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      salaryType: salaryType ?? this.salaryType,
      staffSalary: staffSalary ?? this.staffSalary,
      workingHours: workingHours ?? this.workingHours,
      joiningDate: joiningDate ?? this.joiningDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      companyId: companyId ?? this.companyId,
    );
  }

  String get salaryTypeDisplay {
    switch (salaryType) {
      case SalaryType.monthly:
        return 'Monthly';
      case SalaryType.weekly:
        return 'Weekly';
      case SalaryType.daily:
        return 'Daily';
      case SalaryType.hourly:
        return 'Hourly';
    }
  }

  String get salarySuffix {
    switch (salaryType) {
      case SalaryType.monthly:
        return '/Month';
      case SalaryType.weekly:
        return '/Week';
      case SalaryType.daily:
        return '/Day';
      case SalaryType.hourly:
        return '/Hour';
    }
  }

  @override
  String toString() {
    return 'EmployeeDetails(id: $id, staffName: $staffName, phoneNumber: $phoneNumber, salaryType: $salaryType, staffSalary: $staffSalary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeDetails && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum SalaryType {
  monthly,
  weekly,
  daily,
  hourly,
}
