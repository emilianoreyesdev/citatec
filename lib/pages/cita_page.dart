import 'package:flutter/material.dart';
import 'package:citatec/services/firestore_service.dart';
import 'package:citatec/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CitaPage extends StatefulWidget {
  const CitaPage({super.key});

  @override
  State<CitaPage> createState() => _CitaPageState();
}

class _CitaPageState extends State<CitaPage> {
  int currentStep = 0;
  bool _isSubmitting = false;

  // Mantener los streams estables entre reconstrucciones del widget.
  // Si se crean dentro de build(), cada clic puede reiniciar su estado
  // a waiting y deshabilitar temporalmente todas las horas.
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<QuerySnapshot> _departamentosStream;
  final Map<String, Stream<bool>> _horariosStreams = {};

  @override
  void initState() {
    super.initState();
    _departamentosStream = _firestoreService.getDepartamentos();
  }

  Stream<bool> _streamHorario(String hora) {
    final departamento = selectedDepartment!;
    final fecha = selectedDate!;
    return _horariosStreams.putIfAbsent(
      hora,
      () => _firestoreService.observarHorarioOcupado(
        departamento,
        fecha,
        hora,
      ),
    );
  }

  // Variables para almacenar la selección
  String? selectedDepartment;
  String? selectedService;
  DateTime? selectedDate;
  String? selectedTime;

