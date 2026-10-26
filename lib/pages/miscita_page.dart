import 'package:flutter/material.dart';
import 'package:citatec/pages/cita_page.dart';
import 'package:citatec/services/auth_service.dart';
import 'package:citatec/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MiCitaPage extends StatefulWidget {
  const MiCitaPage({super.key});

  @override
  State<MiCitaPage> createState() => _MiCitaPageState();
}

class _MiCitaPageState extends State<MiCitaPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _operationInProgress = false;

  DateTime _fechaUtc(DateTime fecha) => DateTime.utc(fecha.year, fecha.month, fecha.day);

  DateTime _fechaCalendario(dynamic fecha) {
    final value = fecha is Timestamp ? fecha.toDate().toUtc() : (fecha as DateTime).toUtc();
    return DateTime(value.year, value.month, value.day);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus citas')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mis Citas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getCitasForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Filter only 'Activa' appointments for this view
          final citas = snapshot.data!.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['estado'] == 'Activa';
              })
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                if (data['fecha'] is Timestamp) {
                  data['fecha'] = _fechaCalendario(data['fecha']);
                }
                // Determine icon and color based on department text (simple logic)
                if (data['departamento'].toString().contains('Escolares')) {
                  data['icon'] = Icons.school;
                  data['color'] = Colors.purple;
                } else {
                  data['icon'] = Icons.attach_money;
                  data['color'] = Colors.teal;
                }
                return data;
              })
              .toList();

          if (citas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: citas.length,
            itemBuilder: (context, index) {
              return _buildCitaCard(citas[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CitaPage()),
          );
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cita'),
      ),
    );
  }

  // Widget para estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No tienes citas agendadas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Agenda tu primera cita',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CitaPage()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Agendar Cita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para tarjeta de cita
  Widget _buildCitaCard(Map<String, dynamic> cita) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              (cita['color'] as Color).withValues(alpha: 0.1),
              Theme.of(context).colorScheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con departamento y estado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (cita['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cita['icon'], color: cita['color'], size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cita['departamento'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            cita['estado'],
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // Detalles de la cita
              _buildDetailRow(Icons.description, 'Servicio', cita['servicio']),
              const SizedBox(height: 10),
              _buildDetailRow(
                Icons.calendar_today,
                'Fecha',
                '${cita['fecha'].day}/${cita['fecha'].month}/${cita['fecha'].year}',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(Icons.access_time, 'Hora', cita['hora']),
              const SizedBox(height: 16),
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _modificarCita(cita),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modificar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelarCita(cita),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para fila de detalles
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
      ],
    );
  }

  // Modificar cita
  void _modificarCita(Map<String, dynamic> cita) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Modificar Cita',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.blue),
                title: const Text('Cambiar fecha y hora'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _cambiarFechaHora(cita);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                title: const Text('Cambiar servicio'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _cambiarServicio(cita);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Cambiar fecha/hora respetando el formato de medianoche UTC del servicio.
  void _cambiarFechaHora(Map<String, dynamic> cita) {
    DateTime nuevaFecha = _fechaCalendario(cita['fecha']);
    String nuevaHora = cita['hora'] as String;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: const Text('Cambiar Fecha y Hora'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('Fecha'),
                subtitle: Text('${nuevaFecha.day}/${nuevaFecha.month}/${nuevaFecha.year}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final hoy = DateTime.now();
                  final inicio = DateTime(hoy.year, hoy.month, hoy.day);
                  final fin = inicio.add(const Duration(days: 60));
                  final inicial = nuevaFecha.isBefore(inicio)
                      ? inicio
                      : (nuevaFecha.isAfter(fin) ? fin : nuevaFecha);
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: inicial,
                    firstDate: inicio,
                    lastDate: fin,
                  );
                  if (!dialogContext.mounted) return;
                  if (picked != null) {
                    setStateDialog(() => nuevaFecha = picked);
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: const Text('Hora'),
                subtitle: Text(nuevaHora),
                trailing: const Icon(Icons.edit),
                onTap: () => _mostrarSelectorHora(dialogContext, (hora) {
                  if (dialogContext.mounted) {
                    setStateDialog(() => nuevaHora = hora);
                  }
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_operationInProgress) return;
                _operationInProgress = true;
                try {
                  await _firestoreService.updateCita(cita['id'] as String, {
                    'fecha': Timestamp.fromDate(_fechaUtc(nuevaFecha)),
                    'hora': nuevaHora,
                  });
                  if (!mounted) return;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _mostrarMensajeExito('Fecha y hora actualizadas');
                } catch (e) {
                  if (mounted) _mostrarError('No se pudo cambiar la cita: $e');
                } finally {
                  _operationInProgress = false;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // Mostrar selector de hora
  void _mostrarSelectorHora(BuildContext context, Function(String) onSelected) {
    final horarios = [
      '08:00 AM',
      '09:00 AM',
      '10:00 AM',
      '11:00 AM',
      '12:00 PM',
      '01:00 PM',
      '02:00 PM',
      '03:00 PM',
      '04:00 PM',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona la hora'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: horarios.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(horarios[index]),
                  onTap: () {
                    onSelected(horarios[index]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Actualiza el servicio de la misma cita; no crea una cita adicional.
  Future<void> _cambiarServicio(Map<String, dynamic> cita) async {
    try {
      final snapshot = await _firestoreService.getDepartamentos().first;
      if (!mounted) return;
      final departamento = cita['departamento'] as String;
      final docs = snapshot.docs.where((doc) => doc.id == departamento);
      if (docs.isEmpty) {
        _mostrarError('El departamento ya no existe.');
        return;
      }
      final servicios = List<String>.from(docs.first.data()['tramites'] ?? []);
      if (servicios.isEmpty) {
        _mostrarError('No hay servicios disponibles para este departamento.');
        return;
      }
      final servicio = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Cambiar Servicio'),
          children: servicios.map((nombre) => SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, nombre),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(nombre),
            ),
          )).toList(),
        ),
      );
      if (!mounted || servicio == null || servicio == cita['servicio']) return;
      if (_operationInProgress) return;
      _operationInProgress = true;
      try {
        await _firestoreService.updateCita(cita['id'] as String, {'servicio': servicio});
        if (mounted) _mostrarMensajeExito('Servicio actualizado');
      } finally {
        _operationInProgress = false;
      }
    } catch (e) {
      if (mounted) _mostrarError('No se pudo cambiar el servicio: $e');
    }
  }

  // Cancela la cita y libera su horario mediante la transacción del servicio.
  void _cancelarCita(Map<String, dynamic> cita) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Cancelar Cita'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta cita? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_operationInProgress) return;
              _operationInProgress = true;
              try {
                await _firestoreService.updateCitaStatus(cita['id'] as String, 'Cancelada');
                if (!mounted) return;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _mostrarMensajeExito('Cita cancelada exitosamente');
              } catch (e) {
                if (mounted) _mostrarError('No se pudo cancelar la cita: $e');
              } finally {
                _operationInProgress = false;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  // Mostrar mensaje de éxito
  void _mostrarMensajeExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(mensaje),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
