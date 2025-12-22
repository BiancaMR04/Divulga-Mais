import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:divulgapampa/models/user_profile.dart';

class UserProfileService {
  UserProfileService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('usuarios').doc(uid);
  }

  Stream<UserProfile?> watchCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<UserProfile?>.value(null);
    }
    return watchUserProfile(user.uid);
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _userDoc(user.uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

  bool isSuperuser(UserProfile? profile) {
    return profile != null && profile.ativo && profile.role == UserRole.superuser;
  }

  bool isLeader(UserProfile? profile) {
    return profile != null && profile.ativo && profile.role == UserRole.lider;
  }
}
