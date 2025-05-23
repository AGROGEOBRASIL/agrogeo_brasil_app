// Removido import não utilizado: import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_storage_viewer_utils.dart';
import 'dart:developer' as developer;

/// Serviço para listar arquivos e diretórios no Firebase Storage.
///
/// Esta classe fornece métodos para listar arquivos e diretórios no Firebase Storage
/// usando a API REST do Firebase Storage, com suporte para navegação em pastas.
class FirebaseStorageListService {
  // Nome interno do bucket (usado nas APIs)
  static const String _bucketName = "painel-agrogeo.firebasestorage.app";

  /// Lista arquivos em um diretório do Firebase Storage
  ///
  /// Parâmetros:
  ///   [path] - O caminho do diretório no Storage para listar.
  ///
  /// Retorna:
  ///   Uma lista de objetos StorageItem representando arquivos e diretórios.
  static Future<List<StorageItem>> listarArquivos(String path) async {
    try {
      developer.log('Listando arquivos no caminho: $path',
          name: 'FirebaseStorageListService');

      // Garante que o path não comece com barra
      if (path.startsWith('/')) {
        path = path.substring(1);
      }

      // Constrói a URL de listagem com o domínio correto
      final url =
          'https://firebasestorage.googleapis.com/v0/b/$_bucketName/o?prefix=${Uri.encodeComponent(path)}&delimiter=/';

      // Adiciona cabeçalhos necessários
      final headers = {
        'Origin': 'https://preview.flutlab.io',
        'X-Firebase-Storage-Version': 'webv2',
        // Se você tiver token de autenticação, adicione aqui
        // 'Authorization': 'Firebase $token',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<StorageItem> items = [];

        // Processa prefixos (diretórios)
        if (data['prefixes'] != null) {
          for (var prefix in data['prefixes']) {
            items.add(StorageItem(
              name: _getLastPathSegment(prefix),
              path: prefix,
              isDirectory: true,
            ));
          }
        }

        // Processa itens (arquivos)
        if (data['items'] != null) {
          for (var item in data['items']) {
            // Corrige a URL de download para usar o domínio correto
            String downloadUrl = item['mediaLink'] ?? '';
            downloadUrl =
                FirebaseStorageViewerUtils.corrigirUrlStorage(downloadUrl);

            items.add(StorageItem(
              name: item['name'].split('/').last,
              path: item['name'],
              isDirectory: false,
              size: item['size'],
              contentType: item['contentType'],
              downloadUrl: downloadUrl,
            ));
          }
        }

        return items;
      } else {
        developer.log(
            'Falha ao listar arquivos: ${response.statusCode} - ${response.body}',
            name: 'FirebaseStorageListService');
        throw Exception(
            'Falha ao listar arquivos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('Erro ao listar arquivos: $e',
          name: 'FirebaseStorageListService');
      // Corrigido: throw e → rethrow
      rethrow;
    }
  }

  /// Extrai o último segmento de um caminho
  ///
  /// Parâmetros:
  ///   [path] - O caminho completo.
  ///
  /// Retorna:
  ///   O último segmento do caminho.
  static String _getLastPathSegment(String path) {
    final segments = path.split('/');
    return segments.last.isEmpty && segments.length > 1
        ? segments[segments.length - 2]
        : segments.last;
  }
}

/// Modelo para representar um item do Storage (arquivo ou diretório)
class StorageItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final String? contentType;
  final String? downloadUrl;

  StorageItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.contentType,
    this.downloadUrl,
  });
}

/* 
NOTA IMPORTANTE:
Para que este arquivo funcione corretamente, você precisa adicionar a dependência 'http' 
ao seu arquivo pubspec.yaml:

```yaml
dependencies:
  http: ^1.1.0  # Ou a versão mais recente compatível
```

Depois execute `flutter pub get` para instalar a dependência.
*/
