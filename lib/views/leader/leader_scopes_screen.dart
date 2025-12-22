import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/user_profile_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:divulgapampa/widgets/guards/leader_gate.dart';

class LeaderScopesScreen extends StatefulWidget {
  const LeaderScopesScreen({super.key});

  @override
  State<LeaderScopesScreen> createState() => _LeaderScopesScreenState();
}

class _LeaderScopesScreenState extends State<LeaderScopesScreen> {
  final _service = UserProfileService();

  String _n(String v) => v.trim().toLowerCase();

  bool _nameHas(String name, String needle) {
    return _n(name).contains(_n(needle));
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

  Map<String, String> _asRedesMap(dynamic v) {
    if (v == null) return <String, String>{};

    if (v is List) {
      final out = <String, String>{};
      for (final item in v) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final nome = (m['nome'] ?? '').toString().trim();
        final url = (m['url'] ?? '').toString().trim();
        if (nome.isNotEmpty && url.isNotEmpty) out[nome] = url;
      }
      return out;
    }

    if (v is Map) {
      final map = Map<String, dynamic>.from(v);
      if (map.containsKey('nome') || map.containsKey('url')) {
        final nome = (map['nome'] ?? '').toString().trim();
        final url = (map['url'] ?? '').toString().trim();
        if (nome.isNotEmpty && url.isNotEmpty) return <String, String>{nome: url};
        return <String, String>{};
      }

      final out = <String, String>{};
      for (final entry in map.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        final value = entry.value;
        String url = '';
        String name = key;
        if (value is String) {
          url = value.trim();
        } else if (value is Map) {
          final vm = Map<String, dynamic>.from(value);
          final vmName = (vm['nome'] ?? vm['titulo'] ?? '').toString().trim();
          if (vmName.isNotEmpty) name = vmName;
          url = (vm['url'] ?? vm['link'] ?? vm['href'] ?? '').toString().trim();
        } else if (value != null) {
          url = value.toString().trim();
        }

        if (name.isNotEmpty && url.isNotEmpty) out[name] = url;
      }
      return out;
    }

    return <String, String>{};
  }

  Future<_LeaderScopeRefs> _resolveScopeRefs(UserProfile profile) async {
    final scopeType = (profile.liderScopeType ?? '').trim().toLowerCase();
    final scopeId = (profile.liderScopeId ?? '').trim();
    if (scopeId.isEmpty || (scopeType != 'ppg' && scopeType != 'grupo')) {
      throw Exception('Escopo do líder não configurado.');
    }

    final menusRef = FirebaseFirestore.instance.collection('menus');
    final menusSnap = await menusRef.get();

    DocumentSnapshot<Map<String, dynamic>>? root;
    for (final d in menusSnap.docs) {
      final cf = (d.data()['campoFiltro'] ?? '').toString().trim();
      final isPpg = cf == 'ppgId' || cf == 'ppgIds';
      final isGrupo = cf == 'grupoPesquisaId' || cf == 'grupoPesquisaIds';
      if (scopeType == 'ppg' && isPpg) {
        root = d;
        break;
      }
      if (scopeType == 'grupo' && isGrupo) {
        root = d;
        break;
      }
    }

    if (root == null) {
      final keywords = scopeType == 'grupo'
          ? <String>['grupos de pesquisa', 'grupo de pesquisa', 'grupos', 'grupo']
          : <String>['programas de pós-graduação', 'pós-graduação', 'pos-graduacao', 'ppgs', 'ppg'];

      for (final d in menusSnap.docs) {
        final nome = (d.data()['nome'] ?? '').toString();
        if (keywords.any((k) => _nameHas(nome, k))) {
          root = d;
          break;
        }
      }
    }
    if (root == null) throw Exception('Menu raiz de PPG/Grupo não encontrado.');

    final scopeSnap = await root.reference.collection('submenus').get();
    DocumentReference<Map<String, dynamic>>? scopeRef;
    String scopeName = scopeId;
    for (final d in scopeSnap.docs) {
      final data = d.data();
      final vf = (data['valorFiltro'] ?? '').toString().trim();
      if (d.id == scopeId || (vf.isNotEmpty && vf == scopeId)) {
        scopeRef = d.reference;
        scopeName = (data['nome'] ?? scopeId).toString();
        break;
      }
    }
    if (scopeRef == null) throw Exception('Não encontrei o seu PPG/Grupo no menu (submenus).');

    final subSnap = await scopeRef.collection('submenus').get();
    DocumentReference<Map<String, dynamic>>? contatosRef;
    DocumentReference<Map<String, dynamic>>? integrantesRef;
    DocumentReference<Map<String, dynamic>>? sobreRef;
    DocumentReference<Map<String, dynamic>>? linhasRef;

    for (final d in subSnap.docs) {
      final data = d.data();
      final nome = (data['nome'] ?? '').toString();
      final tipo = (data['tipo'] ?? '').toString().trim().toLowerCase();

      if (tipo == 'contatos' || _nameHas(nome, 'contatos')) {
        contatosRef ??= d.reference;
      }

      if (_nameHas(nome, 'integrantes') && (tipo == 'texto' || tipo.isEmpty)) {
        integrantesRef ??= d.reference;
      }

      final hasSobre = _nameHas(nome, 'sobre');
      if (hasSobre && (tipo == 'texto' || tipo.isEmpty)) {
        sobreRef ??= d.reference;
      }

      if ((tipo == 'submenu') && (_nameHas(nome, 'linhas') || _nameHas(nome, 'linha'))) {
        linhasRef ??= d.reference;
      }
    }

    return _LeaderScopeRefs(
      scopeType: scopeType,
      scopeId: scopeId,
      rootRef: root.reference,
      scopeRef: scopeRef,
      scopeName: scopeName,
      contatosRef: contatosRef,
      integrantesRef: integrantesRef,
      sobreRef: sobreRef,
      linhasRef: linhasRef,
    );
  }

