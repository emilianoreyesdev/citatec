import 'package:citatec/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text("Panel de Administrador"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.secondary,
            indicatorWeight: 3,
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt), text: "Citas"),
              Tab(icon: Icon(Icons.business), text: "Trámites"),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ],
        ),
        body: TabBarView(children: [_buildCitasTab(), _buildTramitesTab()]),
      ),
    );
  }

  Widget _buildCitasTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getAllCitas(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Error al cargar citas: ${snapshot.error}"),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final citas = snapshot.data!.docs;

        if (citas.isEmpty) {
          return _buildEmptyState("No hay citas registradas", Icons.event_busy);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: citas.length,
          itemBuilder: (context, index) {
            final doc = citas[index];
            final cita = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            // Safe data extraction
            final user = cita['userName'] ?? 'Usuario desconocido';
            DateTime? fecha;
            if (cita['fecha'] != null) {
              fecha = (cita['fecha'] as Timestamp).toDate();
            }
            final fechaStr = fecha != null
                ? "${fecha.day}/${fecha.month}/${fecha.year}"
                : "Sin fecha";
            final hora = cita['hora'] ?? '--:--';
            final departamento = cita['departamento'] ?? 'General';
            final servicio = cita['servicio'] ?? 'Trámite general';
            final estado = cita['estado'] ?? 'Pendiente';

            // Colores por estado (puedes ajustar a tu gusto)
            Color statusColor = Colors.blue;
            if (estado == 'Completada') statusColor = Colors.green;
            if (estado == 'Cancelada') statusColor = Colors.red;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.inversePrimary,
                                    ),
                                  ),
                                  Text(
                                    departamento,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              estado,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Details row
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(fechaStr),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(hora),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              servicio,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTramitesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent, // Use parent background
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDepartamentoDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getDepartamentos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deptos = snapshot.data!.docs;

          if (deptos.isEmpty) {
            return _buildEmptyState("No hay departamentos", Icons.business);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deptos.length,
            itemBuilder: (context, index) {
              final doc = deptos[index];
              final deptName = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final tramites = List<String>.from(data['tramites'] ?? []);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  title: Text(
                    deptName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteDepartamento(deptName),
                  ),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide.none,
                  ), // Remove borders
                  children: [
                    // List of tramites
                    ...tramites.map(
                      (tramite) => ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 16,
                        ), // Align with title
                        title: Text(tramite),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              firestoreService.deleteTramite(deptName, tramite),
                        ),
                      ),
                    ),
                    // Add tramite button
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      title: const Text(
                        "Agregar trámite",
                        style: TextStyle(color: Colors.blue),
                      ),
                      onTap: () => _showAddTramiteDialog(deptName),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ],
      ),
    );
  }

  // --- Dialogs (Styled) ---

  void _showAddDepartamentoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Departamento"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Nombre...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                firestoreService.addDepartamento(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _showAddTramiteDialog(String deptoId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Nuevo Trámite para $deptoId"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Nombre del trámite...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                firestoreService.addTramite(deptoId, controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDepartamento(String deptId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Departamento"),
        content: Text(
          "¿Seguro que quieres eliminar $deptId y todos sus trámites?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              firestoreService.deleteDepartamento(deptId);
              Navigator.pop(context);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
