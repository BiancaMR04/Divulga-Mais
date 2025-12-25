import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divulgapampa/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:divulgapampa/services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ArtigoDetalheScreen extends StatefulWidget {
  final String artigoId;

  const ArtigoDetalheScreen({super.key, required this.artigoId});

  @override
  State<ArtigoDetalheScreen> createState() => _ArtigoDetalheScreenState();
}

class _ArtigoDetalheScreenState extends State<ArtigoDetalheScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: agregação diária sem PII.
    AnalyticsService().trackArticleView(artigoId: widget.artigoId);
  }

  Future<String> _getNomePPG(String ppgId) async {
    if (ppgId.isEmpty) return "";
    try {
      final doc = await FirebaseFirestore.instance
          .collection('programas_pos_graduacao/submenus/')
          .doc(ppgId)
          .get();
      return doc.exists ? (doc.data()?['nome'] ?? ppgId) : ppgId;
    } catch (_) {
      return ppgId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      bottomNavigationBar: CustomNavBar(),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('artigos')
              .doc(widget.artigoId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.data!.exists) {
              return const Center(child: Text("Artigo não encontrado."));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final titulo = data['titulo'] ?? '';
            final autor = data['autor'] ?? '';
            final resumo = data['resumo'] ?? '';
            final conteudo = data['conteudo'] ?? '';
            final imagens = (data['imagens'] as List?)?.cast<String>() ?? [];
            final videos = (data['videos'] as List?)?.cast<String>() ?? [];
            final imagemUnica = data['imagem'] ?? '';
            final videoUnico = data['video'] ?? '';
            final ppgId = data['ppgId'] ?? '';
            final dataPub = (data['dataPublicacao'] as Timestamp?)?.toDate();

            return FutureBuilder<String>(
              future: _getNomePPG(ppgId),
              builder: (context, ppgSnapshot) {
                final nomePPG = ppgSnapshot.data ?? ppgId;

                return Column(
                  children: [
                    // Header fino
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              titulo,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Conteúdo
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Data + autor
                            Text(
                              '${dataPub != null ? DateFormat("dd/MM/yyyy").format(dataPub) : ""}  •  $autor',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),

                            // Título grande
                            Text(
                              titulo,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Nome do PPG real
                            Text(
                              nomePPG,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Resumo
                            if (resumo.isNotEmpty)
                              Text(
                                resumo,
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            const SizedBox(height: 16),

                            // Imagem única
                            if (imagemUnica.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(imagemUnica, fit: BoxFit.cover),
                              ),
                            if (imagemUnica.isNotEmpty) const SizedBox(height: 16),

                            // Lista de imagens
                            for (final img in imagens) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(img, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Vídeo único
                            if (videoUnico.isNotEmpty)
                              _VideoPlayerWidget(url: videoUnico),
                            if (videoUnico.isNotEmpty) const SizedBox(height: 16),

                            // Lista de vídeos
                            for (final vid in videos) ...[
                              _VideoPlayerWidget(url: vid),
                              const SizedBox(height: 16),
                            ],

                            // Conteúdo textual
                            if (conteudo.isNotEmpty)
                              Text(
                                conteudo,
                                style: const TextStyle(fontSize: 14, height: 1.5),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  String? _error;

  String? _externalPlatformLabel(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return null;

    if (s.contains('youtube.com') || s.contains('youtu.be')) return 'YouTube';
    if (s.contains('instagram.com')) return 'Instagram';
    if (s.contains('tiktok.com')) return 'TikTok';
    if (s.contains('facebook.com') || s.contains('fb.watch') || s.contains('fb.com')) return 'Facebook';

    return null;
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link inválido.')),
        );
      }
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    final url = widget.url.trim();
    if (url.isEmpty) {
      _error = 'Vídeo vazio.';
      return;
    }

    // Plataformas que não fornecem URL direta (mp4/hls) para o video_player.
    if (_externalPlatformLabel(url) != null) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _error = 'Link inválido.';
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller
        .initialize()
        .timeout(const Duration(seconds: 12))
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _error = 'Não foi possível carregar o vídeo.';
          });
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url.trim();

    final platform = _externalPlatformLabel(url);
    if (platform != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vídeo ($platform)', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F6E58),
                ),
                onPressed: () => _openExternal(url),
                child: Text('Abrir no $platform', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _openExternal(url),
                child: const Text('Abrir link'),
              ),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(controller),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(controller, allowScrubbing: true),
          ),
          IconButton(
            iconSize: 50,
            color: Colors.white,
            icon: Icon(
              controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
            ),
            onPressed: () {
              setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              });
            },
          ),
        ],
      ),
    );
  }
}
