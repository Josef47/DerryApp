import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/drive_link_model.dart';

class DriveService {
  final _db = FirebaseFirestore.instance;

  Stream<List<DriveLinkModel>> watchLinks() => _db
      .collection(AppConstants.colDriveLinks)
      .snapshots()
      .map((s) => s.docs.map(DriveLinkModel.fromFirestore).toList());

  Future<void> addLink(DriveLinkModel link) async {
    await _db.collection(AppConstants.colDriveLinks).add(link.toFirestore());
  }

  Future<void> deleteLink(String linkId) async {
    await _db.collection(AppConstants.colDriveLinks).doc(linkId).delete();
  }
}
