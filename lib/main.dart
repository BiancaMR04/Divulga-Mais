import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/views/cadastroScreen.dart';
import 'package:divulgapampa/views/loginScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // conecta com o Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/home',
      routes: {
        '/': (_) => const HomeScreen(),
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/cadastro': (_) => const RegisterScreen(),
      },
      title: 'Menu Dinâmico',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final shortestSide = size.shortestSide;
        final isSmallPhone = shortestSide < 360 || size.height < 700;

        // Estima a escala de texto do sistema (aprox. linear).
        final systemScale = mq.textScaler.scale(14) / 14;
        // Em telas pequenas, evita que a escala do sistema deixe tudo grande demais.
        final effectiveTextScale =
            isSmallPhone ? systemScale.clamp(0.85, 1.0) : systemScale;

        final themedChild = Theme(
          data: isSmallPhone
              ? Theme.of(context).copyWith(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  inputDecorationTheme:
                      Theme.of(context).inputDecorationTheme.copyWith(
                            isDense: true,
                          ),
                )
              : Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );

        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(effectiveTextScale)),
          child: themedChild,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
    );
  }
}

