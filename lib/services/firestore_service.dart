import 'package:cloud_firestore/cloud_firestore.dart';

class HorarioOcupadoException implements Exception {
  const HorarioOcupadoException();
  @override
  String toString() => 'Horario ocupado. Selecciona otra hora.';
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _citasCollection =>
      _db.collection('citas');
  CollectionReference<Map<String, dynamic>> get _horariosCollection =>
      _db.collection('horarios_ocupados');
  CollectionReference<Map<String, dynamic>> get _disponibilidadCollection =>
      _db.collection('disponibilidad_horarios');
  CollectionReference<Map<String, dynamic>> get _departamentosCollection =>
      _db.collection('departamentos');

  String _horarioId(Map<String, dynamic> datos) {
    final departamento = datos['departamento'];
    final fecha = datos['fecha'];
    final hora = datos['hora'];
    if (departamento is! String ||
        departamento.isEmpty ||
        departamento != departamento.trim() ||
        departamento.contains('|') ||
        departamento.contains('/') ||
        fecha is! Timestamp ||
        hora is! String ||
        hora.isEmpty ||
        hora != hora.trim()) {
      throw ArgumentError('Departamento, fecha u hora invalidos.');
    }
    final dia = fecha.toDate().toUtc();
    if (dia.hour != 0 ||
        dia.minute != 0 ||
        dia.second != 0 ||
        dia.millisecond != 0 ||
        dia.microsecond != 0) {
      throw ArgumentError('La fecha debe ser las 00:00 UTC.');
    }
    return '$departamento|${dia.year}|${dia.month}|${dia.day}|$hora';
  }

  Map<String, dynamic> _datosHorario(
    String citaId,
    Map<String, dynamic> cita,
  ) => {
    'citaId': citaId,
    'userId': cita['userId'],
    'departamento': cita['departamento'],
    'fecha': cita['fecha'],
    'hora': cita['hora'],
  };

  Stream<bool> observarHorarioOcupado(
    String departamento,
    DateTime fecha,
    String hora,
  ) {
    final id = _horarioId({
      'departamento': departamento,
      'fecha': Timestamp.fromDate(
        DateTime.utc(fecha.year, fecha.month, fecha.day),
      ),
      'hora': hora,
    });
    return _disponibilidadCollection.doc(id).snapshots().map(
      (snapshot) => snapshot.exists,
    );
  }

  Future<void> createCita(Map<String, dynamic> citaData) async {
    if (citaData['estado'] != 'Activa') {
      throw ArgumentError('Una cita nueva debe comenzar como Activa.');
    }
    final id = _horarioId(citaData);
    final citaRef = _citasCollection.doc();
    final horarioRef = _horariosCollection.doc(id);
    final publicoRef = _disponibilidadCollection.doc(id);
    final cita = {...citaData, 'horarioId': id};

    // Lectura permitida por las reglas: disponibilidad sin datos personales.
    final creada = await _db.runTransaction<bool>((tx) async {
      final publico = await tx.get(publicoRef);
      if (publico.exists) return false;
      tx.set(citaRef, cita);
      tx.set(horarioRef, _datosHorario(citaRef.id, cita));
      tx.set(publicoRef, {'ocupado': true});
      return true;
    });
    if (!creada) throw const HorarioOcupadoException();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCitasForUser(String userId) =>
      _citasCollection
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .snapshots();

  Future<void> updateCitaStatus(String id, String status) async {
    if (status != 'Cancelada') {
      throw ArgumentError('Este metodo solo permite cancelar citas.');
    }
    final citaRef = _citasCollection.doc(id);
    await _db.runTransaction((tx) async {
      final citaDoc = await tx.get(citaRef);
      if (!citaDoc.exists) throw StateError('La cita no existe.');
      final cita = citaDoc.data()!;
      if (cita['estado'] != 'Activa') {
        throw StateError('Solo se pueden cancelar citas activas.');
      }
      final idHorario = _horarioId(cita);
      if (cita['horarioId'] != idHorario) {
        throw StateError('Reserva de la cita inconsistente.');
      }
      final horarioRef = _horariosCollection.doc(idHorario);
      final publicoRef = _disponibilidadCollection.doc(idHorario);
      // Las reglas permiten leer la reserva privada a su propio titular.
      final horario = await tx.get(horarioRef);
      final publico = await tx.get(publicoRef);
      if (!horario.exists || horario.data()?['citaId'] != id || !publico.exists) {
        throw StateError('No coincide la reserva o su indicador publico.');
      }
      tx.update(citaRef, {'estado': 'Cancelada'});
      tx.delete(horarioRef);
      tx.delete(publicoRef);
    });
  }

  Future<void> updateCita(String id, Map<String, dynamic> cambios) async {
    const permitidos = {'fecha', 'hora', 'servicio'};
    if (cambios.isEmpty || cambios.keys.any((k) => !permitidos.contains(k))) {
      throw ArgumentError('Campos no permitidos para modificar una cita.');
    }
    final citaRef = _citasCollection.doc(id);
    final resultado = await _db.runTransaction<bool>((tx) async {
      final citaDoc = await tx.get(citaRef);
      if (!citaDoc.exists) throw StateError('La cita no existe.');
      final actual = citaDoc.data()!;
      if (actual['estado'] != 'Activa') {
        throw StateError('Solo se pueden modificar citas activas.');
      }
      final actualizada = {...actual, ...cambios};
      final idAnterior = _horarioId(actual);
      final idNuevo = _horarioId(actualizada);
      if (actual['horarioId'] != idAnterior) {
        throw StateError('Reserva de la cita inconsistente.');
      }
      final anteriorRef = _horariosCollection.doc(idAnterior);
      final anteriorPublicoRef = _disponibilidadCollection.doc(idAnterior);
      final anterior = await tx.get(anteriorRef);
      final anteriorPublico = await tx.get(anteriorPublicoRef);
      if (!anterior.exists || anterior.data()?['citaId'] != id || !anteriorPublico.exists) {
        throw StateError('No coincide la reserva original.');
      }
      if (idAnterior == idNuevo) {
        tx.update(citaRef, cambios);
        return true;
      }
      // Importante: NO leer la reserva privada ajena del nuevo horario.
      final nuevoPublicoRef = _disponibilidadCollection.doc(idNuevo);
      final nuevoPublico = await tx.get(nuevoPublicoRef);
      if (nuevoPublico.exists) return false;
      final nuevoRef = _horariosCollection.doc(idNuevo);
      tx.update(citaRef, {...cambios, 'horarioId': idNuevo});
      tx.delete(anteriorRef);
      tx.delete(anteriorPublicoRef);
      tx.set(nuevoRef, _datosHorario(id, actualizada));
      tx.set(nuevoPublicoRef, {'ocupado': true});
      return true;
    });
    if (!resultado) throw const HorarioOcupadoException();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllCitas() =>
      _citasCollection.orderBy('fecha', descending: true).snapshots();

  Future<void> addDepartamento(String nombre) async {
    await _departamentosCollection.doc(nombre).set({'tramites': <String>[]});
  }

  Future<void> deleteDepartamento(String id) async {
    await _departamentosCollection.doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getDepartamentos() =>
      _departamentosCollection.snapshots();

  Future<void> addTramite(String departamentoId, String tramite) async {
    await _departamentosCollection.doc(departamentoId).update({
      'tramites': FieldValue.arrayUnion([tramite]),
    });
  }

  Future<void> deleteTramite(String departamentoId, String tramite) async {
    await _departamentosCollection.doc(departamentoId).update({
      'tramites': FieldValue.arrayRemove([tramite]),
    });
  }
}
