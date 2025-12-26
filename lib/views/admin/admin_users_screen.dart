import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/services/storage_media_service.dart';
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

  Future<String?> _deleteOrDisableAuthUser({
    required String uid,
    required String mode,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('adminDeleteAuthUser');
      final result = await callable.call(<String, dynamic>{
        'uid': uid,
        'mode': mode,
      });
      final modeResult = (result.data is Map)
          ? ((result.data as Map)['mode'] ?? '').toString().trim().toLowerCase()
          : '';

      if (modeResult == 'disable') return 'Login desativado no Auth.';
      if (modeResult == 'delete') return 'Usuário removido do Auth.';
      return 'Auth atualizado.';
    } on FirebaseFunctionsException catch (e) {
      // Se já não existir no Auth, não bloqueia o restante do cleanup.
      if (e.code == 'not-found') {
        return 'Usuário não encontrado no Auth (ok).';
      }
      return 'Falha ao alterar Auth: ${e.message ?? e.code}';
    } catch (e) {
      return 'Falha ao alterar Auth: $e';
    }
  }

  Future<void> _confirmAndDeleteUser(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> userRef,
    Map<String, dynamic> userData,
  ) async {
    final uid = userRef.id;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não é possível excluir o próprio usuário logado.')),
      );
      return;
    }

    final nome = (userData['nome'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();
    final label = nome.isNotEmpty ? nome : (email.isNotEmpty ? email : uid);

    final selectedMode = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text(
          'Tem certeza que deseja excluir "$label"?\n\n'
          'Isso vai remover:\n'
          '• todas as publicações (artigos) desse autor\n'
          '• imagens/vídeos dessas publicações no Storage\n\n'
          'Além disso, você pode:\n'
          '• desativar o login (reversível)\n'
          '• ou excluir (permanente)\n',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
            onPressed: () => Navigator.pop(context, 'disable'),
            child: const Text('Desativar login', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (selectedMode == null) return;

    int deletedArticles = 0;
    int deletedStorage = 0;
    String? authMessage;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Excluindo…'),
        content: SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;

      while (true) {
        final snap = await firestore
            .collection('artigos')
            .where('autorUid', isEqualTo: uid)
            .limit(200)
            .get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final data = doc.data();
          final imagemStoragePath = (data['imagemStoragePath'] ?? '').toString().trim();
          final videoStoragePath = (data['videoStoragePath'] ?? '').toString().trim();

          if (imagemStoragePath.isNotEmpty) {
            await StorageMediaService.deleteIfExists(imagemStoragePath);
            deletedStorage++;
          }
          if (videoStoragePath.isNotEmpty) {
            await StorageMediaService.deleteIfExists(videoStoragePath);
            deletedStorage++;
          }

          await doc.reference.delete();
          deletedArticles++;
        }
      }

      await userRef.delete();

      authMessage = await _deleteOrDisableAuthUser(uid: uid, mode: selectedMode);

      if (context.mounted) {
        Navigator.pop(context); // fecha dialog de progresso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuário excluído. Artigos removidos: $deletedArticles. Mídias removidas: $deletedStorage.'
              '${authMessage == null ? '' : ' $authMessage'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // fecha dialog de progresso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir usuário: $e')),
        );
      }
    }
  }

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
                                    } else if (v == 'delete') {
                                      await _confirmAndDeleteUser(context, doc.reference, data);
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
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir usuário', style: TextStyle(color: Colors.red)),
                                    ),
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
