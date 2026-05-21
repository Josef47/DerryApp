import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceEntryModel {
  final String id;
  final String userId;
  final double amount;
  final String description;
  final String? receiptImageUrl;
  final DateTime createdAt;
  final String? deletedBy;
  final bool isDeleted;

  const FinanceEntryModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.description,
    this.receiptImageUrl,
    required this.createdAt,
    this.deletedBy,
    this.isDeleted = false,
  });

  factory FinanceEntryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FinanceEntryModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      description: d['description'] ?? '',
      receiptImageUrl: d['receiptImageUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedBy: d['deletedBy'],
      isDeleted: d['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'amount': amount,
        'description': description,
        if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        if (deletedBy != null) 'deletedBy': deletedBy,
        'isDeleted': isDeleted,
      };
}

class FinanceBalanceModel {
  final double currentBalance;
  final String lastUpdatedBy;
  final DateTime lastUpdatedAt;

  const FinanceBalanceModel({
    required this.currentBalance,
    required this.lastUpdatedBy,
    required this.lastUpdatedAt,
  });

  factory FinanceBalanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FinanceBalanceModel(
      currentBalance: (d['currentBalance'] ?? 0).toDouble(),
      lastUpdatedBy: d['lastUpdatedBy'] ?? '',
      lastUpdatedAt:
          (d['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'currentBalance': currentBalance,
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      };
}
