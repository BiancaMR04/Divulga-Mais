import 'package:flutter/material.dart';

import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/widgets/guards/leader_gate.dart';
import 'package:divulgapampa/views/leader/leader_posts_screen.dart';
import 'package:divulgapampa/views/leader/leader_scopes_screen.dart';

class LeaderHomeScreen extends StatelessWidget {
  const LeaderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LeaderGate(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Gerenciar (Líder)'),
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
            _Tile(
              title: 'Publicações',
              subtitle: 'Criar/editar/excluir suas publicações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderPostsScreen()),
              ),
            ),
            _Tile(
              title: 'Meu PPG / Grupo',
              subtitle: 'Editar informações e linhas de pesquisa',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderScopesScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
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
