import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/widgets/guards/superuser_gate.dart';

class AdminPostsScreen extends StatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  bool _matches(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String normalizedQuery,
  ) {
    if (normalizedQuery.isEmpty) return true;
    final data = doc.data();
    final titulo = (data['titulo'] ?? '').toString();
    final autor = (data['autor'] ?? '').toString();
    final haystack = _normalize('$titulo $autor');
    return haystack.contains(normalizedQuery);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalize(_query);

    return SuperuserGate(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Moderação de publicações'),
          backgroundColor: const Color(0xFF0F6E58),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('artigos')
              .orderBy('dataPublicacao', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Erro ao carregar publicações: ${snap.error}'));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final allDocs = snap.data!.docs;
            if (allDocs.isEmpty) return const Center(child: Text('Nenhuma publicação.'));

            final filteredDocs = allDocs.where((d) => _matches(d, normalizedQuery)).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por título ou autor',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(child: Text('Nenhuma publicação encontrada.'))
                      : ListView.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, i) {
                            final doc = filteredDocs[i];
                            final data = doc.data();
                            final titulo = (data['titulo'] ?? '').toString();
                            final autor = (data['autor'] ?? '').toString();
                            final ativo = (data['ativo'] as bool?) ?? true;
                            final ts = data['dataPublicacao'] as Timestamp?;
                            final date = ts?.toDate();
                            final authorLabel = autor.isEmpty ? 'Autor desconhecido' : autor;
                            final dateLabel = date == null ? '' : ' • ${date.day}/${date.month}/${date.year}';

                            return Card(
                              child: ListTile(
                                title: Text(titulo.isEmpty ? '(sem título)' : titulo),
                                subtitle: Text('$authorLabel$dateLabel'),
                                leading: Icon(
                                  ativo ? Icons.verified : Icons.hourglass_empty,
                                  color: ativo ? const Color(0xFF0F6E58) : Colors.grey,
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'toggle') {
                                      await doc.reference.update({'ativo': !ativo});
                                    } else if (v == 'edit') {
                                      await _editDialog(context, doc.reference, data);
                                    } else if (v == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Excluir publicação'),
                                          content: const Text('Tem certeza que deseja excluir?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F6E58),
                                              ),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) await doc.reference.delete();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(ativo ? 'Despublicar' : 'Aprovar/publicar'),
                                    ),
                                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                    const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _editDialog(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> ref,
  Map<String, dynamic> existing,
) async {
  final tituloCtrl = TextEditingController(text: (existing['titulo'] ?? '').toString());
  final autorCtrl = TextEditingController(text: (existing['autor'] ?? '').toString());
  final resumoCtrl = TextEditingController(text: (existing['resumo'] ?? '').toString());
  final conteudoCtrl = TextEditingController(text: (existing['conteudo'] ?? '').toString());

  String listToCsv(dynamic v) {
    final list = (v as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return list.join(',');
  }

  final ppgIdsCtrl = TextEditingController(text: listToCsv(existing['ppgIds']));
  final areaIdsCtrl = TextEditingController(text: listToCsv(existing['areaIds']));
  final assuntoIdsCtrl = TextEditingController(text: listToCsv(existing['assuntoIds']));
  final grupoIdsCtrl = TextEditingController(text: listToCsv(existing['grupoPesquisaIds']));
  final linhasIdsCtrl = TextEditingController(text: listToCsv(existing['linhasPesquisaIds']));

  List<String>? csvToList(String text) {
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Editar publicação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: autorCtrl, decoration: const InputDecoration(labelText: 'Autor')),
            TextField(controller: resumoCtrl, decoration: const InputDecoration(labelText: 'Resumo')),
            TextField(controller: conteudoCtrl, decoration: const InputDecoration(labelText: 'Conteúdo'), maxLines: 4),
            const SizedBox(height: 8),
            TextField(controller: ppgIdsCtrl, decoration: const InputDecoration(labelText: 'ppgIds (csv)')),
            TextField(controller: areaIdsCtrl, decoration: const InputDecoration(labelText: 'areaIds (csv)')),
            TextField(controller: assuntoIdsCtrl, decoration: const InputDecoration(labelText: 'assuntoIds (csv)')),
            TextField(controller: grupoIdsCtrl, decoration: const InputDecoration(labelText: 'grupoPesquisaIds (csv)')),
            TextField(controller: linhasIdsCtrl, decoration: const InputDecoration(labelText: 'linhasPesquisaIds (csv)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Salvar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (ok != true) return;

  await ref.update({
    'titulo': tituloCtrl.text.trim(),
    'autor': autorCtrl.text.trim(),
    'resumo': resumoCtrl.text.trim(),
    'conteudo': conteudoCtrl.text.trim(),
    'ppgIds': csvToList(ppgIdsCtrl.text),
    'areaIds': csvToList(areaIdsCtrl.text),
    'assuntoIds': csvToList(assuntoIdsCtrl.text),
    'grupoPesquisaIds': csvToList(grupoIdsCtrl.text),
    'linhasPesquisaIds': csvToList(linhasIdsCtrl.text),
  });
}
