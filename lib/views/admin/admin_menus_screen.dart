import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/widgets/guards/superuser_gate.dart';

class AdminMenusScreen extends StatelessWidget {
  const AdminMenusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperuserGate(
      child: const _AdminCollectionScreen(
        title: 'Gerenciar menus',
        collectionPathLabel: 'menus',
        collection: null,
      ),
    );
  }
}

class AdminSubmenusScreen extends StatelessWidget {
  final String title;
  final CollectionReference<Map<String, dynamic>> subCollection;

  const AdminSubmenusScreen({
    super.key,
    required this.title,
    required this.subCollection,
  });

  @override
  Widget build(BuildContext context) {
    return SuperuserGate(
      child: _AdminCollectionScreen(
        title: title,
        collectionPathLabel: subCollection.path,
        collection: subCollection,
      ),
    );
  }
}

class _AdminCollectionScreen extends StatefulWidget {
  final String title;
  final String collectionPathLabel;
  final CollectionReference<Map<String, dynamic>>? collection;

  const _AdminCollectionScreen({
    required this.title,
    required this.collectionPathLabel,
    required this.collection,
  });

  @override
  State<_AdminCollectionScreen> createState() => _AdminCollectionScreenState();
}

class _AdminCollectionScreenState extends State<_AdminCollectionScreen> {
  CollectionReference<Map<String, dynamic>> get _col {
    return widget.collection ?? FirebaseFirestore.instance.collection('menus');
  }

  bool get _isRootMenusContext {
    return widget.collection == null;
  }

  bool get _isGruposDePesquisaContext {
    final t = widget.title.toLowerCase();
    return t.contains('grupos de pesquisa');
  }

  bool get _isAreasContext {
    final t = widget.title.toLowerCase();
    return t.contains('áreas') || t.contains('areas');
  }

