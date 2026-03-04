import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> updateLocation({
    required String deviceId,
    required double lat,
    required double lng,
    required String state,
    required String pairedWith,
  }) async {
    await _db.collection('devices').doc(deviceId).set({
      'latitude': lat,
      'longitude': lng,
      'state': state,
      'pairedWith': pairedWith,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> listenToDevice(String deviceId) {
    return _db.collection('devices').doc(deviceId).snapshots();
  }
}
