import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  comum,
  lider,
  superuser,
  unknown,
}

class UserProfile {
  final String uid;
  final String? nome;
  final String? email;
  final UserRole role;
  final bool ativo;
  final String? liderScopeType; // 'ppg' | 'grupo'
  final String? liderScopeId;

  const UserProfile({
    required this.uid,
    required this.role,
    required this.ativo,
    this.nome,
    this.email,
    this.liderScopeType,
    this.liderScopeId,
  });

  static UserRole parseRole(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'comum':
      case 'discente':
      case 'docente':
      case 'tae':
      case 'outros':
        return UserRole.comum;
      case 'lider':
        return UserRole.lider;
      case 'superuser':
        return UserRole.superuser;
      default:
        return UserRole.unknown;
    }
  }

  static UserProfile fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      nome: (data['nome'] as String?)?.trim(),
      email: (data['email'] as String?)?.trim(),
      role: parseRole(data['tipo']),
      ativo: (data['ativo'] as bool?) ?? true,
      liderScopeType: (data['liderScopeType'] as String?)?.trim(),
      liderScopeId: (data['liderScopeId'] as String?)?.trim(),
    );
  }
}
