import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:divulgapampa/homescreen.dart';
import 'package:divulgapampa/views/loginScreen.dart';
import 'package:divulgapampa/views/perfilscreen.dart';
import 'package:divulgapampa/views/admin/admin_home_screen.dart';
import 'package:divulgapampa/views/leader/leader_home_screen.dart';
import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/user_profile_service.dart';

enum NavDestination { home, manage, profile }

class CustomNavBar extends StatelessWidget {
  final String tipoUsuario; // opcional (se vazio, carrega via Firestore)
  final NavDestination selected;
  final UserProfileService? profileService;

  CustomNavBar({
    super.key,
    this.tipoUsuario = '', // vazio significa "não logado"
    this.selected = NavDestination.home,
    this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildBar(context, user: null, role: UserRole.unknown);
    }

    if (tipoUsuario.trim().isNotEmpty) {
      return _buildBar(
        context,
        user: user,
        role: UserProfile.parseRole(tipoUsuario),
      );
    }

    return StreamBuilder<UserProfile?>(
      stream: (profileService ?? UserProfileService())
          .watchCurrentUserProfile(),
      builder: (context, snap) {
        final role = snap.data?.role ?? UserRole.unknown;
        return _buildBar(context, user: user, role: role);
      },
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required User? user,
    required UserRole role,
  }) {
    final bool isSuperuser = role == UserRole.superuser;
    final bool isLeader = role == UserRole.lider;

    final List<_NavItem> items = [
      _NavItem(
        icon: PhosphorIcons.house(),
        label: 'Início',
        destination: NavDestination.home,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
      ),
      if (isSuperuser)
        _NavItem(
          icon: PhosphorIcons.squaresFour(),
          label: 'Gerenciar',
          destination: NavDestination.manage,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
            );
          },
        ),
      if (!isSuperuser && isLeader)
        _NavItem(
          icon: PhosphorIcons.squaresFour(),
          label: 'Gerenciar',
          destination: NavDestination.manage,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderHomeScreen()),
            );
          },
        ),
      _NavItem(
        icon: PhosphorIcons.user(),
        label: user == null ? 'Login' : 'Perfil',
        destination: NavDestination.profile,
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

    final effectiveSelected = (isSuperuser || isLeader)
        ? selected
        : (selected == NavDestination.manage ? NavDestination.home : selected);

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
        children: items.map((item) {
          final isSelected = item.destination == effectiveSelected;
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
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final NavDestination destination;

  _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.destination,
  });
}
