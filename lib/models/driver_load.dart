import 'package:cloud_firestore/cloud_firestore.dart';

class DriverLoad {
  final String id;
  final String driverId;
  final String driverName;
  final DateTime date;
  final int? vehicleCapacity; // Total vehicle capacity (set once by driver)
  final int bottlesAssigned; // How many bottles in pending orders (calculated from orders with quantity)
  final int bottlesDelivered; // How many bottles delivered today
  final int bottlesRemaining; // Available capacity (vehicleCapacity - bottlesAssigned)
  final int totalBottlesSold; // Total bottles sold by driver
  final int cashCollected; // Cash collected from customers
  final List<String> cashCustomers; // List of customer IDs who paid cash
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId; // For company-specific data isolation

  DriverLoad({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.date,
    this.vehicleCapacity,
    required this.bottlesAssigned,
    required this.bottlesDelivered,
    required this.bottlesRemaining,
    required this.totalBottlesSold,
    required this.cashCollected,
    required this.cashCustomers,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'driverName': driverName,
      'date': date.toIso8601String(),
      'vehicleCapacity': vehicleCapacity,
      'bottlesAssigned': bottlesAssigned,
      'bottlesDelivered': bottlesDelivered,
      'bottlesRemaining': bottlesRemaining,
      'totalBottlesSold': totalBottlesSold,
      'cashCollected': cashCollected,
      'cashCustomers': cashCustomers,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory DriverLoad.fromJson(Map<String, dynamic> json) {
    return DriverLoad(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      date: json['date'] != null 
          ? (json['date'] is Timestamp 
              ? (json['date'] as Timestamp).toDate()
              : DateTime.parse(json['date']))
          : DateTime.now(),
      vehicleCapacity: json['vehicleCapacity'] ?? json['bottlesLoaded'], // Backward compatibility
      bottlesAssigned: json['bottlesAssigned'] ?? 0,
      bottlesDelivered: json['bottlesDelivered'] ?? 0,
      bottlesRemaining: json['bottlesRemaining'] ?? 0,
      totalBottlesSold: json['totalBottlesSold'] ?? 0,
      cashCollected: json['cashCollected'] ?? 0,
      cashCustomers: List<String>.from(json['cashCustomers'] ?? []),
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

  DriverLoad copyWith({
    String? id,
    String? driverId,
    String? driverName,
    DateTime? date,
    int? vehicleCapacity,
    int? bottlesAssigned,
    int? bottlesDelivered,
    int? bottlesRemaining,
    int? totalBottlesSold,
    int? cashCollected,
    List<String>? cashCustomers,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return DriverLoad(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      date: date ?? this.date,
      vehicleCapacity: vehicleCapacity ?? this.vehicleCapacity,
      bottlesAssigned: bottlesAssigned ?? this.bottlesAssigned,
      bottlesDelivered: bottlesDelivered ?? this.bottlesDelivered,
      bottlesRemaining: bottlesRemaining ?? this.bottlesRemaining,
      totalBottlesSold: totalBottlesSold ?? this.totalBottlesSold,
      cashCollected: cashCollected ?? this.cashCollected,
      cashCustomers: cashCustomers ?? this.cashCustomers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }
}
