import 'package:cloud_firestore/cloud_firestore.dart';

class AutoOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerArea;
  final int quantity;
  final int price;
  final int? salesTax;
  final String assignedDriver;
  final String dayOfWeek; // e.g., "Monday", "Tuesday"
  final DateTime nextDeliveryDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyId;

  AutoOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerArea,
    required this.quantity,
    required this.price,
    this.salesTax,
    required this.assignedDriver,
    required this.dayOfWeek,
    required this.nextDeliveryDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  });

  factory AutoOrder.fromJson(Map<String, dynamic> json) {
    // Helper function to convert Timestamp to DateTime
    DateTime _convertTimestamp(dynamic timestamp) {
      try {
        // Handle null timestamp
        if (timestamp == null) {
          return DateTime.now();
        }
        
        // Handle Timestamp object
        if (timestamp is Timestamp) {
          return timestamp.toDate();
        }
        
        // Handle web Timestamp format
        if (timestamp is Map) {
          try {
            // Try to extract seconds and nanoseconds from web format
            dynamic seconds = timestamp['_seconds'] ?? timestamp['seconds'];
            dynamic nanoseconds = timestamp['_nanoseconds'] ?? timestamp['nanoseconds'] ?? 0;
            
            if (seconds != null) {
              int sec = seconds is int ? seconds : int.tryParse(seconds.toString()) ?? 0;
              int nano = nanoseconds is int ? nanoseconds : int.tryParse(nanoseconds.toString()) ?? 0;
              final milliseconds = (sec * 1000) + (nano ~/ 1000000);
              return DateTime.fromMillisecondsSinceEpoch(milliseconds);
            }
          } catch (e) {
            return DateTime.now();
          }
        }
        
        // Handle string timestamp
        if (timestamp is String) {
          try {
            return DateTime.parse(timestamp);
          } catch (e) {
            return DateTime.now();
          }
        }
      } catch (e) {
        // Return current time on error
      }
      
      // If all else fails, return current time
      return DateTime.now();
    }

    return AutoOrder(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerArea: json['customerArea'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      salesTax: (json['salesTax'] as num?)?.toInt(),
      assignedDriver: json['assignedDriver'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      nextDeliveryDate: _convertTimestamp(json['nextDeliveryDate']),
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: _convertTimestamp(json['createdAt']),
      updatedAt: _convertTimestamp(json['updatedAt']),
      companyId: json['companyId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerArea': customerArea,
      'quantity': quantity,
      'price': price,
      'salesTax': salesTax,
      'assignedDriver': assignedDriver,
      'dayOfWeek': dayOfWeek,
      'nextDeliveryDate': Timestamp.fromDate(nextDeliveryDate),
      'isActive': isActive,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'companyId': companyId,
    };
  }

  AutoOrder copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerArea,
    int? quantity,
    int? price,
    int? salesTax,
    String? assignedDriver,
    String? dayOfWeek,
    DateTime? nextDeliveryDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return AutoOrder(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerArea: customerArea ?? this.customerArea,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      salesTax: salesTax ?? this.salesTax,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      nextDeliveryDate: nextDeliveryDate ?? this.nextDeliveryDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }

  static DateTime getNextDeliveryDate(String dayOfWeek) {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final targetWeekday = days.indexOf(dayOfWeek) + 1; // Dart's weekday is 1-7 (Monday-Sunday)

    int daysUntilNext = targetWeekday - now.weekday;
    if (daysUntilNext <= 0) {
      daysUntilNext += 7; // Schedule for next week if the day has passed or is today
    }
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilNext));
  }
}

