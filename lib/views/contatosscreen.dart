import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContatosScreen extends StatelessWidget {
  final DocumentReference docRef;
  const ContatosScreen({super.key, required this.docRef});

  void _showCantOpen(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Não foi possível abrir: $label'),
      ),
    );
  }

  Uri? _tryParseWebUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // Already has a scheme
    final parsed = Uri.tryParse(text);
    if (parsed != null && parsed.hasScheme) return parsed;

    // Common case: user stored "instagram.com/..." or "www..."
    final withHttps = Uri.tryParse('https://$text');
    return withHttps;
  }

  List<String> _asStringList(dynamic v) {
    if (v == null) return const <String>[];
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? const <String>[] : <String>[s];
    }
    if (v is Map) {
      return v.values
          .map((e) => e?.toString() ?? '')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = v.toString().trim();
    return s.isEmpty ? const <String>[] : <String>[s];
  }

  List<Map<String, dynamic>> _asRedesList(dynamic v) {
    if (v == null) return const <Map<String, dynamic>>[];

    if (v is List) {
      return v
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) {
            final nome = (m['nome'] ?? '').toString().trim();
            final url = (m['url'] ?? '').toString().trim();
            return nome.isNotEmpty || url.isNotEmpty;
          })
          .toList();
    }

    if (v is Map) {
      final map = Map<String, dynamic>.from(v);

      // Caso já seja {nome: ..., url: ...}
      if (map.containsKey('nome') || map.containsKey('url')) {
        return <Map<String, dynamic>>[map];
      }

      // Caso comum: { instagram: 'https://...', facebook: 'https://...' }
      // ou: { instagram: {url: '...'}, ... }
      final redes = <Map<String, dynamic>>[];
      for (final entry in map.entries) {
        final keyName = entry.key.toString().trim();
        if (keyName.isEmpty) continue;

        final value = entry.value;
        String url = '';
        String displayName = keyName;
        if (value is String) {
          url = value.trim();
        } else if (value is Map) {
          final vm = Map<String, dynamic>.from(value);
          final vmName = (vm['nome'] ?? vm['titulo'] ?? '').toString().trim();
          if (vmName.isNotEmpty) displayName = vmName;
          url = (vm['url'] ?? vm['link'] ?? vm['href'] ?? '').toString().trim();
        } else if (value != null) {
          url = value.toString().trim();
        }

        if (url.isEmpty) continue;
        redes.add({'nome': displayName, 'url': url});
      }
      return redes;
    }

    return const <Map<String, dynamic>>[];
  }

  Future<void> _abrirUrl(BuildContext context, String url) async {
    final uri = _tryParseWebUrl(url);
    if (uri == null) {
      _showCantOpen(context, url);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showCantOpen(context, url);
  }

  Future<void> _ligar(BuildContext context, String telefone) async {
    final tel = telefone.trim();
    if (tel.isEmpty) {
      _showCantOpen(context, telefone);
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showCantOpen(context, telefone);
  }

  Future<void> _enviarEmail(BuildContext context, String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      _showCantOpen(context, email);
      return;
    }

    // Allow storing "mailto:foo@bar.com" as well
    Uri? uri = Uri.tryParse(e);
    if (uri == null) {
      _showCantOpen(context, email);
      return;
    }
    if (!uri.hasScheme) {
      uri = Uri(scheme: 'mailto', path: e);
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showCantOpen(context, email);
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
                    final telefones = _asStringList(
                      data['telefones'] ?? data['telefone'] ?? data['fone'] ?? data['fones'],
                    );
                    final emails = _asStringList(
                      data['emails'] ?? data['email'] ?? data['e-mail'] ?? data['e-mails'],
                    );
                    final redesRaw =
                        data['redes'] ?? data['rede'] ?? data['redesSociais'] ?? data['redes_sociais'];
                    final redes = _asRedesList(redesRaw);
                    final bool hasRawRedes = redesRaw != null;

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
                                    onTap: () => _ligar(context, t),
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
                                    onTap: () => _enviarEmail(context, e),
                                    )),
                                const SizedBox(height: 14),
                              ],

                              if (redes.isNotEmpty) ...[
                                const Text('🌐 Redes Sociais',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...redes.map((r) {
                                  final nomeRede = (r['nome'] ?? '').toString();
                                  final urlRede = (r['url'] ?? '').toString();
                                  return _buildCardContato(
                                    icon: _iconeRede(nomeRede),
                                    label: nomeRede,
                                    onTap: () => _abrirUrl(context, urlRede),
                                  );
                                }),
                                const SizedBox(height: 14),
                              ] else if (hasRawRedes) ...[
                                const Text('🌐 Redes Sociais',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Nenhuma rede social encontrada (verifique o formato do campo "redes").',
                                  style: TextStyle(color: Colors.black54),
                                ),
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
