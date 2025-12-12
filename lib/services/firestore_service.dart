import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _citasCollection => _db.collection('citas');

  // Create a new appointment
  Future<void> createCita(Map<String, dynamic> citaData) async {
    try {
      await _citasCollection.add(citaData);
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Get appointments for a specific user
  Stream<QuerySnapshot> getCitasForUser(String userId) {
    return _citasCollection
        .where('userId', isEqualTo: userId)
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  // Update appointment status
  Future<void> updateCitaStatus(String id, String status) async {
    await _citasCollection.doc(id).update({'estado': status});
  }

  // Update appointment details
  Future<void> updateCita(String id, Map<String, dynamic> data) async {
    await _citasCollection.doc(id).update(data);
  }

  // Get all appointments (for admin)
  Stream<QuerySnapshot> getAllCitas() {
    return _citasCollection.orderBy('fecha', descending: true).snapshots();
  }

  // --- Departamentos & Tramites ---

  CollectionReference get _departamentosCollection => _db.collection('departamentos');

  // Create a Department
  Future<void> addDepartamento(String nombre) async {
    try {
      await _departamentosCollection.doc(nombre).set({
        'tramites': []
      });
    } catch (e) {
       print("Error adding department: $e");
       rethrow;
    }
  }

  // Delete a Department
  Future<void> deleteDepartamento(String id) async {
    try {
      await _departamentosCollection.doc(id).delete();
    } catch (e) {
      print("Error deleting department: $e");
       rethrow;
    }
  }

  // Get Departments Stream
  Stream<QuerySnapshot> getDepartamentos() {
    return _departamentosCollection.snapshots();
  }

  // Add Tramite to Department
  Future<void> addTramite(String departamentoId, String tramite) async {
    try {
      await _departamentosCollection.doc(departamentoId).update({
        'tramites': FieldValue.arrayUnion([tramite])
      });
    } catch (e) {
      print("Error adding tramite: $e");
      rethrow;
    }
  }

  // Remove Tramite from Department
  Future<void> deleteTramite(String departamentoId, String tramite) async {
    try {
      await _departamentosCollection.doc(departamentoId).update({
        'tramites': FieldValue.arrayRemove([tramite])
      });
    } catch (e) {
      print("Error deleting tramite: $e");
      rethrow;
    }
  }
}
