import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../core/constants.dart';
import '../models/shopping_item_model.dart';
import '../models/loyalty_card_model.dart';

class ShoppingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<List<ShoppingItemModel>> watchActiveItems() => _db
      .collection(AppConstants.colShoppingItems)
      .where('archived', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(ShoppingItemModel.fromFirestore).toList());

  Stream<List<ShoppingItemModel>> watchArchivedItems() => _db
      .collection(AppConstants.colShoppingItems)
      .where('archived', isEqualTo: true)
      .orderBy('boughtAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ShoppingItemModel.fromFirestore).toList());

  Stream<List<ShoppingCategoryModel>> watchCategories() => _db
      .collection(AppConstants.colShoppingCategories)
      .snapshots()
      .map((s) => s.docs.map(ShoppingCategoryModel.fromFirestore).toList());

  Stream<List<LoyaltyCardModel>> watchLoyaltyCards() => _db
      .collection(AppConstants.colLoyaltyCards)
      .snapshots()
      .map((s) => s.docs.map(LoyaltyCardModel.fromFirestore).toList());

  Future<void> addItem(ShoppingItemModel item, {Uint8List? imageBytes, String? fileName}) async {
    String? imageUrl;
    if (imageBytes != null && fileName != null) {
      final ref = _storage.ref().child('shopping/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await ref.putData(imageBytes);
      imageUrl = await ref.getDownloadURL();
    }
    final data = item.toFirestore();
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    await _db.collection(AppConstants.colShoppingItems).add(data);
  }

  Future<void> markBought(String itemId, String userId) async {
    await _db.collection(AppConstants.colShoppingItems).doc(itemId).update({
      'archived': true,
      'boughtBy': userId,
      'boughtAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _db.collection(AppConstants.colShoppingItems).doc(itemId).delete();
  }

  Future<void> addCategory(String name, String createdBy) async {
    await _db.collection(AppConstants.colShoppingCategories).add({
      'name': name,
      'createdBy': createdBy,
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.collection(AppConstants.colShoppingCategories).doc(categoryId).delete();
  }

  Future<void> addLoyaltyCard(LoyaltyCardModel card, {Uint8List? imageBytes, String? fileName}) async {
    String? imageUrl;
    if (imageBytes != null && fileName != null) {
      final ref = _storage.ref().child('loyalty/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await ref.putData(imageBytes);
      imageUrl = await ref.getDownloadURL();
    }
    final data = card.toFirestore();
    if (imageUrl != null) data['cardImageUrl'] = imageUrl;
    await _db.collection(AppConstants.colLoyaltyCards).add(data);
  }

  Future<void> deleteLoyaltyCard(String cardId) async {
    await _db.collection(AppConstants.colLoyaltyCards).doc(cardId).delete();
  }
}
