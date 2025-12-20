import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';

class TextoScreen extends StatelessWidget {
  final DocumentReference docRef;
  const TextoScreen({super.key, required this.docRef});

  @override
  Widget build(BuildContext context) {
    final double topOffset = 160;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: CustomNavBar(),
      body: SafeArea(
        child: Stack(
          children: [
            // Fundo
            Positioned.fill(
              child: Image.asset('assets/home.png', fit: BoxFit.cover),
            ),

            // Container branco
            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
                child: FutureBuilder<DocumentSnapshot>(
                  future: docRef.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('Informações não encontradas.'));
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final String titulo = data['nome'] ?? '';
                    final String descricao = data['descricao'] ?? '';
                    final String? imagem = data['imagem'];

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (imagem != null && imagem.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(imagem),
                            ),

                          const SizedBox(height: 16),

                          Text(
                            descricao,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Topo com botão voltar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Informações',
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
