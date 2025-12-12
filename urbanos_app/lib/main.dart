import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'map_screen.dart';

void main() {
  runApp(const UrbanosApp());
}

class UrbanosApp extends StatelessWidget {
  const UrbanosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Urbanos Pereira',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6600)), // Naranja Urbanos
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para leer lo que escribe el usuario
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _mensaje = ""; // Para mostrar errores o éxito

  // Función para enviar datos al Backend
  Future<void> _iniciarSesion() async {
    final String email = _emailController.text;
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _mensaje = "⚠️ Por favor escribe correo y contraseña";
      });
      return;
    }

    // Aquí nos conectamos con tu Servidor Node.js
    // NOTA: Usamos 'localhost' porque estás en Chrome. Si usas emulador Android sería '10.0.2.2'
    final url = Uri.parse('http://192.168.0.112:3000/register');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "full_name": "Usuario Nuevo", // Por ahora registramos al intentar entrar
          "role": "CLIENTE"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // EXTRAEMOS EL ID QUE NOS DIO EL SERVIDOR
        String nuevoId = data['user']['id'];

        Navigator.pushReplacement(
          context,
          // SE LO PASAMOS AL MAPA
          MaterialPageRoute(builder: (context) => MapScreen(userId: nuevoId)),
        );
      } else {
        setState(() {
          _mensaje = "❌ Error: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _mensaje = "Error de conexión: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO (Texto o Imagen)
              const Icon(Icons.directions_bus_filled, size: 80, color: Color(0xFFFF6600)),
              const SizedBox(height: 10),
              const Text(
                'URBANOS PEREIRA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 40),

              // 2. CAMPOS DE TEXTO
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true, // Ocultar contraseña
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),

              // 3. BOTÓN DE INGRESO
              SizedBox(
                width: double.infinity, // Ocupar todo el ancho
                height: 50,
                child: ElevatedButton(
                  onPressed: _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600), // Color Naranja
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('INGRESAR O REGISTRARME', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 20),
              
              // 4. MENSAJE DE RESPUESTA
              Text(
                _mensaje,
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}