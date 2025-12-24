import 'package:flutter/material.dart';
import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/widgets/guards/superuser_gate.dart';
import 'package:divulgapampa/views/admin/admin_menus_screen.dart';
import 'package:divulgapampa/views/admin/admin_posts_screen.dart';
import 'package:divulgapampa/views/admin/admin_users_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const double topOffset = 160;

    return SuperuserGate(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F6E58),
        bottomNavigationBar: CustomNavBar(selected: NavDestination.manage), // aba gerenciar
        body: SafeArea(
          child: Stack(
            children: [
              // Fundo verde (ou imagem se quiser)
              Positioned.fill(
                child: Container(color: const Color(0xFF0F6E58)),
              ),

              // Conteúdo branco
              Positioned.fill(
                top: topOffset,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F7F7),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Minhas informações:",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F6E58),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _AdminCard(
                        title: "Publicações",
                        subtitle: "Aprovar, editar ou remover artigos",
                        color: const Color(0xFF5AC89C),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminPostsScreen()),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _AdminCard(
                        title: "Menus",
                        subtitle: "Gerenciar menus e páginas do aplicativo",
                        color: const Color(0xFF9AA6FF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminMenusScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _AdminCard(
                        title: "Usuários",
                        subtitle: "Editar, excluir e definir permissões",
                        color: const Color(0xFFFF8A4D),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              // Topo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Divulga Pampa",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final corEscura = _darken(color, 0.18);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // 🔥 curva superior DIREITA menor
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(56, 56),
                painter: CurvaSuperiorPainter(corEscura),
              ),
            ),

            // Texto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
class CurvaSuperiorPainter extends CustomPainter {
  final Color color;

  CurvaSuperiorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.arcToPoint(
      Offset(0, 0),
      radius: Radius.circular(size.width * 0.6),
      clockwise: true,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
