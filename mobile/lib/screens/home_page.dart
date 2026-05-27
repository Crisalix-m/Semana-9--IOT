import 'package:flutter/material.dart';
import 'package:mobile/models/estacion.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'add_estacion.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Estacion>> _futureEstaciones;
  final ApiService apiService = ApiService(); // Instancia reutilizable para editar/eliminar

  @override
  void initState() {
    super.initState();
    _refreshEstaciones();
  }

  void _refreshEstaciones() {
    setState(() {
      _futureEstaciones = ApiService().fetchEstaciones();
    });
  }

  void _logout() async {
    await AuthService().logout();
    
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ==========================================
  // PASO 3: FUNCIÓN DEL DIÁLOGO DE EDICIÓN
  // ==========================================
  void _mostrarDialogoEdicion(Estacion estacion) {
    // Los controladores inician con los valores actuales de la estación
    final nombreCtrl = TextEditingController(text: estacion.nombre);
    final ubicacionCtrl = TextEditingController(text: estacion.ubicacion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Estación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl, 
              decoration: const InputDecoration(labelText: "Nombre")
            ),
            TextField(
              controller: ubicacionCtrl, 
              decoration: const InputDecoration(labelText: "Ubicación")
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              // Llamamos al método editarEstacion de tu ApiService
              bool ok = await apiService.editarEstacion(
                estacion.id, 
                nombreCtrl.text, 
                ubicacionCtrl.text
              );
              
              if (ok) {
                if (!context.mounted) return;
                Navigator.pop(context); // Cierra el diálogo
                _refreshEstaciones();  // Refresca la lista automáticamente
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Estación actualizada correctamente")),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones SMAT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Estacion>>(
        future: _futureEstaciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay estaciones registradas.'));
          }

          final estaciones = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshEstaciones(), // Pull-to-refresh
            child: ListView.builder(
              itemCount: estaciones.length,
              itemBuilder: (context, index) {
                final estacion = estaciones[index];
                
                // ==========================================
                // PASO 2: SWIPE-TO-DISMISS (DESLIZAR PARA BORRAR)
                // ==========================================
                return Dismissible(
                  key: Key(estacion.id.toString()),
                  direction: DismissDirection.endToStart, // Desliza de derecha a izquierda
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    // Guarda el nombre antes de borrarlo de la lista para el SnackBar
                    final nombreEstacion = estacion.nombre;
                    
                    // Ejecuta la eliminación en el Backend mediante tu ApiService
                    bool ok = await apiService.eliminarEstacion(estacion.id);
                    
                    if (ok) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("$nombreEstacion eliminada")),
                      );
                    } else {
                      // Si falla por seguridad en el backend, recargamos para restaurarla visualmente
                      _refreshEstaciones();
                    }
                  },
                  // ==========================================
                  // RETO DE LA FASE MOBILE: LÓGICA DE COLORES EN EL LEADING
                  // ==========================================
                  child: ListTile(
                    leading: CircleAvatar(
                      // Supongamos que tu modelo tiene 'lectura' o 'ultimaLectura'. 
                      // Si arroja error por el nombre del campo, cámbialo por como se llame en tu modelo.
                      backgroundColor: (estacion.ultimaLectura ?? 0) > 50 
                          ? Colors.red       // Rojo si supera el umbral crítico (> 50)
                          : Colors.green,    // Verde si el valor es normal (< 50)
                      child: Icon(
                        (estacion.ultimaLectura ?? 0) > 50 
                            ? Icons.warning_amber_rounded 
                            : Icons.check,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(estacion.nombre),
                    subtitle: Text(estacion.ubicacion),
                    // AL TOCAR: Se abre el cuadro de edición creado arriba
                    onTap: () => _mostrarDialogoEdicion(estacion),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEstacionScreen()),
          );
          if (resultado == true) {
            _refreshEstaciones();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}