import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/widgets/guards/superuser_gate.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
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
    final nome = (data['nome'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final tipo = (data['tipo'] ?? '').toString();

    final haystack = _normalize('${doc.id} $nome $email $tipo');
    return haystack.contains(normalizedQuery);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalize(_query);

    return SuperuserGate(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Gestão de usuários'),
          backgroundColor: const Color(0xFF0F6E58),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Erro ao carregar usuários: ${snap.error}'));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final allDocs = snap.data!.docs;
            if (allDocs.isEmpty) return const Center(child: Text('Nenhum usuário.'));

            final filteredDocs = allDocs.where((d) => _matches(d, normalizedQuery)).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, email ou UID',
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
                      ? const Center(child: Text('Nenhum usuário encontrado.'))
                      : ListView.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, i) {
                            final doc = filteredDocs[i];
                            final data = doc.data();
                            final nome = (data['nome'] ?? '').toString();
                            final email = (data['email'] ?? '').toString();
                            final tipo = (data['tipo'] ?? 'comum').toString();
                            final ativo = (data['ativo'] as bool?) ?? true;
                            final emailPrefix = email.isEmpty ? '' : '$email • ';

                            return Card(
                              child: ListTile(
                                title: Text(nome.isEmpty ? doc.id : nome),
                                subtitle: Text('$emailPrefix$tipo${ativo ? '' : ' • inativo'}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'toggle') {
                                      await doc.reference.update({'ativo': !ativo});
                                    } else if (v == 'leaderScopes') {
                                      await _editLeaderScope(context, doc.reference, data);
                                    } else if (v.startsWith('role:')) {
                                      final newRole = v.split(':')[1];
                                      if (newRole == 'lider') {
                                        await _setAsLeaderWithScope(context, doc.reference, data);
                                      } else {
                                        await doc.reference.update({
                                          'tipo': newRole,
                                          // Limpa escopo se deixar de ser líder.
                                          'liderScopeType': null,
                                          'liderScopeId': null,
                                          'liderPpgIds': null,
                                          'liderGrupoPesquisaIds': null,
                                          'liderAreaIds': null,
                                        });
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: 'toggle', child: Text(ativo ? 'Desativar' : 'Ativar')),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(value: 'role:comum', child: Text('Definir como comum')),
                                    const PopupMenuItem(value: 'role:lider', child: Text('Definir como líder (com escopo)')),
                                    const PopupMenuItem(value: 'role:superuser', child: Text('Definir como superuser')),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(value: 'leaderScopes', child: Text('Editar escopo do líder')),
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

class _LeaderScopeOption {
  final String id;
  final String name;
  final int order;

  const _LeaderScopeOption({
    required this.id,
    required this.name,
    required this.order,
  });
}

class _LeaderScopeSelection {
  final String type; // 'ppg' | 'grupo'
  final String id;

  const _LeaderScopeSelection({
    required this.type,
    required this.id,
  });
}

Future<void> _setAsLeaderWithScope(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> userRef,
  Map<String, dynamic> existing,
) async {
  final selection = await _pickLeaderScope(context);
  if (selection == null) return;

  final isPpg = selection.type == 'ppg';
  await userRef.update({
    'tipo': 'lider',
    'liderScopeType': selection.type,
    'liderScopeId': selection.id,
    // Mantém compatibilidade com código antigo (arrays) mas garantindo 1 item.
    'liderPpgIds': isPpg ? <String>[selection.id] : null,
    'liderGrupoPesquisaIds': isPpg ? null : <String>[selection.id],
    // Este fluxo agora não usa área como escopo do líder.
    'liderAreaIds': null,
  });

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Líder configurado com escopo.')),
    );
  }
}

Future<void> _editLeaderScope(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> userRef,
  Map<String, dynamic> existing,
) async {
  final selection = await _pickLeaderScope(
    context,
    initialType: (existing['liderScopeType'] ?? '').toString(),
    initialId: (existing['liderScopeId'] ?? '').toString(),
  );
  if (selection == null) return;

  final isPpg = selection.type == 'ppg';
  await userRef.update({
    'liderScopeType': selection.type,
    'liderScopeId': selection.id,
    'liderPpgIds': isPpg ? <String>[selection.id] : null,
    'liderGrupoPesquisaIds': isPpg ? null : <String>[selection.id],
    'liderAreaIds': null,
  });

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escopo do líder atualizado.')),
    );
  }
}

Future<_LeaderScopeSelection?> _pickLeaderScope(
  BuildContext context, {
  String? initialType,
  String? initialId,
}) async {
  String type = (initialType ?? '').trim().toLowerCase();
  if (type != 'ppg' && type != 'grupo') type = 'ppg';
  String? selectedId = (initialId ?? '').trim();
  if (selectedId.isEmpty) selectedId = null;

  Future<List<_LeaderScopeOption>> optionsFuture = _loadLeaderScopeOptions(type);

  return showDialog<_LeaderScopeSelection?>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Definir escopo do líder'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: const Text('PPG'),
                      value: 'ppg',
                      groupValue: type,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          type = v;
                          selectedId = null;
                          optionsFuture = _loadLeaderScopeOptions(type);
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Grupo de Pesquisa'),
                      value: 'grupo',
                      groupValue: type,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          type = v;
                          selectedId = null;
                          optionsFuture = _loadLeaderScopeOptions(type);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<_LeaderScopeOption>>(
                      future: optionsFuture,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            'Erro ao carregar opções: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final options = snap.data!;
                        if (options.isEmpty) {
                          return const Text(
                            'Nenhuma opção encontrada. Verifique se existe o menu de PPGs/Grupos e se ele possui submenus.',
                            style: TextStyle(color: Colors.black54),
                          );
                        }

                        // Se o initialId vier e existir, mantém.
                        final hasSelected = selectedId != null && options.any((o) => o.id == selectedId);
                        if (selectedId != null && !hasSelected) {
                          selectedId = null;
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedId,
                          isExpanded: true,
                          menuMaxHeight: 360,
                          decoration: InputDecoration(
                            labelText: type == 'ppg' ? 'Selecione o PPG' : 'Selecione o grupo',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final o in options)
                              DropdownMenuItem(
                                value: o.id,
                                child: Text(
                                  o.name.isEmpty ? o.id : o.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => selectedId = v),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        _LeaderScopeSelection(type: type, id: selectedId!),
                      ),
              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}

Future<List<_LeaderScopeOption>> _loadLeaderScopeOptions(String type) async {
  final menusRef = FirebaseFirestore.instance.collection('menus');
  final menusSnap = await menusRef.get();

  final normalizedType = type.trim().toLowerCase();
  final keywords = normalizedType == 'grupo'
      ? <String>['grupos de pesquisa', 'grupo de pesquisa', 'grupos', 'grupo']
      : <String>['programas de pós-graduação', 'pos-graduacao', 'pós-graduação', 'ppgs', 'ppg'];

  DocumentSnapshot<Map<String, dynamic>>? root;
  for (final d in menusSnap.docs) {
    final data = d.data();
    final nome = (data['nome'] ?? '').toString().trim().toLowerCase();
    if (nome.isEmpty) continue;
    if (keywords.any(nome.contains)) {
      root = d;
      break;
    }
  }

  if (root == null) {
    return <_LeaderScopeOption>[];
  }

  final subSnap = await root.reference.collection('submenus').get();
  final options = <_LeaderScopeOption>[];

  for (final d in subSnap.docs) {
    final data = d.data();
    final nome = (data['nome'] ?? '').toString();
    final valorFiltroRaw = (data['valorFiltro'] ?? '').toString().trim();
    final idToSave = valorFiltroRaw.isNotEmpty ? valorFiltroRaw : d.id;
    final ordem = (data['ordem'] is int) ? (data['ordem'] as int) : 1 << 30;
    options.add(_LeaderScopeOption(id: idToSave, name: nome, order: ordem));
  }

  options.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return options;
}
