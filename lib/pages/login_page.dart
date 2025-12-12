import 'package:citatec/components/MyButtton.dart';
import 'package:citatec/services/auth_service.dart';
import 'package:citatec/components/MyTextField.dart';
import 'package:citatec/pages/Admin_page.dart';
import 'package:citatec/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //controladores para los TextField
  final TextEditingController NoController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Variables para el dropdown de dominios
  String _selectedDomain = '@gmail.com';
  final List<String> _domains = [
    '@gmail.com',
    '@iguala.edu.mx',
    '@iguala.tecnm.mx'
  ];

  void login(BuildContext context) async {
    //lógica de login aquí
    String no = NoController.text.trim(); // Solo el usuario/número
    String password = passwordController.text.trim();

    // Verificar que los campos no estén vacíos
    if (no.isEmpty || password.isEmpty) {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Concatenar usuario con dominio
    String fullEmail = no + _selectedDomain;

    // Login with Firebase
    final authService = AuthService();
    try {
      // Sign in
      UserCredential? userCredential = await authService
          .signInWithEmailAndPassword(fullEmail, password);

      // Check Role
      if (userCredential != null && userCredential.user != null) {
        String role = await authService.getUserRole(userCredential.user!.uid);

        if (!context.mounted) return;

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //logo
                Icon(
                  Icons.person,
                  size: 80,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                const SizedBox(height: 20),
                //nombre de la app
                const Text(' C I T A T E C ', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 50),
                
                // Row para usuario y dominio
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: MyTextField(
                        hintText: "Usuario / No. Control",
                        obscureText: false,
                        controller: NoController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDomain,
                          icon: const Icon(Icons.arrow_drop_down),
                          elevation: 16,
                          style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDomain = newValue!;
                            });
                          },
                          items: _domains.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
            
                //contraseña textfield
                const SizedBox(height: 10),
                MyTextField(
                  hintText: "Contraseña",
                  obscureText: true,
                  controller: passwordController,
                ),
                const SizedBox(height: 10),
            
                //olvide la contraseña
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                //botón de login
                MyButton(text: "Entrar", onTap: () => login(context)),
                //No tienes cuenta? Regístrate
              ],
            ),
          ),
        ),
      ),
    );
  }
}
