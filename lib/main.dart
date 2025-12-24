import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/views/cadastroScreen.dart';
import 'package:divulgapampa/views/loginScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // conecta com o Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/home',
  routes: {
    '/home': (_) => const HomeScreen(),
    '/login': (_) => const LoginScreen(),
    '/cadastro': (_) => const RegisterScreen(),
  },
      title: 'Menu Dinâmico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const HomeScreen(), // aqui é onde sua tela inicial aparece
    );
  }
}

