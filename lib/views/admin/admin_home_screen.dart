import 'package:flutter/material.dart';

import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/widgets/guards/superuser_gate.dart';
import 'package:divulgapampa/views/admin/admin_menus_screen.dart';
import 'package:divulgapampa/views/admin/admin_posts_screen.dart';
import 'package:divulgapampa/views/admin/admin_users_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperuserGate(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Administração'),
          backgroundColor: const Color(0xFF0F6E58),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AdminTile(
              title: 'Menus',
              subtitle: 'Criar/editar/reordenar menus e submenus',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminMenusScreen()),
              ),
            ),
            _AdminTile(
              title: 'Publicações',
              subtitle: 'Aprovar/editar/remover artigos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPostsScreen()),
              ),
            ),
            _AdminTile(
              title: 'Usuários',
              subtitle: 'Alterar tipo e ativação',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
