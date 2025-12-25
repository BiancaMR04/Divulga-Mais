import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/storage_media_service.dart';
import 'package:divulgapampa/services/user_profile_service.dart';
import 'package:divulgapampa/views/leader/leader_article_editor_screen.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/widgets/guards/leader_gate.dart';

class LeaderPostsScreen extends StatefulWidget {
  const LeaderPostsScreen({super.key});

  @override
  State<LeaderPostsScreen> createState() => _LeaderPostsScreenState();
}

class _LeaderPostsScreenState extends State<LeaderPostsScreen> {
  final _service = UserProfileService();

  Future<void> _openEditor({
    required UserProfile profile,
    required String scopeType,
    required String scopeId,
    DocumentReference<Map<String, dynamic>>? ref,
    Map<String, dynamic>? initial,
  }) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaderArticleEditorScreen(
          profile: profile,
          scopeType: scopeType,
          scopeId: scopeId,
          artigoRef: ref,
          initialData: initial,
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicação salva.')),
      );
    }
  }

  Future<void> _confirmDelete(DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir publicação'),
        content: const Text('Tem certeza? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final snap = await ref.get();
      final data = snap.data() ?? <String, dynamic>{};

      final imagemStoragePath = (data['imagemStoragePath'] ?? '').toString().trim();
      final videoStoragePath = (data['videoStoragePath'] ?? '').toString().trim();

      await ref.delete();

      await StorageMediaService.deleteIfExists(imagemStoragePath);
      await StorageMediaService.deleteIfExists(videoStoragePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação excluída.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  Future<void> _toggleAtivo(DocumentReference<Map<String, dynamic>> ref, bool ativo) async {
    try {
      await ref.update({'ativo': !ativo});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LeaderGate(
      child: StreamBuilder<UserProfile?>(
        stream: _service.watchCurrentUserProfile(),
        builder: (context, profileSnap) {
          if (!profileSnap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final profile = profileSnap.data!;
          final scopeType = (profile.liderScopeType ?? '').trim().toLowerCase();
          final scopeId = (profile.liderScopeId ?? '').trim();

          final campoEscopo = scopeType == 'grupo' ? 'grupoPesquisaId' : 'ppgId';

          return Scaffold(
            backgroundColor: const Color(0xFFF7F7F7),
            appBar: AppBar(
              title: const Text('Publicações do líder'),
              backgroundColor: const Color(0xFF0F6E58),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
            floatingActionButton: FloatingActionButton(
              backgroundColor: const Color(0xFF0F6E58),
              onPressed: () => _openEditor(profile: profile, scopeType: scopeType, scopeId: scopeId),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('artigos')
                  .where(campoEscopo, isEqualTo: scopeId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erro ao carregar artigos: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mine = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snap.data!.docs);
                mine.sort((a, b) {
                  final ta = a.data()['dataPublicacao'];
                  final tb = b.data()['dataPublicacao'];
                  final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  return db.compareTo(da);
                });

                if (mine.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhuma publicação encontrada para o seu escopo.'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: mine.length,
                  itemBuilder: (context, i) {
                    final doc = mine[i];
                    final data = doc.data();
                    final titulo = (data['titulo'] ?? '').toString();
                    final resumo = (data['resumo'] ?? '').toString();
                    final ativo = (data['ativo'] as bool?) ?? true;
                    final categoria = (data['categoria'] ?? '').toString().trim();
                    final catLabel = categoria == 'editais_noticias' ? 'Editais e notícias' : '';

                    return Card(
                      child: ListTile(
                        title: Text(titulo.isEmpty ? '(sem título)' : titulo),
                        subtitle: Text(
                          resumo.isEmpty
                              ? '${catLabel.isEmpty ? '' : '$catLabel • '}${ativo ? 'Ativo' : 'Inativo'}'
                              : '$resumo${catLabel.isEmpty ? '' : ' • $catLabel'}${ativo ? '' : ' • inativo'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openEditor(
                          profile: profile,
                          scopeType: scopeType,
                          scopeId: scopeId,
                          ref: doc.reference,
                          initial: data,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _openEditor(
                                profile: profile,
                                scopeType: scopeType,
                                scopeId: scopeId,
                                ref: doc.reference,
                                initial: data,
                              );
                            } else if (v == 'toggle') {
                              _toggleAtivo(doc.reference, ativo);
                            } else if (v == 'delete') {
                              _confirmDelete(doc.reference);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'toggle', child: Text(ativo ? 'Desativar' : 'Ativar')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
