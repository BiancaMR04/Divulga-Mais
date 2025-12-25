import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageMediaUploadResult {
  final String downloadUrl;
  final String fullPath;

  const StorageMediaUploadResult({
    required this.downloadUrl,
    required this.fullPath,
  });
}

class StorageMediaService {
  static const int maxBytes = 100 * 1024 * 1024;

  static String _safeKey(String input) {
    return input
        .trim()
        .replaceAll('.', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('#', '_')
        .replaceAll(' ', '_')
        .replaceAll(':', '_');
  }

  static String _extensionOf(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    if (ext.isNotEmpty) return ext;

    final name = file.name;
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot + 1 < name.length) {
      return name.substring(dot + 1).trim().toLowerCase();
    }

    return 'bin';
  }

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    return result?.files.single;
  }

  static Future<PlatformFile?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb,
    );
    return result?.files.single;
  }

  static String articleImagePath({required String artigoId, required PlatformFile file}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionOf(file);
    return 'artigos/${_safeKey(artigoId)}/imagem_$ts.$ext';
  }

  static String articleVideoPath({required String artigoId, required PlatformFile file}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionOf(file);
    return 'artigos/${_safeKey(artigoId)}/video_$ts.$ext';
  }

  static String contentImagePath({required String docPath, required PlatformFile file}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionOf(file);
    return 'conteudos/${_safeKey(docPath)}/imagem_$ts.$ext';
  }

  static String contentVideoPath({required String docPath, required PlatformFile file}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionOf(file);
    return 'conteudos/${_safeKey(docPath)}/video_$ts.$ext';
  }

  static Future<StorageMediaUploadResult> uploadPlatformFile({
    required PlatformFile file,
    required String storagePath,
  }) async {
    if (file.size > maxBytes) {
      throw Exception('Arquivo excede o limite de 100MB.');
    }

    final ref = FirebaseStorage.instance.ref(storagePath);

    UploadTask task;
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Falha ao ler arquivo (web).');
      }
      task = ref.putData(bytes);
    } else {
      final path = file.path;
      if (path != null) {
        task = ref.putFile(File(path));
      } else if (file.bytes != null) {
        task = ref.putData(file.bytes!);
      } else {
        throw Exception('Falha ao ler arquivo.');
      }
    }

    final snap = await task;
    final url = await snap.ref.getDownloadURL();
    return StorageMediaUploadResult(downloadUrl: url, fullPath: snap.ref.fullPath);
  }

  static Future<void> deleteIfExists(String? fullPath) async {
    final p = (fullPath ?? '').trim();
    if (p.isEmpty) return;

    try {
      await FirebaseStorage.instance.ref(p).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}
