import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:diacritic/diacritic.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/views/postscreen.dart';

String normalizeText(String text) {
  return removeDiacritics(text)
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class ArtigosScreen extends StatefulWidget {
  final String titulo;
  final Map<String, String>? filtros;

  const ArtigosScreen({
    super.key,
    required this.titulo,
    this.filtros,
  });

  @override
  State<ArtigosScreen> createState() => _ArtigosScreenState();
}

class _ArtigosScreenState extends State<ArtigosScreen> {
  String _termoPesquisa = '';
  int? _anoInicial;
  int? _anoFinal;

  Query _artigosQuery() {
    Query q = FirebaseFirestore.instance
        .collection('artigos')
        .where('ativo', isEqualTo: true)
        .orderBy('dataPublicacao', descending: true);

    if (widget.filtros != null && widget.filtros!.isNotEmpty) {
      widget.filtros!.forEach((campo, valor) {
        final useArrayContains =
            campo == 'linhasPesquisaIds' || campo.endsWith('Ids');
        if (useArrayContains) {
          q = q.where(campo, arrayContains: valor);
        } else {
          q = q.where(campo, isEqualTo: valor);
        }
      });
    }

    // Filtros de ano
    if (_anoInicial != null && _anoFinal == null) {
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
      n(data['areaId']),
      n(data['assuntoId']),
      n(data['grupoPesquisaId']),
      n((data['linhasPesquisaIds'] ?? []).join(' ')),
      n((data['tags'] ?? []).join(' ')),
    ];

    return campos.any((campo) => campo.contains(termo));
  }

  void _abrirFiltroAno() {
    final anoAtual = DateTime.now().year;
    int? tempInicial = _anoInicial;
    int? tempFinal = _anoFinal;

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
                const Text(
                  "Filtrar por ano de publicação",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Ano inicial
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

                // Ano final
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
    final bool mostrandoFiltro = _anoInicial != null || _anoFinal != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E58),
      bottomNavigationBar: const CustomNavBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
                child: Image.asset('assets/home.png', fit: BoxFit.cover)),

            Positioned.fill(
              top: topOffset,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.only(top: 90),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _artigosQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    final termoLower = _termoPesquisa.toLowerCase().trim();
                    final filtered = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesSearch(data, termoLower);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text("Nenhum artigo encontrado."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final data =
                            filtered[i].data() as Map<String, dynamic>;
                        final dataPub =
                            (data['dataPublicacao'] as Timestamp?)?.toDate();

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
                              Text(data['titulo'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(data['autor'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(data['resumo'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14)),
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
                  },
                ),
              ),
            ),

            // Barra verde + busca + filtro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(widget.titulo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 95),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Pesquise artigos...',
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
                          ),
                          child: const Icon(Icons.filter_list,
                              color: Color(0xFF0F6E58)),
                        ),
                      ),
                    ],
                  ),
                  if (mostrandoFiltro)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 8),
                      child: Text(
                        "Exibindo resultados filtrados por ano.",
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 13),
                      ),
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