  Future<void> _migrateEditaisNoticiasCategoria(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Migrar “Editais e notícias”'),
        content: const Text(
          'Isso vai atualizar automaticamente todos os submenus “Editais e notícias” dentro de PPGs e Grupos de Pesquisa para filtrar por categoria (categoria = editais_noticias).\n\nUse isso se esses submenus foram criados antes da nova classificação.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    int updated = 0;
    int scanned = 0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Migrando…'),
        content: SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final menusRef = FirebaseFirestore.instance.collection('menus');
      final menusSnap = await menusRef.get();

      DocumentSnapshot<Map<String, dynamic>>? findRoot(List<String> keywords) {
        for (final d in menusSnap.docs) {
          final nome = (d.data()['nome'] ?? '').toString().trim().toLowerCase();
          if (nome.isEmpty) continue;
          if (keywords.any(nome.contains)) return d;
        }
        return null;
      }

      final ppgRoot = findRoot(<String>[
        'programas de pós-graduação',
        'pós-graduação',
        'pos-graduacao',
        'ppgs',
        'ppg',
      ]);

      final gruposRoot = findRoot(<String>[
        'grupos de pesquisa',
        'grupo de pesquisa',
        'grupos',
        'grupo',
      ]);

      final roots = <DocumentReference<Map<String, dynamic>>>[];
      if (ppgRoot != null) roots.add(ppgRoot.reference);
      if (gruposRoot != null) roots.add(gruposRoot.reference);

      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      int batchCount = 0;

      Future<void> flushBatch() async {
        if (batchCount == 0) return;
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }

      void queueUpdate(DocumentReference<Map<String, dynamic>> ref) {
        batch.update(ref, {
          'campoFiltro': 'categoria',
          'valorFiltro': 'editais_noticias',
        });
        batchCount += 1;
      }

      bool isTarget(Map<String, dynamic> data) {
        final tipo = (data['tipo'] ?? '').toString().trim().toLowerCase();
        if (tipo != 'artigos') return false;

        final nome = (data['nome'] ?? '').toString().trim().toLowerCase();
        final hasEditais = nome.contains('editais');
        final hasNoticias = nome.contains('noticias') || nome.contains('notícias') || nome.contains('noticia') || nome.contains('notícia');
        if (!(hasEditais && hasNoticias)) return false;

        final cf = (data['campoFiltro'] ?? '').toString().trim();
        final vf = (data['valorFiltro'] ?? '').toString().trim();
        if (cf == 'categoria' && vf == 'editais_noticias') return false;
        return true;
      }

      Future<void> walk(DocumentReference<Map<String, dynamic>> ref) async {
        final sub = await ref.collection('submenus').get();
        for (final d in sub.docs) {
          scanned += 1;
          final data = d.data();
          if (isTarget(data)) {
            queueUpdate(d.reference);
            updated += 1;
            if (batchCount >= 400) {
              await flushBatch();
            }
          }
          await walk(d.reference);
        }
      }

      for (final root in roots) {
        final scopes = await root.collection('submenus').get();
        for (final scope in scopes.docs) {
          await walk(scope.reference);
        }
      }

      await flushBatch();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na migração: $e')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migração concluída: $updated atualizado(s), $scanned verificado(s).')),
      );
    }
  }

  Future<int> _nextOrderFor(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    var maxOrder = 0;
    for (final d in snap.docs) {
      final ordem = _safeOrderOf(d.data());
      if (ordem != (1 << 30) && ordem > maxOrder) {
        maxOrder = ordem;
      }
    }
    return maxOrder + 1;
  }

  Future<void> _duplicateWithChildren(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> sourceRef,
    Map<String, dynamic> sourceData,
  ) async {
    final nomeAtual = (sourceData['nome'] ?? '').toString();
    final nomeCtrl = TextEditingController(text: nomeAtual);
    final campoFiltro = (sourceData['campoFiltro'] ?? '').toString();
    final valorFiltro = (sourceData['valorFiltro'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Duplicar (com submenus)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome do novo item'),
              ),
              const SizedBox(height: 8),
              const Text(
                'A duplicação copia toda a estrutura de submenus.\n\nSe este item usa filtro por ID (ex: valorFiltro = id do PPG), o app vai atualizar automaticamente para o ID novo para não misturar os artigos.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Duplicar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final newNome = nomeCtrl.text.trim();
    if (newNome.isEmpty) return;

    final nextOrder = await _nextOrderFor(_col);
    final newData = Map<String, dynamic>.from(sourceData);
    newData['nome'] = newNome;
    newData['ordem'] = nextOrder;

    // Se o filtro do item de origem estiver amarrado ao ID do próprio doc,
    // reescrevemos para o ID novo após criar o doc (abaixo).
    // Caso contrário, mantemos como estava (slug/manual).
    newData['campoFiltro'] = campoFiltro.isEmpty ? null : campoFiltro;
    newData['valorFiltro'] = valorFiltro.isEmpty ? null : valorFiltro;

    final newRef = await _col.add(newData);

    final shouldRewriteIdBasedFilter =
        valorFiltro == sourceRef.id ||
        campoFiltro == 'ppgId' ||
        campoFiltro == 'ppgIds' ||
        campoFiltro == 'grupoPesquisaId' ||
        campoFiltro == 'grupoPesquisaIds';
    if (shouldRewriteIdBasedFilter) {
      await newRef.update({'valorFiltro': newRef.id});
    }

    Future<void> copyChildren(
      DocumentReference<Map<String, dynamic>> fromRef,
      DocumentReference<Map<String, dynamic>> toRef,
      String oldRootId,
      String newRootId,
    ) async {
      final childrenSnap = await fromRef.collection('submenus').get();
      final children = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(childrenSnap.docs);
      children.sort((a, b) {
        final ao = _safeOrderOf(a.data());
        final bo = _safeOrderOf(b.data());
        return ao.compareTo(bo);
      });

      for (final child in children) {
        final childData = Map<String, dynamic>.from(child.data());

        // Se algum filho também estiver apontando para o ID antigo, atualiza.
        final childValor = (childData['valorFiltro'] ?? '').toString();
        if (childValor == oldRootId) {
          childData['valorFiltro'] = newRootId;
        }

        // Preserve child order as-is
        final newChildRef = await toRef.collection('submenus').add(childData);
        await copyChildren(child.reference, newChildRef, oldRootId, newRootId);
      }
    }

    await copyChildren(sourceRef, newRef, sourceRef.id, newRef.id);
  }

  Future<void> _createGrupoModelo(BuildContext context) async {
    final nomeCtrl = TextEditingController(text: 'Novo grupo');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Criar grupo (modelo tipo PPG)'),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome do grupo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
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

    final ordem = await _nextOrderFor(_col);
    final newRef = await _col.add({
      'nome': nome,
      'tipo': 'submenu',
      'ativo': true,
      'ordem': ordem,
      'icone': 'groups',
      // Importante: artigos usam IDs do grupo em um array (grupoPesquisaIds)
      'campoFiltro': 'grupoPesquisaIds',
      'valorFiltro': null,
    });

    // Filtro por ID do próprio doc
    await newRef.update({'valorFiltro': newRef.id});

    final sub = newRef.collection('submenus');

    Future<DocumentReference<Map<String, dynamic>>> addChild(Map<String, dynamic> data) async {
      return sub.add(data);
    }

    // 1) Integrantes (texto)
    await addChild({
      'nome': 'Integrantes',
      'tipo': 'texto',
      'ativo': true,
      'ordem': 1,
      'icone': 'groups',
    });

    // 2) Contatos
    await addChild({
      'nome': 'Contatos',
      'tipo': 'contatos',
      'ativo': true,
      'ordem': 2,
      'icone': 'phone',
    });

    // 3) Editais e notícias (artigos) filtrados pelo grupo
    await addChild({
      'nome': 'Editais e notícias',
      'tipo': 'artigos',
      'ativo': true,
      'ordem': 3,
      'icone': 'book',
        // Além do filtro do grupo (acumulado), filtra por categoria.
        'campoFiltro': 'categoria',
        'valorFiltro': 'editais_noticias',
    });

    // 4) Linhas de pesquisa (submenu) com linhas de exemplo
    final linhasRef = await addChild({
      'nome': 'Linhas de pesquisa',
      'tipo': 'submenu',
      'ativo': true,
      'ordem': 4,
      'icone': 'book',
    });

    final linhasCol = linhasRef.collection('submenus');

    Future<void> addLinha(String nomeLinha, int ordemLinha) async {
      final linhaDoc = await linhasCol.add({
        'nome': nomeLinha,
        'tipo': 'artigos',
        'ativo': true,
        'ordem': ordemLinha,
        'icone': 'book',
        'campoFiltro': 'linhasPesquisaIds',
        'valorFiltro': null,
      });
      // Cada linha filtra por ID do próprio doc
      await linhaDoc.update({'valorFiltro': linhaDoc.id});
    }

    await addLinha('Linha de pesquisa 1', 1);
    await addLinha('Linha de pesquisa 2', 2);

    // 5) Sobre o grupo (texto)
    await addChild({
      'nome': 'Sobre o grupo',
      'tipo': 'texto',
      'ativo': true,
      'ordem': 5,
      'icone': 'info',
    });
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

  List<String> _parseLinesToList(String text) {
    // Accept newlines and commas; trim and drop empties.
    return text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, String> _asRedesMap(dynamic v) {
    if (v == null) return <String, String>{};

    // List<{nome,url}>
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

      // Single {nome,url}
      if (map.containsKey('nome') || map.containsKey('url')) {
        final nome = (map['nome'] ?? '').toString().trim();
        final url = (map['url'] ?? '').toString().trim();
        if (nome.isNotEmpty && url.isNotEmpty) return <String, String>{nome: url};
        return <String, String>{};
      }

      // { instagram: 'https://...', facebook: {url: '...'} }
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

  Map<String, String> _parseRedesTextToMap(String text) {
    // Each line: "instagram=https://..." or "instagram: https://..."
    final out = <String, String>{};
    final lines = text.split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      int idx = line.indexOf('=');
      if (idx < 0) idx = line.indexOf(':');
      if (idx < 0) continue;

      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }

  Future<void> _editContent(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> existing,
  ) async {
    final tipo = (existing['tipo'] ?? '').toString();
    final nome = (existing['nome'] ?? '').toString();
    final normalizedTipo = tipo.trim().toLowerCase();
    final normalizedNome = nome.trim().toLowerCase();
    final bool isContatos = normalizedTipo == 'contatos' || normalizedNome == 'contatos';

    final descCtrl = TextEditingController(
      text: (existing['descricao'] ?? '').toString(),
    );

    TextEditingController? telefonesCtrl;
    TextEditingController? emailsCtrl;
    TextEditingController? redesCtrl;
    if (isContatos) {
      final telefonesRaw =
          existing['telefones'] ?? existing['telefone'] ?? existing['fone'] ?? existing['fones'];
      final emailsRaw = existing['emails'] ?? existing['email'] ?? existing['e-mail'] ?? existing['e-mails'];
      final redesRaw = existing['redes'] ?? existing['rede'] ?? existing['redesSociais'] ?? existing['redes_sociais'];

      telefonesCtrl = TextEditingController(
        text: _asStringList(telefonesRaw).join('\n'),
      );
      emailsCtrl = TextEditingController(
        text: _asStringList(emailsRaw).join('\n'),
      );

      final redesMap = _asRedesMap(redesRaw);
      final redesText = redesMap.entries
          .map((e) => '${e.key}=${e.value}')
          .join('\n');
      redesCtrl = TextEditingController(text: redesText);
    }

    TextEditingController? imagemCtrl;
    if (normalizedTipo == 'quemsomos' || normalizedTipo == 'texto') {
      imagemCtrl = TextEditingController(text: (existing['imagem'] ?? '').toString());
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(nome.isEmpty ? 'Editar conteúdo' : 'Editar conteúdo: $nome'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isContatos)
                  TextField(
                    controller: descCtrl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Texto/descrição',
                      alignLabelWithHint: true,
                    ),
                  ),
                if (isContatos) ...[
                  const SizedBox(height: 16),
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
                      hintText: 'instagram=https://instagram.com/...\nfacebook=https://facebook.com/...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                if (imagemCtrl != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: imagemCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Imagem (URL opcional)',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F6E58),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Salvar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final descricao = descCtrl.text.trim();
    final imagem = imagemCtrl?.text.trim();

    final telefones = telefonesCtrl == null
        ? null
        : _parseLinesToList(telefonesCtrl.text);
    final emails = emailsCtrl == null ? null : _parseLinesToList(emailsCtrl.text);
    final redes = redesCtrl == null ? null : _parseRedesTextToMap(redesCtrl.text);

    await docRef.update({
      if (!isContatos) 'descricao': descricao.isEmpty ? null : descricao,
      if (imagemCtrl != null) 'imagem': (imagem == null || imagem.isEmpty) ? null : imagem,
      if (isContatos) 'telefones': telefones ?? <String>[],
      if (isContatos) 'emails': emails ?? <String>[],
      if (isContatos) 'redes': redes ?? <String, String>{},
    });
  }

  int _safeOrderOf(Map<String, dynamic> data) {
    final v = data['ordem'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 1 << 30; // sem ordem vai para o fim
  }

  Future<void> _createOrEdit({
    DocumentReference<Map<String, dynamic>>? docRef,
    Map<String, dynamic>? existing,
  }) async {
    final isAreas = _isAreasContext;

    final nomeCtrl = TextEditingController(
      text: (existing?['nome'] ?? '').toString(),
    );
    final iconeCtrl = TextEditingController(
      text: (existing?['icone'] ?? '').toString(),
    );
    final campoFiltroCtrl = TextEditingController(
      text: (existing?['campoFiltro'] ?? '').toString(),
    );
    final valorFiltroCtrl = TextEditingController(
      text: (existing?['valorFiltro'] ?? '').toString(),
    );
    final corCtrl = TextEditingController(
      text: (existing?['cor'] ?? '').toString(),
    );

    String tipo = (existing?['tipo'] ?? (isAreas ? 'artigos' : 'submenu')).toString();
    bool ativo = (existing?['ativo'] as bool?) ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(docRef == null ? 'Novo item' : 'Editar item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: 8),
                    if (isAreas)
                      DropdownButtonFormField<String>(
                        value: 'artigos',
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(value: 'artigos', child: Text('artigos')),
                        ],
                        onChanged: null,
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'submenu',
                            child: Text('submenu'),
                          ),
                          DropdownMenuItem(
                            value: 'artigos',
                            child: Text('artigos'),
                          ),
                          DropdownMenuItem(
                            value: 'contatos',
                            child: Text('contatos'),
                          ),
                          DropdownMenuItem(
                            value: 'quemsomos',
                            child: Text('quemsomos'),
                          ),
                          DropdownMenuItem(value: 'texto', child: Text('texto')),
                        ],
                        onChanged: (v) {
                          setDialogState(() => tipo = v ?? 'submenu');
                        },
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: iconeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ícone (string)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: corCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cor (hex opcional, ex: #0F6E58)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: ativo,
                      title: const Text('Ativo'),
                      onChanged: (v) {
                        setDialogState(() => ativo = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (isAreas) ...[
                      const Text(
                        'Filtros (automático):\n- campoFiltro = areaId\n- valorFiltro = ID da área criada',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ] else ...[
                      TextField(
                        controller: campoFiltroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'campoFiltro (ex: ppgIds)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: valorFiltroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'valorFiltro (ex: ppg_bioquimica)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                  child: const Text(
                    'Salvar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final nome = nomeCtrl.text.trim();
    if (nome.isEmpty) return;

    final data = <String, dynamic>{
      'nome': nome,
      'tipo': isAreas ? 'artigos' : tipo,
      'icone': iconeCtrl.text.trim(),
      'ativo': ativo,
      'campoFiltro': isAreas
        ? 'areaId'
        : (campoFiltroCtrl.text.trim().isEmpty
          ? null
          : campoFiltroCtrl.text.trim()),
      'valorFiltro': isAreas
        ? (docRef?.id)
        : (valorFiltroCtrl.text.trim().isEmpty
          ? null
          : valorFiltroCtrl.text.trim()),
      'cor': corCtrl.text.trim().isEmpty ? null : corCtrl.text.trim(),
    };

    if (docRef == null) {
      data['ordem'] = await _nextOrderFor(_col);
      final created = await _col.add(data);
      if (isAreas) {
        await created.update({'valorFiltro': created.id});
      }
    } else {
      await docRef.update(data);
    }
  }

  Future<void> _deleteRecursive(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    Future<void> deleteChildren(
      DocumentReference<Map<String, dynamic>> ref,
    ) async {
      final children = await ref.collection('submenus').get();
      for (final child in children.docs) {
        await deleteChildren(child.reference);
        await child.reference.delete();
      }
    }

    await deleteChildren(docRef);
    await docRef.delete();
  }

  Future<void> _reorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < list.length; i++) {
      batch.update(list[i].reference, {'ordem': i + 1});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0F6E58),
        foregroundColor: Colors.white,
        actions: [
          if (_isRootMenusContext)
            IconButton(
              tooltip: 'Migrar “Editais e notícias” (categoria)',
              onPressed: () => _migrateEditaisNoticiasCategoria(context),
              icon: const Icon(Icons.auto_fix_high),
            ),
          if (_isGruposDePesquisaContext)
            IconButton(
              tooltip: 'Criar grupo (modelo tipo PPG)',
              onPressed: () => _createGrupoModelo(context),
              icon: const Icon(Icons.copy_all),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F6E58),
        onPressed: () => _createOrEdit(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Coleção: ${widget.collectionPathLabel}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col.snapshots(),
                builder: (context, snap) {
                  assert(() {
                    debugPrint(
                      '[AdminMenus] ${widget.collectionPathLabel} '
                      'state=${snap.connectionState} '
                      'hasData=${snap.hasData} '
                      'hasError=${snap.hasError} '
                      'docs=${snap.data?.docs.length}',
                    );
                    if (snap.hasError) {
                      debugPrint('[AdminMenus] error=${snap.error}');
                    }
                    return true;
                  }());

                  if (snap.hasError) {
                    return ColoredBox(
                      color: const Color(0xFFF7F7F7),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Erro ao carregar ${widget.collectionPathLabel}:\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snap.hasData) {
                    return const ColoredBox(
                      color: Color(0xFFF7F7F7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFF0F6E58),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Carregando...',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sorted =
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snap.data!.docs,
                      );
                  sorted.sort((a, b) {
                    final ao = _safeOrderOf(a.data());
                    final bo = _safeOrderOf(b.data());
                    final byOrder = ao.compareTo(bo);
                    if (byOrder != 0) return byOrder;
                    final an = (a.data()['nome'] ?? '')
                        .toString()
                        .toLowerCase();
                    final bn = (b.data()['nome'] ?? '')
                        .toString()
                        .toLowerCase();
                    return an.compareTo(bn);
                  });

                  if (sorted.isEmpty) {
                    return const ColoredBox(
                      color: Color(0xFFF7F7F7),
                      child: Center(
                        child: Text(
                          'Nenhum item.',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    );
                  }

                  return ColoredBox(
                    color: const Color(0xFFF7F7F7),
                    child: ReorderableListView.builder(
                      itemCount: sorted.length,
                      onReorder: (oldIndex, newIndex) =>
                          _reorder(sorted, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final doc = sorted[index];
                        final data = doc.data();
                        final tipo = (data['tipo'] ?? '').toString();
                        final bool canEditContent =
                            tipo == 'contatos' || tipo == 'quemsomos' || tipo == 'texto';
                        final bool canDuplicate = true;

                        return Card(
                          key: ValueKey(doc.id),
                          child: ListTile(
                            title: Text(data['nome']?.toString() ?? ''),
                            subtitle: Text(
                              '${data['tipo'] ?? ''} • ordem ${data['ordem'] ?? ''} • ${data['ativo'] == true ? 'ativo' : 'inativo'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await _createOrEdit(
                                    docRef: doc.reference,
                                    existing: data,
                                  );
                                } else if (v == 'content') {
                                  await _editContent(context, doc.reference, data);
                                } else if (v == 'duplicate') {
                                  await _duplicateWithChildren(context, doc.reference, data);
                                } else if (v == 'sub') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminSubmenusScreen(
                                        title: 'Submenus: ${data['nome']}',
                                        subCollection: doc.reference.collection(
                                          'submenus',
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (v == 'delete') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Excluir'),
                                      content: const Text(
                                        'Excluir este item e todos os submenus?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0F6E58,
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Excluir',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _deleteRecursive(doc.reference);
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                if (canEditContent)
                                  const PopupMenuItem(
                                    value: 'content',
                                    child: Text('Editar conteúdo'),
                                  ),
                                if (canDuplicate)
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicar (com submenus)'),
                                  ),
                                const PopupMenuItem(
                                  value: 'sub',
                                  child: Text('Submenus'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir (recursivo)'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
