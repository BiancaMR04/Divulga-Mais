import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/homescreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _loading = true;

  Future<void> _carregarUsuario() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  Widget build(BuildContext context) {
    const double topOffset = 160;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: CustomNavBar(
        tipoUsuario: (_userData?['tipo'] ?? '').toString(),
        selected: NavDestination.profile,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/home.png', fit: BoxFit.cover),
            ),

            // conteúdo
            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _userData == null
                        ? const Center(
                            child: Text(
                              "Nenhum dado encontrado.",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20),
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor:
                                      const Color(0xFF0F6E58).withOpacity(0.1),
                                  child: Icon(
                                    PhosphorIcons.userCircle(),
                                    size: 70,
                                    color: const Color(0xFF0F6E58),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _userData?['nome'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F6E58),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _userData?['email'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F6E58)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _userData?['tipo']?.toString().toUpperCase() ??
                                        '',
                                    style: const TextStyle(
                                      color: Color(0xFF0F6E58),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                const Divider(),
                                const SizedBox(height: 10),

                                // botão logout
                                ElevatedButton.icon(
                                  onPressed: _logout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6E58),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.logout,
                                      color: Colors.white),
                                  label: const Text(
                                    'Sair da conta',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),

            // topo verde
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
},

                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Meu Perfil",
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
    );
  }
}
