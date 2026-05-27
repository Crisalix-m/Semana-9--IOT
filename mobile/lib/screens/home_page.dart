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
                
                // Usamos un FutureBuilder secundario para obtener las lecturas en tiempo real de esta estación
                return FutureBuilder<List<dynamic>>(
                   future: apiService.fetchLecturas(), // <--- Llama a la función que acabamos de agregar arriba
                   builder: (context, lecturaSnapshot) {
                    String valorTexto = "0.0 cm";
                     bool esCritico = false;

                     if (lecturaSnapshot.hasData && lecturaSnapshot.data!.isNotEmpty) {
                          // FILTRADO INTELIGENTE: Buscamos las lecturas que correspondan a ESTA estación
                       final lecturasDeEstaEstacion = lecturaSnapshot.data!
                          .where((l) => l['estacion_id'] == estacion.id)
                          .toList();

                        if (lecturasDeEstaEstacion.isNotEmpty) {
                          // Tomamos el último valor (la telemetría más reciente del script de Python)
                          final ultimaLectura = lecturasDeEstaEstacion.last;
                          final double valor = double.tryParse(ultimaLectura['valor'].toString()) ?? 0.0;
        
                            valorTexto = "${valor.toStringAsFixed(1)} cm";
        
                            // VALIDACIÓN DEL RETO: ¿El nivel del río supera los 70.0 cm?
                             if (valor > 70.0) {
                              esCritico = true;
                            }
                          }
                       }
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
                        final nombreEstacion = estacion.nombre;
                        bool ok = await apiService.eliminarEstacion(estacion.id);
                        
                        if (ok) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$nombreEstacion eliminada")),
                          );
                        } else {
                          _refreshEstaciones();
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        // RETO SEMANA 9: Si hay peligro, la tarjeta se vuelve de un tono rojo suave
                        color: esCritico ? Colors.red.shade50 : Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            // RETO SEMANA 9: El círculo cambia a rojo e icono de advertencia ante emergencias
                            backgroundColor: esCritico ? Colors.red.shade100 : Colors.green.shade100,
                            child: Icon(
                              Icons.wifi_tethering, // Icono de señal inalámbrica ((.))
                              color: esCritico ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            estacion.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: esCritico ? Colors.red.shade900 : Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                "Valor actual: $valorTexto",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: esCritico ? Colors.red.shade700 : Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                estacion.ubicacion,
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.black45), // Icono del lápiz
                            onPressed: () => _mostrarDialogoEdicion(estacion), // Abre el modal de edición
                          ),
                        ),
                      ),
                    );
                  },
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