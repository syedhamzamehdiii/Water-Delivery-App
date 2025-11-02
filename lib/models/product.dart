import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String size;
  final int? price;
  final bool? isAvailable;
  final String? description;
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.size,
    this.price,
    this.isAvailable,
    this.description,
    this.companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.imageUrl,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'price': price,
    'isAvailable': isAvailable,
    'description': description,
    'companyId': companyId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'imageUrl': imageUrl,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    size: json['size'] ?? '',
    price: json['price'],
    isAvailable: json['isAvailable'],
    description: json['description'],
    companyId: json['companyId'],
    createdAt: _parseDateTime(json['createdAt']),
    updatedAt: _parseDateTime(json['updatedAt']),
    imageUrl: json['imageUrl'],
  );

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  Product copyWith({
    String? id,
    String? name,
    String? size,
    int? price,
    bool? isAvailable,
    String? description,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, size: $size, price: $price, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

