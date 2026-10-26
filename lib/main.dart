
import 'package:citatec/theme/oscuro.dart';
import 'package:citatec/theme/claro.dart';
import 'package:citatec/pages/login_page.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:citatec/firebase_options.dart';

const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useFirebaseEmulators) {
    // Flutter Web y escritorio usan localhost.
    // El emulador de Android utiliza 10.0.2.2.
    final String host = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    debugPrint('Firebase: utilizando emuladores locales');
    debugPrint('Authentication: $host:9099');
    debugPrint('Firestore: $host:8080');
  } else {
    debugPrint('Firebase: utilizando servicios reales');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
      theme: claroTheme,
      darkTheme: oscuroTheme,
      themeMode: ThemeMode.system,
    );
  }
}
