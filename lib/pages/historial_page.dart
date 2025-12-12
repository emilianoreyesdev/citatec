import 'package:flutter/material.dart';
import 'package:citatec/services/firestore_service.dart';
import 'package:citatec/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  // Filtro seleccionado
  String filtroSeleccionado = 'Todas';

  // Lista de historial de citas (simulada)
  final List<Map<String, dynamic>> historialCitas = [
    {
      'id': 1,
      'departamento': 'Servicios Escolares',
      'servicio': 'Ajuste de horario',
      'fecha': DateTime(2025, 10, 15),
      'hora': '10:00 AM',
      'estado': 'Completada',
      'icon': Icons.school,
      'color': Colors.purple,
      'notas': 'Cita atendida satisfactoriamente',
    },
    {
      'id': 2,
      'departamento': 'Servicios Financieros',
      'servicio': 'Canje de ticket de reinscripción',
      'fecha': DateTime(2025, 10, 20),
      'hora': '02:00 PM',
      'estado': 'Cancelada',
      'icon': Icons.attach_money,
      'color': Colors.teal,
      'notas': 'Cancelada por el usuario',
    },
    {
      'id': 3,
      'departamento': 'Servicios Escolares',
      'servicio': 'Cambio de materias',
      'fecha': DateTime(2025, 10, 22),
      'hora': '11:00 AM',
      'estado': 'Reagendada',
      'icon': Icons.school,
      'color': Colors.purple,
      'notas': 'Reagendada para el 28 de octubre',
    },
    {
      'id': 4,
      'departamento': 'Servicios Financieros',
      'servicio': 'Consulta de adeudos',
      'fecha': DateTime(2025, 10, 18),
      'hora': '09:00 AM',
      'estado': 'Completada',
      'icon': Icons.attach_money,
      'color': Colors.teal,
      'notas': 'Trámite finalizado',
    },
    {
      'id': 5,
      'departamento': 'Servicios Escolares',
      'servicio': 'Ajuste de horario',
      'fecha': DateTime(2025, 10, 28),
      'hora': '10:00 AM',
      'estado': 'Activa',
      'icon': Icons.school,
      'color': Colors.purple,
      'notas': 'Próxima cita agendada',
    },
    {
      'id': 6,
      'departamento': 'Servicios Financieros',
      'servicio': 'Canje de ticket cursos de inglés',
      'fecha': DateTime(2025, 11, 5),
      'hora': '02:00 PM',
      'estado': 'Activa',
      'icon': Icons.attach_money,
      'color': Colors.teal,
      'notas': 'Cita pendiente',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Por favor inicia sesión')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Historial de Citas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todas', Icons.all_inclusive),
                  const SizedBox(width: 8),
                  _buildFilterChip('Activa', Icons.event_available),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completada', Icons.check_circle),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cancelada', Icons.cancel),
                  const SizedBox(width: 8),
                  _buildFilterChip('Reagendada', Icons.update),
                ],
              ),
            ),
          ),
          // Lista de citas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService().getCitasForUser(user.uid),
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

                // Convert docs to list of maps
                final citas = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  if (data['fecha'] is Timestamp) {
                    data['fecha'] = (data['fecha'] as Timestamp).toDate();
                  }
                  // Mock UI data
                  if (data['departamento'] == 'Servicios Escolares') {
                    data['icon'] = Icons.school;
                    data['color'] = Colors.purple;
                  } else {
                    data['icon'] = Icons.attach_money;
                    data['color'] = Colors.teal;
                  }
                  return data;
                }).toList();

                // Filter locally
                final citasFiltradas = filtroSeleccionado == 'Todas'
                    ? citas
                    : citas
                        .where((cita) => cita['estado'] == filtroSeleccionado)
                        .toList();

                if (citasFiltradas.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: citasFiltradas.length,
                  itemBuilder: (context, index) {
                    return _buildHistorialCard(citasFiltradas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget para chip de filtro
  Widget _buildFilterChip(String estado, IconData icon) {
    bool isSelected = filtroSeleccionado == estado;
    Color chipColor = _getEstadoColor(estado);

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : chipColor),
          const SizedBox(width: 6),
          Text(estado),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          filtroSeleccionado = estado;
        });
      },
      backgroundColor: Theme.of(context).colorScheme.primary,
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.inversePrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? chipColor : Colors.grey.shade400),
    );
  }

  // Widget para estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No hay citas en esta categoría',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Intenta con otro filtro',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // Widget para tarjeta de historial
  Widget _buildHistorialCard(Map<String, dynamic> cita) {
    Color estadoColor = _getEstadoColor(cita['estado']);
    IconData estadoIcon = _getEstadoIcon(cita['estado']);
    bool esPasada =
        cita['fecha'].isBefore(DateTime.now()) && cita['estado'] != 'Activa';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: estadoColor.withOpacity(0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              estadoColor.withOpacity(0.05),
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cita['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cita['icon'], color: cita['color'], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cita['departamento'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cita['servicio'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: estadoColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 16, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          cita['estado'],
                          style: TextStyle(
                            color: estadoColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              // Detalles
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today,
                      '${cita['fecha'].day}/${cita['fecha'].month}/${cita['fecha'].year}',
                      esPasada ? Colors.grey : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.access_time,
                      cita['hora'],
                      esPasada ? Colors.grey : Colors.orange,
                    ),
                  ),
                ],
              ),
              // Notas
              if (cita['notas'] != null && cita['notas'].isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cita['notas'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Botón de detalles
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _mostrarDetalles(cita),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ver más detalles',
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: estadoColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para chip de información
  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Obtener color según estado
  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Completada':
        return Colors.green;
      case 'Cancelada':
        return Colors.red;
      case 'Reagendada':
        return Colors.orange;
      case 'Activa':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Obtener icono según estado
  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'Completada':
        return Icons.check_circle;
      case 'Cancelada':
        return Icons.cancel;
      case 'Reagendada':
        return Icons.update;
      case 'Activa':
        return Icons.event_available;
      default:
        return Icons.help_outline;
    }
  }

  // Mostrar detalles de la cita
  void _mostrarDetalles(Map<String, dynamic> cita) {
    Color estadoColor = _getEstadoColor(cita['estado']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cita['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cita['icon'], color: cita['color'], size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalles de la Cita',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        Text(
                          'ID: #${cita['id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              // Información detallada
              _buildDetailRow(
                'Departamento',
                cita['departamento'],
                Icons.business,
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Servicio', cita['servicio'], Icons.description),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Fecha',
                '${cita['fecha'].day}/${cita['fecha'].month}/${cita['fecha'].year}',
                Icons.calendar_today,
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Hora', cita['hora'], Icons.access_time),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Estado',
                cita['estado'],
                _getEstadoIcon(cita['estado']),
              ),
              if (cita['notas'] != null && cita['notas'].isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Notas', cita['notas'], Icons.note),
              ],
              const SizedBox(height: 24),
              // Botón cerrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: estadoColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Widget para fila de detalles
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.inversePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
