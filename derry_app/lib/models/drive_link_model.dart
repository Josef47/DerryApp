import 'package:cloud_firestore/cloud_firestore.dart';

class DriveLinkModel {
  final String id;
  final String label;
  final String url;
  final String type; // folder | file
  final String addedBy;

  const DriveLinkModel({
    required this.id,
    required this.label,
    required this.url,
    required this.type,
    required this.addedBy,
  });

  factory DriveLinkModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DriveLinkModel(
      id: doc.id,
      label: d['label'] ?? '',
      url: d['url'] ?? '',
      type: d['type'] ?? 'file',
      addedBy: d['addedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'label': label,
        'url': url,
        'type': type,
        'addedBy': addedBy,
      };
}
