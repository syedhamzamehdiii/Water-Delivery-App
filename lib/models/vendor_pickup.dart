import 'package:cloud_firestore/cloud_firestore.dart';

class VendorPickup {
  final String id;
  final String vendorId;
  final String vendorName;
  final String driverId;
  final String driverName;
  final int bottlesPicked;
  final int perBottleRate;
  final int calculatedAmount; // bottlesPicked × perBottleRate
  final int amountPaid;
  final DateTime pickupDate;
  final DateTime createdAt;
  final String? companyId;

  VendorPickup({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.driverId,
    required this.driverName,
    required this.bottlesPicked,
    required this.perBottleRate,
    required this.calculatedAmount,
    required this.amountPaid,
    required this.pickupDate,
    required this.createdAt,
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'driverId': driverId,
      'driverName': driverName,
      'bottlesPicked': bottlesPicked,
      'perBottleRate': perBottleRate,
      'calculatedAmount': calculatedAmount,
      'amountPaid': amountPaid,
      'pickupDate': pickupDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory VendorPickup.fromJson(Map<String, dynamic> json) {
    return VendorPickup(
      id: json['id'] ?? '',
      vendorId: json['vendorId'] ?? '',
      vendorName: json['vendorName'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      bottlesPicked: json['bottlesPicked'] ?? 0,
      perBottleRate: json['perBottleRate'] ?? 0,
      calculatedAmount: json['calculatedAmount'] ?? 0,
      amountPaid: json['amountPaid'] ?? 0,
      pickupDate: json['pickupDate'] != null
          ? (json['pickupDate'] is Timestamp
              ? (json['pickupDate'] as Timestamp).toDate()
              : DateTime.parse(json['pickupDate']))
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      companyId: json['companyId'],
    );
  }
}

