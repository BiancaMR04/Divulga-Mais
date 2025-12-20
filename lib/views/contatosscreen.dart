import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContatosScreen extends StatelessWidget {
  final DocumentReference docRef;
  const ContatosScreen({super.key, required this.docRef});

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _ligar(String telefone) async {
    final uri = Uri(scheme: 'tel', path: telefone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _iconeRede(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('instagram')) return PhosphorIcons.instagramLogo();
    if (lower.contains('facebook')) return PhosphorIcons.facebookLogo();
    if (lower.contains('linkedin')) return PhosphorIcons.linkedinLogo();
    if (lower.contains('twitter') || lower.contains('x')) return PhosphorIcons.twitterLogo();
    return PhosphorIcons.link();
  }

  Widget _buildCardContato({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF0F6E58), size: 28),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // opção responsiva: usa uma porcentagem da altura em vez de um número fixo (evita "comprido" em telas pequenas/altas)
    final double topOffset = MediaQuery.of(context).size.height * 0.16; // ajuste esse valor se quiser igual ao Home
    // se preferir fixo igual Home: use: final double topOffset = 160;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: CustomNavBar(),
      body: SafeArea(
        child: Stack(
          children: [
            // fundo
            Positioned.fill(child: Image.asset('assets/home.png', fit: BoxFit.cover)),

            // container branco (começa em topOffset)
            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.only(top: 40), // espaço visual igual ao Home
                child: FutureBuilder<DocumentSnapshot>(
                  future: docRef.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('Contato não encontrado.'));
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final String docNome = (data['nome'] ?? '').toString();
                    final telefones = List<String>.from(data['telefones'] ?? []);
                    final emails = List<String>.from(data['emails'] ?? []);
                    final redes = List<Map<String, dynamic>>.from(data['redes'] ?? []);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // título dentro do container (ex: nome do PPG / grupo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            docNome,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // conteúdo rolável (apenas 1 ListView, dentro de Expanded)
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (telefones.isNotEmpty) ...[
                                const Text('📞 Telefones',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...telefones.map((t) => _buildCardContato(
                                      icon: PhosphorIcons.phone(),
                                      label: t,
                                      onTap: () => _ligar(t),
                                    )),
                                const SizedBox(height: 14),
                              ],

                              if (emails.isNotEmpty) ...[
                                const Text('📧 E-mails',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...emails.map((e) => _buildCardContato(
                                      icon: PhosphorIcons.envelope(),
                                      label: e,
                                      onTap: () => _enviarEmail(e),
                                    )),
                                const SizedBox(height: 14),
                              ],

                              if (redes.isNotEmpty) ...[
                                const Text('🌐 Redes Sociais',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...redes.map((r) => _buildCardContato(
                                      icon: _iconeRede(r['nome'] ?? ''),
                                      label: r['nome'] ?? '',
                                      onTap: () => _abrirUrl(r['url'] ?? ''),
                                    )),
                                const SizedBox(height: 14),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // topo (onde está o nome do app na Home) — aqui colocamos o título "Contatos" na mesma posição
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // título do topo (posição do "Divulga Pampa" na Home)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Contatos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5), // espaço até a barra de busca
                  // barra de busca (opcional — deixa visual igual à Home)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
