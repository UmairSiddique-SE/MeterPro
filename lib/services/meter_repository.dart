import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meter.dart';

/// Persists every user's meters in Cloud Firestore under
/// `users/{uid}/meters/{meterId}` so data survives app restarts, reinstalls,
/// and syncs automatically across every device they sign into.
class MeterRepository {
  MeterRepository._();
  static final MeterRepository instance = MeterRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _metersCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('meters');
  }

  /// Live stream of the signed-in user's meters, newest first. Emits an
  /// empty list (instead of erroring) if nobody is signed in.
  Stream<List<MeterModel>> watchMeters() {
    final col = _metersCol;
    if (col == null) return Stream.value(const []);
    return col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((d) => MeterModel.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Saves a brand-new meter and returns the generated document id.
  Future<String> addMeter(MeterModel meter) async {
    final col = _metersCol;
    if (col == null) throw StateError('No signed-in user');
    final docRef = col.doc();
    await docRef.set({
      ...meter.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Updates an existing meter (e.g. after a new reading is recorded).
  Future<void> updateMeter(MeterModel meter) async {
    final col = _metersCol;
    if (col == null) throw StateError('No signed-in user');
    await col.doc(meter.id).update(meter.toMap());
  }

  Future<void> deleteMeter(String id) async {
    final col = _metersCol;
    if (col == null) throw StateError('No signed-in user');
    await col.doc(id).delete();
  }

  /// Checks both identifiers across every user's meter collection.
  Future<bool> checkGlobalMeterIdentity({
    required String referenceNo,
    required String meterNo,
  }) async {
    final references = await _db
        .collectionGroup('meters')
        .where('referenceNo', isEqualTo: referenceNo.trim())
        .limit(1)
        .get();
    if (references.docs.isNotEmpty) return true;

    final meterNumbers = await _db
        .collectionGroup('meters')
        .where('meterNo', isEqualTo: meterNo.trim())
        .limit(1)
        .get();
    return meterNumbers.docs.isNotEmpty;
  }
}
