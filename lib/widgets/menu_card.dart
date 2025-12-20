import 'package:flutter/material.dart';

class MenuCard extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final corEscura = darken(cor, 0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Ícone com curva "para dentro" no canto superior direito
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(64, 64),
                painter: CurvaSuperiorPainter(corEscura),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(
                    child: Icon(
                      icone,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            // Texto centralizado abaixo
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 12, left: 8, right: 8),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
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
      radius: Radius.circular(size.width * 0.73),
      clockwise: true,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
