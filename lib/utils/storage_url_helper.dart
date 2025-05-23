// lib/utils/storage_url_helper.dart

class StorageUrlHelper {
  // Domínio correto para o bucket do Firebase Storage
  static const String _storageBucketUrl =
      "https://firebasestorage.googleapis.com/v0/b/painel-agrogeo.firebasestorage.app";

  // Método para construir URLs corretas para o Firebase Storage
  static String buildStorageUrl(String path, {String alt = "media"}) {
    // Garante que o path não comece com barra
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Codifica o path para URL
    final encodedPath = Uri.encodeComponent(path);

    // Constrói a URL completa com o domínio correto
    return "$_storageBucketUrl/o/$encodedPath?alt=$alt";
  }

  // Método para converter URLs incorretas para o formato correto
  static String fixStorageUrl(String url) {
    // Se a URL já estiver no formato correto, retorna sem alterações
    if (url.contains("painel-agrogeo.firebasestorage.app")) {
      return url;
    }

    // Substitui o domínio incorreto pelo correto
    if (url.contains("painel-agrogeo.appspot.com")) {
      return url.replaceFirst(
          "https://firebasestorage.googleapis.com/v0/b/painel-agrogeo.appspot.com",
          _storageBucketUrl);
    }

    // Se não for uma URL do Storage ou estiver em outro formato, retorna sem alterações
    return url;
  }
}
