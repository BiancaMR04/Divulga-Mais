import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:divulgapampa/views/artigosscreen.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/widgets/menu_sub_screen.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:diacritic/diacritic.dart';
import '../../widgets/menu_card.dart';

// ✅ normaliza texto para busca
String normalizeText(String text) {
  return removeDiacritics(text)
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _termoPesquisa = '';
  int? _anoInicial;
  int? _anoFinal;
  bool _ultimoAno = false;
  String? _tipoUsuario; // ← tipo do usuário logado

  @override
  void initState() {
    super.initState();
    _carregarTipoUsuario();
  }

  Future<void> _carregarTipoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    setState(() => _tipoUsuario = doc.data()?['tipo'] ?? 'comum');
  }

  Query _artigosQuery() {
    Query q = FirebaseFirestore.instance
        .collection('artigos')
        .where('ativo', isEqualTo: true)
        .orderBy('dataPublicacao', descending: true);

    if (_ultimoAno) {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year - 1, agora.month, agora.day);
      q = q.where('dataPublicacao',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicio));
    } else if (_anoInicial != null && _anoFinal == null) {
      q = q.where('dataPublicacao',
          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(_anoInicial!)));
    } else if (_anoFinal != null && _anoInicial == null) {
      q = q.where('dataPublicacao',
          isLessThanOrEqualTo: Timestamp.fromDate(DateTime(_anoFinal! + 1)));
    } else if (_anoInicial != null && _anoFinal != null) {
      q = q.where('dataPublicacao',
          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(_anoInicial!)));
      q = q.where('dataPublicacao',
          isLessThanOrEqualTo: Timestamp.fromDate(DateTime(_anoFinal! + 1)));
    }

    return q;
  }

  bool _matchesSearch(Map<String, dynamic> data, String termoLower) {
    if (termoLower.isEmpty) return true;
    final termo = normalizeText(termoLower);
    String n(value) => normalizeText((value ?? '').toString());
    final campos = [
      n(data['titulo']),
      n(data['resumo']),
      n(data['conteudo']),
      n(data['autor']),
      n(data['ppgId']),
      n((data['tags'] ?? []).join(' ')),
      n((data['linhasPesquisaIds'] ?? []).join(' ')),
    ];
    return campos.any((campo) => campo.contains(termo));
  }

  IconData _iconeFromString(String nome) {
    switch (nome) {
      case 'school':
        return PhosphorIcons.graduationCap();
      case 'groups':
        return PhosphorIcons.usersThree();
      case 'book':
        return PhosphorIcons.bookBookmark();
      case 'library_books':
        return PhosphorIcons.books();
      case 'info':
        return PhosphorIcons.info();
      case 'phone':
        return PhosphorIcons.phone();
      default:
        return PhosphorIcons.squaresFour();
    }
  }

  Color _corPorIndice(int i) {
    final cores = [
      const Color(0xFFB56B82),
      const Color(0xFF98C8AD),
      const Color(0xFFE0A48F),
      const Color(0xFFAFB5EC),
      const Color(0xFFECD08B),
      const Color(0xFFDC9FD3),
    ];
    return cores[i % cores.length];
  }

  void _abrirFiltroAno() {
    final anoAtual = DateTime.now().year;
    int? tempInicial = _anoInicial;
    int? tempFinal = _anoFinal;
    bool tempUltimoAno = _ultimoAno;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Filtrar por ano de publicação",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                CheckboxListTile(
                  title: const Text("Mostrar apenas artigos do último ano"),
                  value: tempUltimoAno,
                  onChanged: (val) {
                    setModalState(() => tempUltimoAno = val ?? false);
                    if (val == true) {
                      tempInicial = null;
                      tempFinal = null;
                    }
                  },
                ),

                if (!tempUltimoAno) ...[
                  Row(
                    children: [
                      const Text("De: "),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: tempInicial,
                          hint: const Text("Ano inicial"),
                          isExpanded: true,
                          items: List.generate(10, (i) {
                            final ano = anoAtual - i;
                            return DropdownMenuItem(
                              value: ano,
                              child: Text(ano.toString()),
                            );
                          }),
                          onChanged: (val) =>
                              setModalState(() => tempInicial = val),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Até: "),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: tempFinal,
                          hint: const Text("Ano final"),
                          isExpanded: true,
                          items: List.generate(10, (i) {
                            final ano = anoAtual - i;
                            return DropdownMenuItem(
                              value: ano,
                              child: Text(ano.toString()),
                            );
                          }),
                          onChanged: (val) =>
                              setModalState(() => tempFinal = val),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6E58)),
                        onPressed: () {
                          setState(() {
                            _anoInicial = tempInicial;
                            _anoFinal = tempFinal;
                            _ultimoAno = tempUltimoAno;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Aplicar",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _anoInicial = null;
                          _anoFinal = null;
                          _ultimoAno = false;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Limpar"),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double topOffset = 160;
    final filtroAtivo =
        _termoPesquisa.isNotEmpty || _anoInicial != null || _anoFinal != null || _ultimoAno;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: CustomNavBar(tipoUsuario: _tipoUsuario ?? 'comum'),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
                child: Image.asset('assets/home.png', fit: BoxFit.cover)),

            // Conteúdo
            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.only(top: 90),
                child: filtroAtivo
                    ? StreamBuilder<QuerySnapshot>(
                        stream: _artigosQuery().snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final allDocs = snapshot.data!.docs;
                          final termoLower = _termoPesquisa.toLowerCase().trim();

                          final filteredDocs = allDocs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _matchesSearch(data, termoLower);
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return const Center(
                                child: Text("Nenhum artigo encontrado."));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, i) {
                              final data =
                                  filteredDocs[i].data() as Map<String, dynamic>;
                              final titulo = data['titulo'] ?? '';
                              final autor = data['autor'] ?? '';
                              final ppg = data['ppgId'] ?? '';
                              final resumo = data['resumo'] ?? '';
                              final dataPub =
                                  (data['dataPublicacao'] as Timestamp?)
                                      ?.toDate();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(titulo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Text("$autor • $ppg",
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Text(resumo,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                    if (dataPub != null)
                                      Text(
                                        "Publicado em ${dataPub.day}/${dataPub.month}/${dataPub.year}",
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        })
                    : FutureBuilder(
                        future: FirebaseFirestore.instance
                            .collection('menus')
                            .where('ativo', isEqualTo: true)
                            .orderBy('ordem')
                            .get(),
                        builder: (context, menuSnap) {
                          if (!menuSnap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final menus = menuSnap.data!.docs;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                              children: List.generate(menus.length, (index) {
                                final menu = menus[index];
                                final tipo = menu['tipo'] ?? 'submenu';
                                return MenuCard(
                                  titulo: menu['nome'],
                                  icone: _iconeFromString(menu['icone']),
                                  cor: _corPorIndice(index),
                                  onTap: () async {
                                    if (tipo == 'submenu') {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => MenuSubScreen(
                                                    titulo: menu['nome'],
                                                    subCollection: menu.reference
                                                        .collection('submenus'),
                                                  )));
                                    } else if (tipo == 'artigos') {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ArtigosScreen(
                                                    titulo: menu['nome'],
                                                    filtros: null,
                                                  )));
                                    }
                                  },
                                );
                              }),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // ✅ topo + busca + filtro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                   Padding(
  padding: const EdgeInsets.only(left: 14), // ← aumente ou diminua
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        "Divulga Pampa",
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 8),
      Image.asset('assets/logo.png', height: 130, fit: BoxFit.contain),
    ],
  ),
),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: "Pesquise postagens...",
                              border: InputBorder.none,
                              icon: Icon(Icons.search,
                                  color: Color(0xFF0F6E58)),
                            ),
                            onChanged: (v) =>
                                setState(() => _termoPesquisa = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _abrirFiltroAno,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.filter_list,
                              color: Color(0xFF0F6E58)),
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
