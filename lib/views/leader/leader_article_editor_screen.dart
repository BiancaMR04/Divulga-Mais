import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
import 'package:divulgapampa/services/storage_media_service.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';

class _NamedOption {
  final String id;
  final String name;
  final int order;

  const _NamedOption({
    required this.id,
    required this.name,
    required this.order,
  });
}

class LeaderArticleEditorScreen extends StatefulWidget {
  final UserProfile profile;
  final String scopeType; // 'ppg' | 'grupo'
  final String scopeId;
  final DocumentReference<Map<String, dynamic>>? artigoRef;
  final Map<String, dynamic>? initialData;

  const LeaderArticleEditorScreen({
    super.key,
    required this.profile,
    required this.scopeType,
    required this.scopeId,
    this.artigoRef,
    this.initialData,
  });

  @override
  State<LeaderArticleEditorScreen> createState() => _LeaderArticleEditorScreenState();
}

class _LeaderArticleEditorScreenState extends State<LeaderArticleEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _categoriaOptions = <String, String>{
    'geral': 'Geral',
    'editais_noticias': 'Editais e notícias',
  };

  Future<List<_NamedOption>>? _areasFuture;
  Future<List<_NamedOption>>? _linhasFuture;
  String? _selectedAreaId;
  Set<String> _selectedLinhas = <String>{};
  String? _linhaToAddId;
  String _categoria = 'geral';

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _resumoCtrl;
  late final TextEditingController _conteudoCtrl;
  late final TextEditingController _imagemCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _tagsCsvCtrl;

  PlatformFile? _pickedImagem;
  PlatformFile? _pickedVideo;
  bool _removeImagem = false;
  bool _removeVideo = false;

  late final String _initialImagemUrl;
  late final String _initialVideoUrl;
  late final String? _initialImagemStoragePath;
  late final String? _initialVideoStoragePath;

  bool _ativo = true;
  bool _saving = false;

  bool get _isEditing => widget.artigoRef != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? <String, dynamic>{};

    _tituloCtrl = TextEditingController(text: (d['titulo'] ?? '').toString());
    _resumoCtrl = TextEditingController(text: (d['resumo'] ?? '').toString());
    _conteudoCtrl = TextEditingController(text: (d['conteudo'] ?? '').toString());
    _imagemCtrl = TextEditingController(text: (d['imagem'] ?? '').toString());
    _linkCtrl = TextEditingController(text: (d['link'] ?? '').toString());
    _videoCtrl = TextEditingController(text: (d['video'] ?? '').toString());

    _initialImagemUrl = (d['imagem'] ?? '').toString();
    _initialVideoUrl = (d['video'] ?? '').toString();

    final imgPath = (d['imagemStoragePath'] ?? '').toString().trim();
    _initialImagemStoragePath = imgPath.isEmpty ? null : imgPath;

    final vidPath = (d['videoStoragePath'] ?? '').toString().trim();
    _initialVideoStoragePath = vidPath.isEmpty ? null : vidPath;

    String toCsv(dynamic v) {
      final list = (v as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      return list.join(',');
    }

    _tagsCsvCtrl = TextEditingController(text: toCsv(d['tags']));
    _selectedLinhas = (d['linhasPesquisaIds'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toSet() ??
        <String>{};

    final areaId = (d['areaId'] ?? '').toString().trim();
    _selectedAreaId = areaId.isEmpty ? null : areaId;

    final cat = (d['categoria'] ?? '').toString().trim();
    if (_categoriaOptions.containsKey(cat)) {
      _categoria = cat;
    }

    _areasFuture = _loadAreas();
    _linhasFuture = _loadLinhasDoEscopo(widget.scopeType, widget.scopeId);

    _ativo = (d['ativo'] as bool?) ?? true;
  }

  Future<void> _pickImagem() async {
    try {
      final file = await StorageMediaService.pickImage();
      if (file == null) return;
      if (file.size > StorageMediaService.maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arquivo excede o limite de 100MB.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _pickedImagem = file;
          _removeImagem = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await StorageMediaService.pickVideo();
      if (file == null) return;
      if (file.size > StorageMediaService.maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arquivo excede o limite de 100MB.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _pickedVideo = file;
          _removeVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar vídeo: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _resumoCtrl.dispose();
    _conteudoCtrl.dispose();
    _imagemCtrl.dispose();
    _linkCtrl.dispose();
    _videoCtrl.dispose();
    _tagsCsvCtrl.dispose();
    super.dispose();
  }

  List<String> _csvToList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<_NamedOption>> _loadAreas() async {
    final menusRef = FirebaseFirestore.instance.collection('menus');
    final menusSnap = await menusRef.get();

    DocumentSnapshot<Map<String, dynamic>>? root;
    for (final d in menusSnap.docs) {
      final nome = (d.data()['nome'] ?? '').toString().trim().toLowerCase();
      if (nome.contains('áreas') || nome.contains('areas')) {
        root = d;
        break;
      }
    }
    if (root == null) return <_NamedOption>[];

    final subSnap = await root.reference.collection('submenus').where('ativo', isEqualTo: true).get();
    final options = <_NamedOption>[];
    for (final d in subSnap.docs) {
      final data = d.data();
      final nome = (data['nome'] ?? '').toString();
      final valorFiltro = (data['valorFiltro'] ?? '').toString().trim();
      final idToSave = valorFiltro.isNotEmpty ? valorFiltro : d.id;
      final ordem = (data['ordem'] is int) ? (data['ordem'] as int) : 1 << 30;
      options.add(_NamedOption(id: idToSave, name: nome, order: ordem));
    }

    options.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return options;
  }

  Future<List<_NamedOption>> _loadLinhasDoEscopo(String scopeType, String scopeId) async {
    final type = scopeType.trim().toLowerCase();

    final menusRef = FirebaseFirestore.instance.collection('menus');
    final menusSnap = await menusRef.get();

    final keywords = type == 'grupo'
        ? <String>['grupos de pesquisa', 'grupo de pesquisa', 'grupos', 'grupo']
        : <String>['programas de pós-graduação', 'pos-graduacao', 'pós-graduação', 'ppgs', 'ppg'];

    DocumentSnapshot<Map<String, dynamic>>? root;
    for (final d in menusSnap.docs) {
      final nome = (d.data()['nome'] ?? '').toString().trim().toLowerCase();
      if (keywords.any(nome.contains)) {
        root = d;
        break;
      }
    }
    if (root == null) return <_NamedOption>[];

    final scopeSnap = await root.reference.collection('submenus').get();
    DocumentReference<Map<String, dynamic>>? scopeRef;
    for (final d in scopeSnap.docs) {
      final data = d.data();
      final valorFiltro = (data['valorFiltro'] ?? '').toString().trim();
      if (d.id == scopeId || (valorFiltro.isNotEmpty && valorFiltro == scopeId)) {
        scopeRef = d.reference;
        break;
      }
    }
    if (scopeRef == null) return <_NamedOption>[];

    final seen = <String>{};
    final out = <_NamedOption>[];

    Future<void> walk(DocumentReference<Map<String, dynamic>> ref) async {
      final subSnap = await ref.collection('submenus').get();
      for (final d in subSnap.docs) {
        final data = d.data();
        final campo = (data['campoFiltro'] ?? '').toString().trim();
        final valor = (data['valorFiltro'] ?? '').toString().trim();
        final nome = (data['nome'] ?? '').toString();
        final ordem = (data['ordem'] is int) ? (data['ordem'] as int) : 1 << 30;

        if (campo == 'linhasPesquisaIds' && valor.isNotEmpty && !seen.contains(valor)) {
          seen.add(valor);
          out.add(_NamedOption(id: valor, name: nome, order: ordem));
        }

        final hasChildren = (await d.reference.collection('submenus').limit(1).get()).docs.isNotEmpty;
        if (hasChildren) {
          await walk(d.reference);
        }
      }
    }

    await walk(scopeRef);
    out.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  String _displayAuthor() {
    final nome = (widget.profile.nome ?? '').trim();
    if (nome.isNotEmpty) return nome;

    final email = (widget.profile.email ?? '').trim();
    if (email.isNotEmpty) return email;

    return widget.profile.uid;
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    String? uploadedNewImagemPath;
    String? uploadedNewVideoPath;

    setState(() => _saving = true);
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('Usuário não autenticado.');
      }

      final docRef = _isEditing
          ? widget.artigoRef!
          : FirebaseFirestore.instance.collection('artigos').doc();

      final titulo = _tituloCtrl.text.trim();
      final resumo = _resumoCtrl.text.trim();
      final conteudo = _conteudoCtrl.text.trim();
      final areaId = (_selectedAreaId ?? '').trim();
      final link = _linkCtrl.text.trim();
      final tags = _csvToList(_tagsCsvCtrl.text);
      final linhas = _selectedLinhas.toList();

      final initialImagemUrlTrim = _initialImagemUrl.trim();
      final initialVideoUrlTrim = _initialVideoUrl.trim();

      final prevImagemStoragePath = _initialImagemStoragePath;
      final prevVideoStoragePath = _initialVideoStoragePath;

      String imagemUrl = _imagemCtrl.text.trim();
      String videoUrl = _videoCtrl.text.trim();

      String? imagemStoragePath = prevImagemStoragePath;
      String? videoStoragePath = prevVideoStoragePath;

      bool deletePrevImagem = false;
      bool deletePrevVideo = false;

      if (_removeImagem || imagemUrl.isEmpty) {
        imagemUrl = '';
        imagemStoragePath = null;
        if (prevImagemStoragePath != null) {
          deletePrevImagem = true;
        }
      }

      if (_pickedImagem != null) {
        final storagePath = StorageMediaService.articleImagePath(
          artigoId: docRef.id,
          file: _pickedImagem!,
        );
        final upload = await StorageMediaService.uploadPlatformFile(
          file: _pickedImagem!,
          storagePath: storagePath,
        );
        uploadedNewImagemPath = upload.fullPath;
        imagemUrl = upload.downloadUrl;
        imagemStoragePath = upload.fullPath;

        if (prevImagemStoragePath != null && prevImagemStoragePath != imagemStoragePath) {
          deletePrevImagem = true;
        }
      } else if (prevImagemStoragePath != null && imagemUrl != initialImagemUrlTrim) {
        // URL foi alterada manualmente: não conseguimos garantir que ainda é o mesmo arquivo.
        imagemStoragePath = null;
        deletePrevImagem = true;
      }

      if (_removeVideo || videoUrl.isEmpty) {
        videoUrl = '';
        videoStoragePath = null;
        if (prevVideoStoragePath != null) {
          deletePrevVideo = true;
        }
      }

      if (_pickedVideo != null) {
        final storagePath = StorageMediaService.articleVideoPath(
          artigoId: docRef.id,
          file: _pickedVideo!,
        );
        final upload = await StorageMediaService.uploadPlatformFile(
          file: _pickedVideo!,
          storagePath: storagePath,
        );
        uploadedNewVideoPath = upload.fullPath;
        videoUrl = upload.downloadUrl;
        videoStoragePath = upload.fullPath;

        if (prevVideoStoragePath != null && prevVideoStoragePath != videoStoragePath) {
          deletePrevVideo = true;
        }
      } else if (prevVideoStoragePath != null && videoUrl != initialVideoUrlTrim) {
        videoStoragePath = null;
        deletePrevVideo = true;
      }

      final isPpg = widget.scopeType == 'ppg';

      Timestamp? dataPublicacao;
      final initial = widget.initialData;
      final v = initial == null ? null : initial['dataPublicacao'];
      if (v is Timestamp) dataPublicacao = v;

      final data = <String, dynamic>{
        'titulo': titulo,
        'resumo': resumo,
        'conteudo': conteudo,
        'areaId': areaId,
        'categoria': _categoria,
        'imagem': imagemUrl.isEmpty ? null : imagemUrl,
        'imagemStoragePath': imagemStoragePath,
        'link': link,
        'video': videoUrl.isEmpty ? null : videoUrl,
        'videoStoragePath': videoStoragePath,
        'tags': tags,
        'linhasPesquisaIds': linhas,
        'ativo': _ativo,
        'autor': _displayAuthor(),
        'autorUid': authUser.uid,
        'ppgId': isPpg ? widget.scopeId : null,
        'grupoPesquisaId': isPpg ? null : widget.scopeId,
      };

      if (_isEditing) {
        await docRef.update({
          ...data,
          // mantém dataPublicacao se existir; se não existir, define agora.
          'dataPublicacao': dataPublicacao ?? Timestamp.now(),
        });
      } else {
        await docRef.set({
          ...data,
          'dataPublicacao': Timestamp.now(),
        });
      }

      if (deletePrevImagem) {
        await StorageMediaService.deleteIfExists(prevImagemStoragePath);
      }
      if (deletePrevVideo) {
        await StorageMediaService.deleteIfExists(prevVideoStoragePath);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Se fez upload mas não salvou no Firestore, evita lixo no Storage.
      try {
        await StorageMediaService.deleteIfExists(uploadedNewImagemPath);
        await StorageMediaService.deleteIfExists(uploadedNewVideoPath);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar publicação' : 'Nova publicação'),
        backgroundColor: const Color(0xFF0F6E58),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? 'Salvando…' : 'Salvar',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavBar(selected: NavDestination.manage),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  
                ),
                const SizedBox(height: 12),

                
              

                SwitchListTile(
                  value: _ativo,
                  // thumb (bolinha) mais escura para contraste
                  activeColor: const Color(0xFF0F6E58),
                  // track (trilho) verde mais escuro
                  activeTrackColor: const Color(0x590F6E58),
                  onChanged: (v) => setState(() => _ativo = v),
                  title: const Text('Ativo'),
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    helperText: 'Obrigatório',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o título.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _resumoCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Resumo *',
                    helperText: 'Obrigatório',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o resumo.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conteudoCtrl,
                  minLines: 6,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Conteúdo *',
                    helperText: 'Obrigatório',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o conteúdo.';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                FutureBuilder<List<_NamedOption>>(
                  future: _areasFuture,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('Erro ao carregar áreas: ${snap.error}', style: const TextStyle(color: Colors.red));
                    }
                    final options = snap.data ?? const <_NamedOption>[];
                    return DropdownButtonFormField<String>(
                      value: options.any((o) => o.id == _selectedAreaId) ? _selectedAreaId : null,
                      items: [
                        for (final o in options)
                          DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name.isEmpty ? o.id : o.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _selectedAreaId = v),
                      decoration: const InputDecoration(
                        labelText: 'Área *',
                        helperText: 'Obrigatório',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Selecione uma área.';
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categoria,
                  items: [
                    for (final e in _categoriaOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _categoria = v ?? 'geral'),
                  decoration: const InputDecoration(
                    labelText: 'Classificação *',
                    helperText: 'Obrigatório (use “Editais e notícias” para aparecer nesse submenu)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Opcionais',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<_NamedOption>>(
                  future: _linhasFuture,
                  builder: (context, snap) {
                    final options = snap.data ?? const <_NamedOption>[];

                    final idToName = <String, String>{
                      for (final o in options) o.id: (o.name.isEmpty ? o.id : o.name),
                    };

                    final selectedNames = _selectedLinhas
                        .map((id) => idToName[id] ?? id)
                        .toList()
                      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: options.any((o) => o.id == _linhaToAddId) ? _linhaToAddId : null,
                          items: [
                            for (final o in options)
                              DropdownMenuItem(
                                value: o.id,
                                child: Text(o.name.isEmpty ? o.id : o.name),
                              ),
                          ],
                          onChanged: snap.connectionState != ConnectionState.done
                              ? null
                              : (v) => setState(() => _linhaToAddId = v),
                          decoration: const InputDecoration(
                            labelText: 'Linhas de pesquisa (opcional)',
                            helperText: 'Escolha uma linha e clique em “Adicionar”',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                            onPressed: (_linhaToAddId == null)
                                ? null
                                : () {
                                    setState(() {
                                      _selectedLinhas.add(_linhaToAddId!);
                                      _linhaToAddId = null;
                                    });
                                  },
                            child: const Text('Adicionar linha', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        if (selectedNames.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in _selectedLinhas)
                                Chip(
                                  label: Text(idToName[id] ?? id),
                                  onDeleted: () => setState(() => _selectedLinhas.remove(id)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsCsvCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (csv) (opcional)',
                    helperText: 'Ex.: mindfulness, educacao, psicologia',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imagemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Imagem (URL) (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_removeImagem) {
                      setState(() => _removeImagem = false);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _pickImagem,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                        child: const Text('Upload de imagem', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _pickedImagem = null;
                                _removeImagem = true;
                                _imagemCtrl.clear();
                              });
                            },
                      child: const Text('Remover'),
                    ),
                  ],
                ),
                if (_pickedImagem != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecionado: ${_pickedImagem!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Link (URL) (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _videoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vídeo (URL) (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_removeVideo) {
                      setState(() => _removeVideo = false);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _pickVideo,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                        child: const Text('Upload de vídeo', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _pickedVideo = null;
                                _removeVideo = true;
                                _videoCtrl.clear();
                              });
                            },
                      child: const Text('Remover'),
                    ),
                  ],
                ),
                if (_pickedVideo != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecionado: ${_pickedVideo!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6E58)),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Salvando…' : 'Salvar',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
