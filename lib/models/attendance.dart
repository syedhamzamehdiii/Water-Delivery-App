import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final String status; // 'Present', 'Absent', 'Paid Holiday', 'Half Day', 'Overtime', 'Late Fine'
  final String? notes; // For reasons, comments, etc.
  final double? overtimeHours; // For overtime records
  final double? fineAmount; // For late fine records
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.status,
    this.notes,
    this.overtimeHours,
    this.fineAmount,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(date), // Save as Timestamp for Firestore queries
      'status': status,
      'notes': notes,
      'overtimeHours': overtimeHours,
      'fineAmount': fineAmount,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      date: _parseDateTime(json['date']),
      status: json['status'] ?? 'Present',
      notes: json['notes'],
      overtimeHours: json['overtimeHours']?.toDouble(),
      fineAmount: json['fineAmount']?.toDouble(),
      companyId: json['companyId'],
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

  Attendance copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? date,
    String? status,
    String? notes,
    double? overtimeHours,
    double? fineAmount,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      fineAmount: fineAmount ?? this.fineAmount,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

