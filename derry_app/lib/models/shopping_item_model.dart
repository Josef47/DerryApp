import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItemModel {
  final String id;
  final String title;
  final String category;
  final String? description;
  final DateTime? deadline;
  final String urgency; // Low | Medium | High
  final String? imageUrl;
  final double? expectedPrice;
  final String addedBy;
  final String? boughtBy;
  final DateTime? boughtAt;
  final bool archived;

  const ShoppingItemModel({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.deadline,
    this.urgency = 'Low',
    this.imageUrl,
    this.expectedPrice,
    required this.addedBy,
    this.boughtBy,
    this.boughtAt,
    this.archived = false,
  });

  factory ShoppingItemModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ShoppingItemModel(
      id: doc.id,
      title: d['title'] ?? '',
      category: d['category'] ?? '',
      description: d['description'],
      deadline: (d['deadline'] as Timestamp?)?.toDate(),
      urgency: d['urgency'] ?? 'Low',
      imageUrl: d['imageUrl'],
      expectedPrice: (d['expectedPrice'] as num?)?.toDouble(),
      addedBy: d['addedBy'] ?? '',
      boughtBy: d['boughtBy'],
      boughtAt: (d['boughtAt'] as Timestamp?)?.toDate(),
      archived: d['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'category': category,
        if (description != null) 'description': description,
        if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
        'urgency': urgency,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (expectedPrice != null) 'expectedPrice': expectedPrice,
        'addedBy': addedBy,
        if (boughtBy != null) 'boughtBy': boughtBy,
        if (boughtAt != null) 'boughtAt': Timestamp.fromDate(boughtAt!),
        'archived': archived,
      };
}

class ShoppingCategoryModel {
  final String id;
  final String name;
  final String createdBy;

  const ShoppingCategoryModel({
    required this.id,
    required this.name,
    required this.createdBy,
  });

  factory ShoppingCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ShoppingCategoryModel(
      id: doc.id,
      name: d['name'] ?? '',
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'createdBy': createdBy,
      };
}
