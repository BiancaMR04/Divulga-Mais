import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BarraPesquisaGlobal extends StatefulWidget {
  final Map<String, dynamic>? filtrosFixos; // Ex: {"ppgId": "ppg_bioquimica"} ou {"linhasPesquisaIds": "linha_bioqui_biotecnologia"}
  final Function(List<Map<String, dynamic>>) onResultados;

  const BarraPesquisaGlobal({
    super.key,
    this.filtrosFixos,
    required this.onResultados,
  });

  @override
  State<BarraPesquisaGlobal> createState() => _BarraPesquisaGlobalState();
}

class _BarraPesquisaGlobalState extends State<BarraPesquisaGlobal> {
  final TextEditingController _controller = TextEditingController();
  bool _carregando = false;

  void _buscar(String termo) async {
    setState(() => _carregando = true);

    Query query = FirebaseFirestore.instance.collection('artigos');

    // Aplica filtros fixos (quando está dentro de uma área/submenu)
    if (widget.filtrosFixos != null) {
      widget.filtrosFixos!.forEach((campo, valor) {
        final isArray = campo.endsWith("Ids") || campo == "linhasPesquisaIds" || campo == "submenusRelacionados";
        query = isArray ? query.where(campo, arrayContains: valor) : query.where(campo, isEqualTo: valor);
      });
    }

    // Ordena por data
    query = query.orderBy('dataPublicacao', descending: true);

    // Executa consulta
    final snap = await query.get();
    final resultados = snap.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where((data) {
          final termoLower = termo.toLowerCase();
          return termo.isEmpty ||
              (data['titulo']?.toString().toLowerCase().contains(termoLower) ?? false) ||
              (data['resumo']?.toString().toLowerCase().contains(termoLower) ?? false) ||
              (data['conteudo']?.toString().toLowerCase().contains(termoLower) ?? false);
        })
        .toList();

    widget.onResultados(resultados);

    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Pesquisar...',
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Color(0xFF0F6E58)),
              ),
              onChanged: _buscar,
            ),
          ),
        ),
        if (_carregando)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