  // Horarios disponibles
  final List<String> availableTimes = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Agendar Cita'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _departamentosStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          Map<String, List<String>> departmentServices = {};
          
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final tramites = List<String>.from(data['tramites'] ?? []);
            departmentServices[doc.id] = tramites;
          }

          return Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Colors.blue)),
            child: Stepper(
              type: StepperType.vertical,
              currentStep: currentStep,
              onStepContinue: () {
                if (currentStep < 3) {
                  if (validateCurrentStep()) {
                    setState(() {
                      currentStep++;
                    });
                  }
                } else {
                  if (!_isSubmitting && validateCurrentStep()) {
                    confirmarCita();
                  }
                }
              },
              onStepCancel: () {
                if (currentStep > 0) {
                  setState(() {
                    currentStep--;
                  });
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      if (currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Anterior'),
                          ),
                        ),
                      if (currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(currentStep == 3 ? 'Confirmar' : 'Siguiente'),
                        ),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Seleccionar Departamento
                Step(
                  title: const Text('Departamento'),
                  isActive: currentStep >= 0,
                  state: currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona el departamento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (departmentServices.isEmpty)
                         const Text("No hay departamentos disponibles"),
                      ...departmentServices.keys.map((department) {
                         // Default icon logic
                        IconData icon = Icons.business;
                        Color color = Colors.grey;

                        if (department.contains('Escolares')) {
                          icon = Icons.school;
                          color = Colors.purple;
                        } else if (department.contains('Financieros')) {
                          icon = Icons.attach_money;
                          color = Colors.teal;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildSelectionCard(
                            icon: icon,
                            title: department,
                            isSelected: selectedDepartment == department,
                            color: color,
                            onTap: () {
                              setState(() {
                                selectedDepartment = department;
                                selectedTime = null;
                                _horariosStreams.clear();
                                selectedService = null; // Reset service
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Step 2: Seleccionar Servicio
                Step(
                  title: const Text('Servicio'),
                  isActive: currentStep >= 1,
                  state: currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona el servicio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (selectedDepartment != null && departmentServices.containsKey(selectedDepartment))
                        ...departmentServices[selectedDepartment]!.map((service) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildServiceCard(
                              title: service,
                              isSelected: selectedService == service,
                              onTap: () {
                                setState(() {
                                  selectedService = service;
                                });
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                // Step 3: Seleccionar Fecha
                Step(
                  title: const Text('Fecha'),
                  isActive: currentStep >= 2,
                  state: currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona la fecha',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedDate != null
                                  ? Colors.blue
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.blue,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  selectedDate != null
                                      ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                      : 'Toca para seleccionar fecha',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: selectedDate != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.inversePrimary
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Step 4: Seleccionar Hora
                Step(
                  title: const Text('Hora'),
                  isActive: currentStep >= 3,
                  state: currentStep > 3 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona la hora',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (selectedDepartment != null && selectedDate != null)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: availableTimes.map((time) {
                            return StreamBuilder<bool>(
                              key: ValueKey('${selectedDepartment}_${selectedDate!.year}_${selectedDate!.month}_${selectedDate!.day}_$time'),
                              stream: _streamHorario(time),
                              builder: (context, horarioSnapshot) {
                                final cargando = horarioSnapshot.connectionState == ConnectionState.waiting;
                                final error = horarioSnapshot.hasError;
                                final ocupado = horarioSnapshot.data ?? false;
                                final bloqueado = cargando || error || ocupado;
                                if (bloqueado && selectedTime == time) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted && selectedTime == time) {
                                      setState(() => selectedTime = null);
                                    }
                                  });
                                }
                                return _buildTimeChip(
                                  time: time,
                                  isSelected: selectedTime == time && !bloqueado,
                                  isDisabled: bloqueado,
                                  subtitle: error ? 'Sin conexión' : cargando ? 'Consultando' : ocupado ? 'Ocupado' : null,
                                  onTap: () => setState(() => selectedTime = time),
                                );
                              },
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget para tarjetas de selección (Departamento)
  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  // Widget para tarjetas de servicio
  Widget _buildServiceCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ?  Colors.blue.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 24),
          ],
        ),
      ),
    );
  }

  // Widget para chips de hora
  Widget _buildTimeChip({
    required String time,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
    String? subtitle,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withValues(alpha: 0.16)
              : isSelected ? Colors.blue : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: TextStyle(
              color: isDisabled ? Colors.grey : isSelected ? Colors.white : Theme.of(context).colorScheme.inversePrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
            if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Seleccionar fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
        _horariosStreams.clear();
      });
    }
  }

  // Validar paso actual
  bool validateCurrentStep() {
    switch (currentStep) {
      case 0:
        if (selectedDepartment == null) {
          _showSnackBar('Por favor, selecciona un departamento');
          return false;
        }
        return true;
      case 1:
        if (selectedService == null) {
          _showSnackBar('Por favor, selecciona un servicio');
          return false;
        }
        return true;
      case 2:
        if (selectedDate == null) {
          _showSnackBar('Por favor, selecciona una fecha');
          return false;
        }
        return true;
      case 3:
        if (selectedTime == null) {
          _showSnackBar('Por favor, selecciona una hora');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // Mostrar mensaje
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Confirmar una cita sin permitir envíos duplicados.
  Future<void> confirmarCita() async {
    if (_isSubmitting) return;

    final user = AuthService().currentUser;
    final departamento = selectedDepartment;
    final servicio = selectedService;
    final fecha = selectedDate;
    final hora = selectedTime;

    if (user == null || user.email == null) {
      _showSnackBar('Debes iniciar sesión con un correo válido.');
      return;
    }
    if (departamento == null || servicio == null || fecha == null || hora == null) {
      _showSnackBar('Completa todos los datos de la cita.');
      return;
    }

    setState(() => _isSubmitting = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? mensajeError;
    try {
      await FirestoreService().createCita({
        'userId': user.uid,
        'userName': user.email!,
        'departamento': departamento,
        'servicio': servicio,
        'fecha': Timestamp.fromDate(DateTime.utc(fecha.year, fecha.month, fecha.day)),
        'hora': hora,
        'estado': 'Activa',
        'created_at': FieldValue.serverTimestamp(),
      });
    } on HorarioOcupadoException {
      mensajeError = 'Horario no disponible. Selecciona otra hora o fecha.';
    } on FirebaseException catch (e) {
      // Se mantiene el detalle tecnico en la terminal, no en la interfaz.
      debugPrint('Error de Firebase al agendar: ${e.code} - ${e.message}');
      mensajeError = e.code == 'permission-denied'
          ? 'No se pudo autorizar la reserva. Revisa tu sesion o contacta soporte.'
          : 'No se pudo agendar la cita. Intentalo de nuevo.';
    } catch (e, stackTrace) {
      debugPrint('Error inesperado al agendar: $e\n$stackTrace');
      mensajeError = 'No se pudo completar la reserva. Intentalo de nuevo.';
    }

    if (!mounted) return;

    // Cierra únicamente el diálogo de carga.
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isSubmitting = false);

    if (mensajeError != null) {
      _showSnackBar(mensajeError);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Cita Confirmada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu cita ha sido agendada exitosamente:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildDetailRow(Icons.business, 'Departamento', departamento),
            _buildDetailRow(Icons.description, 'Servicio', servicio),
            _buildDetailRow(Icons.calendar_today, 'Fecha',
                '${fecha.day}/${fecha.month}/${fecha.year}'),
            _buildDetailRow(Icons.access_time, 'Hora', hora),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Regresa a la pantalla anterior.
  }

  // Widget para detalles en el diálogo
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
