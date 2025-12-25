import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/user_profile_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';

class LeaderGate extends StatelessWidget {
  final Widget child;
  final UserProfileService? service;

  const LeaderGate({
    super.key,
    required this.child,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: (service ?? UserProfileService()).watchCurrentUserProfile(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            body: const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
          );
        }

        final profile = snap.data;
        final isLeader = (service ?? UserProfileService()).isLeader(profile);
        if (!isLeader) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7F7),
            appBar: AppBar(
              title: const Text('Acesso restrito'),
              backgroundColor: const Color(0xFF0F6E58),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Esta área é exclusiva para líderes.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final scopeId = (profile?.liderScopeId ?? '').trim();
        final scopeType = (profile?.liderScopeType ?? '').trim().toLowerCase();
        final hasScope = scopeId.isNotEmpty && (scopeType == 'ppg' || scopeType == 'grupo');
        if (!hasScope) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7F7),
            appBar: AppBar(
              title: const Text('Configuração pendente'),
              backgroundColor: const Color(0xFF0F6E58),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Seu perfil de líder ainda não tem um PPG/Grupo associado.\n\nPeça para um superuser configurar o seu escopo em “Gestão de usuários”.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
