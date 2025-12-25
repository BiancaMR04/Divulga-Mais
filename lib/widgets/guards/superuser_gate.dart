import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/user_profile_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';

class SuperuserGate extends StatelessWidget {
  final Widget child;
  final UserProfileService? service;

  const SuperuserGate({
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
        final isSuper = (service ?? UserProfileService()).isSuperuser(profile);
        if (!isSuper) {
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
                  'Esta área é exclusiva para superuser.',
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
