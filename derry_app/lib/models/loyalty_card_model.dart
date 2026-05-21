import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyCardModel {
  final String id;
  final String storeName;
  final String? cardImageUrl;
  final String? barcodeValue;
  final String? barcodeType;
  final String addedBy;

  const LoyaltyCardModel({
    required this.id,
    required this.storeName,
    this.cardImageUrl,
    this.barcodeValue,
    this.barcodeType,
    required this.addedBy,
  });

  factory LoyaltyCardModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LoyaltyCardModel(
      id: doc.id,
      storeName: d['storeName'] ?? '',
      cardImageUrl: d['cardImageUrl'],
      barcodeValue: d['barcodeValue'],
      barcodeType: d['barcodeType'],
      addedBy: d['addedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'storeName': storeName,
        if (cardImageUrl != null) 'cardImageUrl': cardImageUrl,
        if (barcodeValue != null) 'barcodeValue': barcodeValue,
        if (barcodeType != null) 'barcodeType': barcodeType,
        'addedBy': addedBy,
      };
}
