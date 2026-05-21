import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../core/constants.dart';
import '../models/finance_entry_model.dart';

class FinanceService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<FinanceBalanceModel?> watchBalance() => _db
      .collection(AppConstants.colFinanceBalance)
      .doc(AppConstants.docBalance)
      .snapshots()
      .map((s) => s.exists ? FinanceBalanceModel.fromFirestore(s) : null);

  Stream<List<FinanceEntryModel>> watchEntries() => _db
      .collection(AppConstants.colFinanceEntries)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FinanceEntryModel.fromFirestore).toList());

  Future<void> addExpense({
    required String userId,
    required double amount,
    required String description,
    Uint8List? receiptBytes,
    String? receiptFileName,
  }) async {
    String? receiptUrl;
    if (receiptBytes != null && receiptFileName != null) {
      final ref = _storage
          .ref()
          .child('receipts/${DateTime.now().millisecondsSinceEpoch}_$receiptFileName');
      await ref.putData(receiptBytes);
      receiptUrl = await ref.getDownloadURL();
    }

    // Add entry
    await _db.collection(AppConstants.colFinanceEntries).add({
      'userId': userId,
      'amount': amount,
      'description': description,
      if (receiptUrl != null) 'receiptImageUrl': receiptUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });

    // Deduct from balance
    await _db
        .collection(AppConstants.colFinanceBalance)
        .doc(AppConstants.docBalance)
        .set(
      {
        'currentBalance': FieldValue.increment(-amount),
        'lastUpdatedBy': userId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateBalance(double newBalance, String userId) async {
    await _db
        .collection(AppConstants.colFinanceBalance)
        .doc(AppConstants.docBalance)
        .set({
      'currentBalance': newBalance,
      'lastUpdatedBy': userId,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry(String entryId, String deletedBy) async {
    final doc = await _db
        .collection(AppConstants.colFinanceEntries)
        .doc(entryId)
        .get();
    if (!doc.exists) return;
    final amount = (doc.data()!['amount'] as num).toDouble();

    await doc.reference
        .update({'isDeleted': true, 'deletedBy': deletedBy});

    // Restore amount to balance
    await _db
        .collection(AppConstants.colFinanceBalance)
        .doc(AppConstants.docBalance)
        .set(
      {
        'currentBalance': FieldValue.increment(amount),
        'lastUpdatedBy': deletedBy,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateEntry({
    required String entryId,
    required double newAmount,
    required double oldAmount,
    required String description,
    required String updatedBy,
  }) async {
    await _db.collection(AppConstants.colFinanceEntries).doc(entryId).update({
      'amount': newAmount,
      'description': description,
    });
    final diff = oldAmount - newAmount;
    await _db
        .collection(AppConstants.colFinanceBalance)
        .doc(AppConstants.docBalance)
        .set(
      {
        'currentBalance': FieldValue.increment(diff),
        'lastUpdatedBy': updatedBy,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
