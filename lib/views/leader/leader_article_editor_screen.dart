import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:divulgapampa/models/user_profile.dart';
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

    setState(() => _saving = true);
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('Usuário não autenticado.');
      }

      final titulo = _tituloCtrl.text.trim();
      final resumo = _resumoCtrl.text.trim();
      final conteudo = _conteudoCtrl.text.trim();
      final areaId = (_selectedAreaId ?? '').trim();
      final imagem = _imagemCtrl.text.trim();
      final link = _linkCtrl.text.trim();
      final video = _videoCtrl.text.trim();
      final tags = _csvToList(_tagsCsvCtrl.text);
      final linhas = _selectedLinhas.toList();

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
        'imagem': imagem,
        'link': link,
        'video': video,
        'tags': tags,
        'linhasPesquisaIds': linhas,
        'ativo': _ativo,
        'autor': _displayAuthor(),
        'autorUid': authUser.uid,
        'ppgId': isPpg ? widget.scopeId : null,
        'grupoPesquisaId': isPpg ? null : widget.scopeId,
      };

      if (_isEditing) {
        await widget.artigoRef!.update({
          ...data,
          // mantém dataPublicacao se existir; se não existir, define agora.
          'dataPublicacao': dataPublicacao ?? Timestamp.now(),
        });
      } else {
        await FirebaseFirestore.instance.collection('artigos').add({
          ...data,
          'dataPublicacao': Timestamp.now(),
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
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
    final scopeLabel = widget.scopeType == 'ppg' ? 'PPG' : 'Grupo';

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
                  child: Text('$scopeLabel (fixo): ${widget.scopeId}'),
                ),
                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Obrigatórios',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  value: _ativo,
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
                ),
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
                ),

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
