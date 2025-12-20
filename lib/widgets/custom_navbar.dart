import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/views/loginScreen.dart';
import 'package:divulgapampa/views/perfilscreen.dart';

class CustomNavBar extends StatelessWidget {
  final String tipoUsuario; // 'discente', 'docente', 'outros', 'lider', 'superuser' ou '' se não logado
  final int selectedIndex;

  const CustomNavBar({
    super.key,
    this.tipoUsuario = '', // vazio significa "não logado"
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = tipoUsuario == 'lider' || tipoUsuario == 'superuser';

    final List<_NavItem> items = [
      _NavItem(
        icon: PhosphorIcons.house(),
        label: 'Início',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
      ),

      if (isAdmin)
        _NavItem(
          icon: PhosphorIcons.squaresFour(),
          label: 'Gerenciar',
          onTap: () {},
        ),

      _NavItem(
        icon: PhosphorIcons.user(),
        label: user == null ? 'Login' : 'Perfil',
        onTap: () {
          if (user == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PerfilScreen()),
            );
          }
        },
      ),
    ];

    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: item.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected
                      ? const Color(0xFF0F6E58)
                      : Colors.grey.shade600,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0F6E58)
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