  Future<DocumentReference<Map<String, dynamic>>> _ensureChildDoc({
    required DocumentReference<Map<String, dynamic>> scopeRef,
    required String nome,
    required String tipo,
    required String icone,
  }) async {
    final col = scopeRef.collection('submenus');
    final ordem = await _nextOrderFor(col);
    final doc = await col.add({
      'nome': nome,
      'tipo': tipo,
      'ativo': true,
      'ordem': ordem,
      'icone': icone,
    });
    return doc;
  }

  Future<void> _editTextoDoc(BuildContext context, DocumentReference<Map<String, dynamic>> ref, String title) async {
    final snap = await ref.get();
    final existing = snap.data() ?? <String, dynamic>{};

    final ctrl = TextEditingController(text: (existing['descricao'] ?? '').toString());
    final imagemCtrl = TextEditingController(text: (existing['imagem'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Texto',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imagemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Imagem (URL opcional)',
                ),
              ),
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

    final descricao = ctrl.text.trim();
    final imagem = imagemCtrl.text.trim();
    await ref.update({
      'descricao': descricao.isEmpty ? null : descricao,
      'imagem': imagem.isEmpty ? null : imagem,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atualizado.')));
    }
  }

  Future<void> _editContatos(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    final existing = snap.data() ?? <String, dynamic>{};

    final telefonesCtrl = TextEditingController(text: _asStringList(existing['telefones']).join('\n'));
    final emailsCtrl = TextEditingController(text: _asStringList(existing['emails']).join('\n'));

    final redesMap = _asRedesMap(existing['redes']);
    final redesCtrl = TextEditingController(
      text: redesMap.entries.map((e) => '${e.key}=${e.value}').join('\n'),
    );

    Map<String, String> parseRedes(String text) {
      final out = <String, String>{};
      for (final raw in text.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        int idx = line.indexOf('=');
        if (idx < 0) idx = line.indexOf(':');
        if (idx < 0) continue;
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) out[key] = value;
      }
      return out;
    }

    List<String> parseLines(String text) {
      return text
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar contatos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: telefonesCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Telefones (1 por linha)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailsCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'E-mails (1 por linha)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: redesCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Redes (1 por linha: nome=url)',
                  hintText: 'instagram=https://...\nfacebook=https://...',
                  alignLabelWithHint: true,
                ),
              ),
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
      'telefones': parseLines(telefonesCtrl.text),
      'emails': parseLines(emailsCtrl.text),
      'redes': parseRedes(redesCtrl.text),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contatos atualizados.')));
    }
  }

  Future<int> _nextOrderFor(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    int maxOrder = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final ordem = (data['ordem'] is int) ? (data['ordem'] as int) : 0;
      if (ordem > maxOrder) maxOrder = ordem;
    }
    return maxOrder + 1;
  }

  Future<void> _createLinha(BuildContext context, DocumentReference<Map<String, dynamic>> linhasRef) async {
    final nomeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Criar linha de pesquisa'),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome da linha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final nome = nomeCtrl.text.trim();
    if (nome.isEmpty) return;

    final col = linhasRef.collection('submenus');
    final ordem = await _nextOrderFor(col);
    final doc = await col.add({
      'nome': nome,
      'tipo': 'artigos',
      'ativo': true,
      'ordem': ordem,
      'icone': 'book',
      'campoFiltro': 'linhasPesquisaIds',
      'valorFiltro': null,
    });
    await doc.update({'valorFiltro': doc.id});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Linha criada.')));
    }
  }

  Future<void> _renameLinha(BuildContext context, DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> existing) async {
    final nomeCtrl = TextEditingController(text: (existing['nome'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear linha'),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome'),
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
    final nome = nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    await ref.update({'nome': nome});
  }

  Future<void> _deleteLinha(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir linha'),
        content: const Text('Tem certeza?'),
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
    await ref.delete();
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

          return FutureBuilder<_LeaderScopeRefs>(
            future: _resolveScopeRefs(profile),
            builder: (context, scopeSnap) {
              if (scopeSnap.hasError) {
                return Scaffold(
                  backgroundColor: const Color(0xFFF7F7F7),
                  appBar: AppBar(
                    title: const Text('Meu PPG / Grupo'),
                    backgroundColor: const Color(0xFF0F6E58),
                    foregroundColor: Colors.white,
                  ),
                  bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${scopeSnap.error}'),
                    ),
                  ),
                );
              }
              if (!scopeSnap.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final refs = scopeSnap.data!;
              final isPpg = refs.scopeType == 'ppg';
              final title = isPpg ? 'Meu PPG' : 'Meu Grupo';
              final sobreNome = isPpg ? 'Sobre o PPG' : 'Sobre o grupo';

              return Scaffold(
                backgroundColor: const Color(0xFFF7F7F7),
                appBar: AppBar(
                  title: Text('$title: ${refs.scopeName}'),
                  backgroundColor: const Color(0xFF0F6E58),
                  foregroundColor: Colors.white,
                ),
                bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: const Text('Contatos', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(refs.contatosRef == null ? 'Não encontrado — toque para criar.' : 'Editar telefones, e-mails e redes.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final ref = refs.contatosRef ??
                              await _ensureChildDoc(
                                scopeRef: refs.scopeRef,
                                nome: 'Contatos',
                                tipo: 'contatos',
                                icone: 'phone',
                              );
                          if (mounted) setState(() {});
                          await _editContatos(context, ref);
                        },
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: const Text('Integrantes', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(refs.integrantesRef == null ? 'Não encontrado — toque para criar.' : 'Editar o texto de integrantes.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final ref = refs.integrantesRef ??
                              await _ensureChildDoc(
                                scopeRef: refs.scopeRef,
                                nome: 'Integrantes',
                                tipo: 'texto',
                                icone: 'groups',
                              );
                          if (mounted) setState(() {});
                          await _editTextoDoc(context, ref, 'Editar integrantes');
                        },
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(sobreNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(refs.sobreRef == null ? 'Não encontrado — toque para criar.' : 'Editar o texto “Sobre”.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final ref = refs.sobreRef ??
                              await _ensureChildDoc(
                                scopeRef: refs.scopeRef,
                                nome: sobreNome,
                                tipo: 'texto',
                                icone: 'info',
                              );
                          if (mounted) setState(() {});
                          await _editTextoDoc(context, ref, isPpg ? 'Editar sobre o PPG' : 'Editar sobre o grupo');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Linhas de pesquisa',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                                    onPressed: () async {
                                      final linhasRef = refs.linhasRef ??
                                          await _ensureChildDoc(
                                            scopeRef: refs.scopeRef,
                                            nome: 'Linhas de pesquisa',
                                            tipo: 'submenu',
                                            icone: 'book',
                                          );
                                      if (mounted) setState(() {});
                                      await _createLinha(context, linhasRef);
                                    },
                                    child: const Text('Criar', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (refs.linhasRef == null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Ainda não existe o submenu de linhas. Use “Criar” para cadastrar a primeira linha.'),
                                )
                              else
                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: refs.linhasRef!
                                      .collection('submenus')
                                      .orderBy('ordem')
                                      .snapshots(),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: LinearProgressIndicator(),
                                      );
                                    }
                                    final docs = snap.data!.docs;
                                    if (docs.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Text('Nenhuma linha cadastrada.'),
                                      );
                                    }
                                    return Column(
                                      children: [
                                        for (final d in docs)
                                          Builder(
                                            builder: (context) {
                                              final data = d.data();
                                              final nome = (data['nome'] ?? '').toString();
                                              final ativo = (data['ativo'] as bool?) ?? true;
                                              return ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(nome.isEmpty ? d.id : nome),
                                                subtitle: Text(ativo ? 'Ativo' : 'Inativo'),
                                                trailing: PopupMenuButton<String>(
                                                  onSelected: (v) {
                                                    if (v == 'rename') {
                                                      _renameLinha(context, d.reference, data);
                                                    } else if (v == 'toggle') {
                                                      d.reference.update({'ativo': !ativo});
                                                    } else if (v == 'delete') {
                                                      _deleteLinha(context, d.reference);
                                                    }
                                                  },
                                                  itemBuilder: (_) => [
                                                    const PopupMenuItem(value: 'rename', child: Text('Renomear')),
                                                    PopupMenuItem(value: 'toggle', child: Text(ativo ? 'Desativar' : 'Ativar')),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaderScopeRefs {
  final String scopeType;
  final String scopeId;
  final String scopeName;
  final DocumentReference<Map<String, dynamic>> rootRef;
  final DocumentReference<Map<String, dynamic>> scopeRef;
  final DocumentReference<Map<String, dynamic>>? contatosRef;
  final DocumentReference<Map<String, dynamic>>? integrantesRef;
  final DocumentReference<Map<String, dynamic>>? sobreRef;
  final DocumentReference<Map<String, dynamic>>? linhasRef;

  const _LeaderScopeRefs({
    required this.scopeType,
    required this.scopeId,
    required this.scopeName,
    required this.rootRef,
    required this.scopeRef,
    required this.contatosRef,
    required this.integrantesRef,
    required this.sobreRef,
    required this.linhasRef,
  });
}
