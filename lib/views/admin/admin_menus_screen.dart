import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/services/storage_media_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
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

  bool get _isGruposDePesquisaContext {
    final t = widget.title.toLowerCase();
    return t.contains('grupos de pesquisa');
  }

  bool get _isAreasContext {
    final t = widget.title.toLowerCase();
    return t.contains('áreas') || t.contains('areas');
  }

  bool get _isPpgsContext {
    final t = widget.title.toLowerCase();
    return t.contains('ppg') ||
        t.contains('pós-graduação') ||
        t.contains('pos-graduacao') ||
        t.contains('programas de pós-graduação') ||
        t.contains('programas de pos-graduacao');
  }

  Future<void> _createGrupoModelo(BuildContext context) async {
    final nomeCtrl = TextEditingController(text: 'Novo grupo');
    String? nomeErro;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Criar grupo (modelo tipo PPG)'),
              content: TextField(
                controller: nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome do grupo',
                  errorText: nomeErro,
                ),
                onChanged: (_) {
                  if (nomeErro != null) {
                    setDialogState(() => nomeErro = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                  onPressed: () {
                    final nome = nomeCtrl.text.trim();
                    if (nome.isEmpty) {
                      setDialogState(() => nomeErro = 'Informe o nome do grupo.');
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Criar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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

    final bool allowMediaUpload = normalizedNome.contains('sobre o app') ||
      normalizedNome.contains('sobre a unipampa') ||
      normalizedNome.contains('sobre unipampa');

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

    TextEditingController? videoCtrl;
    if (imagemCtrl != null && allowMediaUpload) {
      videoCtrl = TextEditingController(text: (existing['video'] ?? '').toString());
    }

    final initialImagemUrlTrim = (existing['imagem'] ?? '').toString().trim();
    final initialVideoUrlTrim = (existing['video'] ?? '').toString().trim();
    final initialImagemStoragePath = (existing['imagemStoragePath'] ?? '').toString().trim();
    final initialVideoStoragePath = (existing['videoStoragePath'] ?? '').toString().trim();

    PlatformFile? pickedImagem;
    PlatformFile? pickedVideo;
    bool removeImagem = false;
    bool removeVideo = false;

    String? descErro;
    String? contatosErro;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                        decoration: InputDecoration(
                          labelText: 'Texto/descrição',
                          alignLabelWithHint: true,
                          errorText: descErro,
                        ),
                        onChanged: (_) {
                          if (descErro != null) {
                            setDialogState(() => descErro = null);
                          }
                        },
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
                        onChanged: (_) {
                          if (contatosErro != null) {
                            setDialogState(() => contatosErro = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailsCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'E-mails (1 por linha)',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) {
                          if (contatosErro != null) {
                            setDialogState(() => contatosErro = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: redesCtrl,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: 'Redes (1 por linha: nome=url)',
                          hintText:
                              'instagram=https://instagram.com/...\nfacebook=https://facebook.com/...',
                          alignLabelWithHint: true,
                          // Mensagem do grupo de contatos aparece embaixo deste campo
                          errorText: contatosErro,
                        ),
                        onChanged: (_) {
                          if (contatosErro != null) {
                            setDialogState(() => contatosErro = null);
                          }
                        },
                      ),
                    ],
                    if (imagemCtrl != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: imagemCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Imagem (URL opcional)',
                        ),
                        onChanged: (_) {
                          if (removeImagem) {
                            setDialogState(() => removeImagem = false);
                          }
                        },
                      ),
                      if (allowMediaUpload) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F6E58),
                                ),
                                onPressed: () async {
                                  try {
                                    final file = await StorageMediaService.pickImage();
                                    if (file == null) return;
                                    if (file.size > StorageMediaService.maxBytes) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('Arquivo excede o limite de 100MB.')),
                                        );
                                      }
                                      return;
                                    }
                                    setDialogState(() {
                                      pickedImagem = file;
                                      removeImagem = false;
                                    });
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Erro ao selecionar imagem: $e')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Upload de imagem', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  pickedImagem = null;
                                  removeImagem = true;
                                  imagemCtrl?.clear();
                                });
                              },
                              child: const Text('Remover'),
                            ),
                          ],
                        ),
                        if (pickedImagem != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Selecionado: ${pickedImagem!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ],

                    if (videoCtrl != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: videoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vídeo (URL opcional)',
                        ),
                        onChanged: (_) {
                          if (removeVideo) {
                            setDialogState(() => removeVideo = false);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F6E58),
                              ),
                              onPressed: () async {
                                try {
                                  final file = await StorageMediaService.pickVideo();
                                  if (file == null) return;
                                  if (file.size > StorageMediaService.maxBytes) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(content: Text('Arquivo excede o limite de 100MB.')),
                                      );
                                    }
                                    return;
                                  }
                                  setDialogState(() {
                                    pickedVideo = file;
                                    removeVideo = false;
                                  });
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Erro ao selecionar vídeo: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Upload de vídeo', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                pickedVideo = null;
                                removeVideo = true;
                                videoCtrl?.clear();
                              });
                            },
                            child: const Text('Remover'),
                          ),
                        ],
                      ),
                      if (pickedVideo != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selecionado: ${pickedVideo!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                  onPressed: () {
                    if (!isContatos) {
                      final descricao = descCtrl.text.trim();
                      if (descricao.isEmpty) {
                        setDialogState(() => descErro = 'O texto/descrição é obrigatório.');
                        return;
                      }
                    } else {
                      final telefones = (telefonesCtrl?.text ?? '').trim();
                      final emails = (emailsCtrl?.text ?? '').trim();
                      final redes = (redesCtrl?.text ?? '').trim();
                      final hasAny = telefones.isNotEmpty || emails.isNotEmpty || redes.isNotEmpty;
                      if (!hasAny) {
                        setDialogState(
                          () => contatosErro =
                              'Informe pelo menos 1 contato (telefone, e-mail ou rede).',
                        );
                        return;
                      }
                    }
                    Navigator.pop(ctx, true);
                  },
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

    if (ok != true) return;

    final descricao = descCtrl.text.trim();

    String? uploadedNewImagemPath;
    String? uploadedNewVideoPath;
    bool deletePrevImagem = false;
    bool deletePrevVideo = false;

    String imagemUrl = (imagemCtrl?.text ?? '').trim();
    String videoUrl = (videoCtrl?.text ?? '').trim();

    String? imagemStoragePath = initialImagemStoragePath.isEmpty ? null : initialImagemStoragePath;
    String? videoStoragePath = initialVideoStoragePath.isEmpty ? null : initialVideoStoragePath;

    final telefones = telefonesCtrl == null
        ? null
        : _parseLinesToList(telefonesCtrl.text);
    final emails = emailsCtrl == null ? null : _parseLinesToList(emailsCtrl.text);
    final redes = redesCtrl == null ? null : _parseRedesTextToMap(redesCtrl.text);

    final updates = <String, dynamic>{
      if (!isContatos) 'descricao': descricao.isEmpty ? null : descricao,
      if (isContatos) 'telefones': telefones ?? <String>[],
      if (isContatos) 'emails': emails ?? <String>[],
      if (isContatos) 'redes': redes ?? <String, String>{},
    };

    if (imagemCtrl != null && allowMediaUpload) {
      if (removeImagem || imagemUrl.isEmpty) {
        imagemUrl = '';
        imagemStoragePath = null;
        if (initialImagemStoragePath.isNotEmpty) {
          deletePrevImagem = true;
        }
      }

      if (pickedImagem != null) {
        final storagePath = StorageMediaService.contentImagePath(
          docPath: docRef.path,
          file: pickedImagem!,
        );
        final upload = await StorageMediaService.uploadPlatformFile(
          file: pickedImagem!,
          storagePath: storagePath,
        );
        uploadedNewImagemPath = upload.fullPath;
        imagemUrl = upload.downloadUrl;
        imagemStoragePath = upload.fullPath;
        if (initialImagemStoragePath.isNotEmpty && initialImagemStoragePath != imagemStoragePath) {
          deletePrevImagem = true;
        }
      } else if (initialImagemStoragePath.isNotEmpty && imagemUrl != initialImagemUrlTrim) {
        imagemStoragePath = null;
        deletePrevImagem = true;
      }

      if (removeVideo || videoUrl.isEmpty) {
        videoUrl = '';
        videoStoragePath = null;
        if (initialVideoStoragePath.isNotEmpty) {
          deletePrevVideo = true;
        }
      }

      if (pickedVideo != null) {
        final storagePath = StorageMediaService.contentVideoPath(
          docPath: docRef.path,
          file: pickedVideo!,
        );
        final upload = await StorageMediaService.uploadPlatformFile(
          file: pickedVideo!,
          storagePath: storagePath,
        );
        uploadedNewVideoPath = upload.fullPath;
        videoUrl = upload.downloadUrl;
        videoStoragePath = upload.fullPath;
        if (initialVideoStoragePath.isNotEmpty && initialVideoStoragePath != videoStoragePath) {
          deletePrevVideo = true;
        }
      } else if (initialVideoStoragePath.isNotEmpty && videoUrl != initialVideoUrlTrim) {
        videoStoragePath = null;
        deletePrevVideo = true;
      }

      updates['imagem'] = imagemUrl.isEmpty ? null : imagemUrl;
      updates['imagemStoragePath'] = imagemStoragePath;
      updates['video'] = videoUrl.isEmpty ? null : videoUrl;
      updates['videoStoragePath'] = videoStoragePath;
    } else if (imagemCtrl != null) {
      final imagem = imagemCtrl.text.trim();
      updates['imagem'] = imagem.isEmpty ? null : imagem;
    }

    try {
      await docRef.update(updates);

      if (allowMediaUpload) {
        if (deletePrevImagem) {
          await StorageMediaService.deleteIfExists(initialImagemStoragePath);
        }
        if (deletePrevVideo) {
          await StorageMediaService.deleteIfExists(initialVideoStoragePath);
        }
      }
    } catch (e) {
      // Se fez upload mas não conseguiu salvar no Firestore, evita lixo no Storage.
      try {
        await StorageMediaService.deleteIfExists(uploadedNewImagemPath);
        await StorageMediaService.deleteIfExists(uploadedNewVideoPath);
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar conteúdo: $e')),
        );
      }
      return;
    }
  }

  int _safeOrderOf(Map<String, dynamic> data) {
    final v = data['ordem'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 1 << 30; // sem ordem vai para o fim
  }

  Future<int> _nextOrderFor(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    var maxOrder = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final v = data['ordem'];
      int? order;
      if (v is int) {
        order = v;
      } else if (v is num) {
        order = v.toInt();
      }
      if (order != null && order > maxOrder) {
        maxOrder = order;
      }
    }
    return maxOrder + 1;
  }

  Future<void> _duplicateWithChildren(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> sourceRef,
    Map<String, dynamic> sourceData,
  ) async {
    final nomeCtrl = TextEditingController(
      text: ((sourceData['nome'] ?? '').toString().trim().isEmpty)
          ? 'Cópia'
          : '${(sourceData['nome'] ?? '').toString().trim()} (cópia)',
    );

    String? nomeErro;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Duplicar item'),
              content: TextField(
                controller: nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome do novo item',
                  errorText: nomeErro,
                ),
                onChanged: (_) {
                  if (nomeErro != null) {
                    setDialogState(() => nomeErro = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                  onPressed: () {
                    final newNome = nomeCtrl.text.trim();
                    if (newNome.isEmpty) {
                      setDialogState(() => nomeErro = 'Informe o nome do novo item.');
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Duplicar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final newNome = nomeCtrl.text.trim();
    if (newNome.isEmpty) return;

    final campoFiltro = (sourceData['campoFiltro'] ?? '').toString().trim();
    final valorFiltro = (sourceData['valorFiltro'] ?? '').toString().trim();

    final nextOrder = await _nextOrderFor(_col);
    final newData = Map<String, dynamic>.from(sourceData);
    newData['nome'] = newNome;
    newData['ordem'] = nextOrder;

    // Mantém os filtros como estavam; se forem baseados no ID do doc, reescreve abaixo.
    newData['campoFiltro'] = campoFiltro.isEmpty ? null : campoFiltro;
    newData['valorFiltro'] = valorFiltro.isEmpty ? null : valorFiltro;

    final newRef = await _col.add(newData);

    final shouldRewriteIdBasedFilter =
        valorFiltro == sourceRef.id ||
        campoFiltro == 'ppgId' ||
        campoFiltro == 'ppgIds' ||
        campoFiltro == 'grupoPesquisaId' ||
        campoFiltro == 'grupoPesquisaIds' ||
        campoFiltro == 'areaId' ||
        campoFiltro == 'areasIds';
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
        final childValor = (childData['valorFiltro'] ?? '').toString();
        if (childValor == oldRootId) {
          childData['valorFiltro'] = newRootId;
        }

        final newChildRef = await toRef.collection('submenus').add(childData);
        await copyChildren(child.reference, newChildRef, oldRootId, newRootId);
      }
    }

    await copyChildren(sourceRef, newRef, sourceRef.id, newRef.id);
  }

  Future<void> _createOrEdit({
    DocumentReference<Map<String, dynamic>>? docRef,
    Map<String, dynamic>? existing,
  }) async {
    final isAreas = _isAreasContext;

    final nomeCtrl = TextEditingController(
      text: (existing?['nome'] ?? '').toString(),
    );
    String? nomeErro;
    final iconeCtrl = TextEditingController(
      text: (existing?['icone'] ?? '').toString(),
    );
    final corCtrl = TextEditingController(
      text: (existing?['cor'] ?? '').toString(),
    );

    String tipo = (existing?['tipo'] ?? (isAreas ? 'artigos' : 'submenu')).toString();
    bool ativo = (existing?['ativo'] as bool?) ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(docRef == null ? 'Novo item' : 'Editar item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        errorText: nomeErro,
                      ),
                      onChanged: (_) {
                        if (nomeErro != null) {
                          setDialogState(() => nomeErro = null);
                        }
                      },
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
                      activeColor: const Color(0xFF0F6E58),
                      activeTrackColor: const Color(0x590F6E58),
                      title: const Text('Ativo'),
                      onChanged: (v) {
                        setDialogState(() => ativo = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F6E58),
                  ),
                  onPressed: () {
                    final nome = nomeCtrl.text.trim();
                    if (nome.isEmpty) {
                      setDialogState(() => nomeErro = 'O campo Nome é obrigatório.');
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
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

    final isNew = docRef == null;
    final shouldAutoFilter = isNew && (isAreas || _isPpgsContext || _isGruposDePesquisaContext);
    final String? autoCampoFiltro = !shouldAutoFilter
        ? null
        : (isAreas
            ? 'areaId'
            : (_isGruposDePesquisaContext ? 'grupoPesquisaIds' : 'ppgIds'));

    final data = <String, dynamic>{
      'nome': nome,
      'tipo': isAreas ? 'artigos' : tipo,
      'icone': iconeCtrl.text.trim(),
      'ativo': ativo,
      'cor': corCtrl.text.trim().isEmpty ? null : corCtrl.text.trim(),
    };

    if (shouldAutoFilter) {
      data['campoFiltro'] = autoCampoFiltro;
      // valorFiltro será preenchido automaticamente com o ID do doc criado
      data['valorFiltro'] = null;
    }

    if (docRef == null) {
      data['ordem'] = await _nextOrderFor(_col);
      final created = await _col.add(data);
      if (shouldAutoFilter) {
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
          if (_isGruposDePesquisaContext)
            IconButton(
              tooltip: 'Criar grupo (modelo tipo PPG)',
              onPressed: () => _createGrupoModelo(context),
              icon: const Icon(Icons.copy_all),
            ),
        ],
      ),
      bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
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
