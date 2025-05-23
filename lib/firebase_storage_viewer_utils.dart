import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

// Classe utilitária para funcionalidades relacionadas à visualização e manipulação de arquivos no Firebase Storage.
class FirebaseStorageViewerUtils {
  // Constantes para o projeto Firebase
  static const String _projectId = "painel-agrogeo";
  static const String _bucketName = "painel-agrogeo.firebasestorage.app";

  // URL base para acesso direto a arquivos no Firebase Storage (domínio correto)
  static const String _storageBaseUrl =
      "https://firebasestorage.googleapis.com/v0/b/painel-agrogeo.firebasestorage.app";

  // Removida constante não utilizada _oldStorageBaseUrl

  /// Abre a pasta de uma etapa específica da Ordem de Serviço no console do Firebase Storage.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço (geralmente "Nome do Serviço DD-MM-AAAA").
  ///   [nomePastaEtapa] - O nome da pasta específica da etapa dentro do diretório 'etapas' (valor de `etapa.storageFolder`).
  static Future<void> abrirPastaEtapaNoConsole({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
  }) async {
    try {
      // Constrói o caminho base no Firebase Storage para a pasta da etapa.
      // Exemplo: clientes/LUIS FERNANDO CORREA BRITO/fazendas/teste 02/DECLARAÇÃO DE POSSE 04-05-2025/etapas/reunir_documentos_pessoais_e_da_propriedade
      final List<String> pathParts = [
        "clientes",
        nomeCliente,
        "fazendas",
        nomeFazenda,
        nomeServicoData,
        "etapas",
        nomePastaEtapa,
      ];

      // Codifica cada segmento do caminho para uso em URL e substitui '/' por '~2F' para o formato do console do Firebase.
      final String encodedPathForFirebaseConsole =
          pathParts.map((part) => Uri.encodeComponent(part)).join("~2F");

      // Monta a URL final para o console do Firebase Storage.
      // Formato: https://console.firebase.google.com/project/<PROJECT_ID>/storage/<BUCKET_NAME>/files/<ENCODED_PATH>
      final String urlString =
          "https://console.firebase.google.com/project/$_projectId/storage/$_bucketName/files/$encodedPathForFirebaseConsole";

      final Uri url = Uri.parse(urlString);

      if (await canLaunchUrl(url)) {
        await launchUrl(url,
            mode: LaunchMode.externalApplication); // Abre no navegador externo
      } else {
        // Tratar o erro ou logar, caso a URL não possa ser aberta.
        developer.log('Não foi possível abrir a URL: $urlString',
            name: 'FirebaseStorageViewerUtils');
        // Você pode querer lançar uma exceção ou mostrar um Snackbar/Toast no app Flutter.
        // throw 'Não foi possível abrir a URL: $urlString';
      }
    } catch (e) {
      developer.log('Erro ao abrir pasta no console: $e',
          name: 'FirebaseStorageViewerUtils');
      rethrow;
    }
  }

  /// Constrói uma URL de download para um arquivo no Firebase Storage.
  ///
  /// Parâmetros:
  ///   [path] - O caminho completo para o arquivo no Storage.
  ///   [alt] - O parâmetro alt para a URL (padrão: "media").
  ///
  /// Retorna:
  ///   Uma URL formatada corretamente para download do arquivo.
  static String buildStorageUrl(String path, {String alt = "media"}) {
    try {
      // Garante que o path não comece com barra
      if (path.startsWith('/')) {
        path = path.substring(1);
      }

      // Codifica o path para URL
      final encodedPath = Uri.encodeComponent(path);

      // Constrói a URL completa com o domínio correto
      return "$_storageBaseUrl/o/$encodedPath?alt=$alt";
    } catch (e) {
      developer.log('Erro ao construir URL de Storage: $e',
          name: 'FirebaseStorageViewerUtils');
      rethrow;
    }
  }

  /// Corrige URLs do Firebase Storage que possam estar usando o domínio incorreto.
  ///
  /// Parâmetros:
  ///   [url] - A URL original que pode conter o domínio incorreto.
  ///
  /// Retorna:
  ///   A URL corrigida com o domínio correto.
  static String fixStorageUrl(String url) {
    try {
      // Se a URL estiver vazia, retorna vazia
      if (url.isEmpty) {
        return url;
      }

      // Se a URL já estiver no formato correto, retorna sem alterações
      if (url.contains(_bucketName)) {
        return url;
      }

      // Substitui o domínio incorreto pelo correto
      if (url.contains("painel-agrogeo.appspot.com")) {
        return url.replaceAll(
            "painel-agrogeo.appspot.com", "painel-agrogeo.firebasestorage.app");
      }

      // Se não for uma URL do Storage ou estiver em outro formato, retorna sem alterações
      return url;
    } catch (e) {
      developer.log('Erro ao corrigir URL: $e',
          name: 'FirebaseStorageViewerUtils');
      return url; // Em caso de erro, retorna a URL original
    }
  }

  /// Método alternativo para corrigir URLs (para compatibilidade com código existente)
  static String corrigirUrlStorage(String url) {
    return fixStorageUrl(url);
  }

  /// Constrói o caminho para uma pasta de etapa específica.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço.
  ///   [nomePastaEtapa] - O nome da pasta da etapa.
  ///
  /// Retorna:
  ///   O caminho completo para a pasta da etapa.
  static String buildEtapaPath({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
  }) {
    try {
      return "clientes/$nomeCliente/fazendas/$nomeFazenda/$nomeServicoData/etapas/$nomePastaEtapa";
    } catch (e) {
      developer.log('Erro ao construir caminho da etapa: $e',
          name: 'FirebaseStorageViewerUtils');
      rethrow;
    }
  }

  /// Constrói uma URL de download para um arquivo específico de uma etapa.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço.
  ///   [nomePastaEtapa] - O nome da pasta da etapa.
  ///   [nomeArquivo] - O nome do arquivo.
  ///
  /// Retorna:
  ///   Uma URL formatada corretamente para download do arquivo.
  static String getEtapaFileUrl({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
    required String nomeArquivo,
  }) {
    try {
      final String path = buildEtapaPath(
        nomeCliente: nomeCliente,
        nomeFazenda: nomeFazenda,
        nomeServicoData: nomeServicoData,
        nomePastaEtapa: nomePastaEtapa,
      );
      return buildStorageUrl("$path/$nomeArquivo");
    } catch (e) {
      developer.log('Erro ao obter URL do arquivo da etapa: $e',
          name: 'FirebaseStorageViewerUtils');
      rethrow;
    }
  }

  /// Verifica se um arquivo .visivel existe na pasta da etapa.
  ///
  /// Este método verifica se a pasta da etapa contém um arquivo .visivel,
  /// indicando que os arquivos estão prontos para visualização.
  /// Utiliza listAll() para maior robustez com as regras de segurança do Storage.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço.
  ///   [nomePastaEtapa] - O nome da pasta da etapa.
  ///
  /// Retorna:
  ///   true se o arquivo .visivel existir, false caso contrário.
  static Future<bool> verificarEtapaVisivel({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
  }) async {
    final String pathDaEtapa = buildEtapaPath(
      nomeCliente: nomeCliente,
      nomeFazenda: nomeFazenda,
      nomeServicoData: nomeServicoData,
      nomePastaEtapa: nomePastaEtapa,
    );
    try {
      final storageRef = FirebaseStorage.instance.ref(pathDaEtapa);
      final listResult = await storageRef.listAll();
      return listResult.items.any((item) => item.name == '.visivel');
    } catch (e) {
      developer.log('Erro ao verificar .visivel em $pathDaEtapa: $e',
          name: 'FirebaseStorageViewerUtils');
      return false;
    }
  }

  /// Verifica se uma etapa está concluída.
  ///
  /// Este método verifica se a pasta da etapa contém um arquivo .keep,
  /// indicando que a etapa está concluída.
  /// Utiliza listAll() para maior robustez com as regras de segurança do Storage.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço.
  ///   [nomePastaEtapa] - O nome da pasta da etapa.
  ///
  /// Retorna:
  ///   true se o arquivo .keep existir, false caso contrário.
  static Future<bool> verificarEtapaConcluida({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
  }) async {
    final String pathDaEtapa = buildEtapaPath(
      nomeCliente: nomeCliente,
      nomeFazenda: nomeFazenda,
      nomeServicoData: nomeServicoData,
      nomePastaEtapa: nomePastaEtapa,
    );
    try {
      final storageRef = FirebaseStorage.instance.ref(pathDaEtapa);
      final listResult = await storageRef.listAll();
      return listResult.items.any((item) => item.name == '.keep');
    } catch (e) {
      developer.log('Erro ao verificar .keep em $pathDaEtapa: $e',
          name: 'FirebaseStorageViewerUtils');
      return false;
    }
  }

  /// Lista todos os arquivos em uma pasta de etapa.
  ///
  /// Este método lista todos os arquivos em uma pasta de etapa,
  /// excluindo os arquivos .keep e .visivel.
  ///
  /// Parâmetros:
  ///   [nomeCliente] - O nome do cliente.
  ///   [nomeFazenda] - O nome da fazenda.
  ///   [nomeServicoData] - O nome da pasta da Ordem de Serviço.
  ///   [nomePastaEtapa] - O nome da pasta da etapa.
  ///
  /// Retorna:
  ///   Uma lista de referências para os arquivos na pasta da etapa.
  static Future<List<Reference>> listarArquivosEtapa({
    required String nomeCliente,
    required String nomeFazenda,
    required String nomeServicoData,
    required String nomePastaEtapa,
  }) async {
    final String path = buildEtapaPath(
      nomeCliente: nomeCliente,
      nomeFazenda: nomeFazenda,
      nomeServicoData: nomeServicoData,
      nomePastaEtapa: nomePastaEtapa,
    );

    final etapaRef = FirebaseStorage.instance.ref(path);

    try {
      final ListResult result = await etapaRef.listAll();

      // Filtra os arquivos .keep e .visivel
      return result.items
          .where((ref) => ref.name != '.keep' && ref.name != '.visivel')
          .toList();
    } catch (e) {
      developer.log('Erro ao listar arquivos da etapa: $e',
          name: 'FirebaseStorageViewerUtils');
      return [];
    }
  }

  /// Obtém a URL de download para um arquivo e aplica a correção de domínio automaticamente.
  ///
  /// Este método é uma conveniência que combina getDownloadURL() com fixStorageUrl().
  ///
  /// Parâmetros:
  ///   [reference] - A referência do arquivo no Firebase Storage.
  ///
  /// Retorna:
  ///   A URL de download corrigida.
  static Future<String> getCorrigidaDownloadURL(Reference reference) async {
    try {
      final String url = await reference.getDownloadURL();
      return fixStorageUrl(url);
    } catch (e) {
      developer.log('Erro ao obter URL de download: $e',
          name: 'FirebaseStorageViewerUtils');
      rethrow; // Propaga a exceção para tratamento adequado pelo chamador
    }
  }
}

/*
COMO USAR ESTE UTILITÁRIO NO SEU APLICATIVO FLUTTER:

1. PARA ABRIR A PASTA NO CONSOLE DO FIREBASE:
   ```dart
   await FirebaseStorageViewerUtils.abrirPastaEtapaNoConsole(
     nomeCliente: "LUIS FERNANDO CORREA BRITO",
     nomeFazenda: "teste 03",
     nomeServicoData: "LAR- LICENCIAMENTO RURAL AMBIENTAL 15-05-2025",
     nomePastaEtapa: "atendimento_de_notificação_se_houver",
   );
   ```

2. PARA VERIFICAR SE UMA ETAPA ESTÁ VISÍVEL:
   ```dart
   bool etapaVisivel = await FirebaseStorageViewerUtils.verificarEtapaVisivel(
     nomeCliente: "LUIS FERNANDO CORREA BRITO",
     nomeFazenda: "teste 03",
     nomeServicoData: "LAR- LICENCIAMENTO RURAL AMBIENTAL 15-05-2025",
     nomePastaEtapa: "atendimento_de_notificação_se_houver",
   );
   ```

3. PARA VERIFICAR SE UMA ETAPA ESTÁ CONCLUÍDA:
   ```dart
   bool etapaConcluida = await FirebaseStorageViewerUtils.verificarEtapaConcluida(
     nomeCliente: "LUIS FERNANDO CORREA BRITO",
     nomeFazenda: "teste 03",
     nomeServicoData: "LAR- LICENCIAMENTO RURAL AMBIENTAL 15-05-2025",
     nomePastaEtapa: "atendimento_de_notificação_se_houver",
   );
   ```

4. PARA LISTAR ARQUIVOS DE UMA ETAPA:
   ```dart
   List<Reference> arquivos = await FirebaseStorageViewerUtils.listarArquivosEtapa(
     nomeCliente: "LUIS FERNANDO CORREA BRITO",
     nomeFazenda: "teste 03",
     nomeServicoData: "LAR- LICENCIAMENTO RURAL AMBIENTAL 15-05-2025",
     nomePastaEtapa: "atendimento_de_notificação_se_houver",
   );
   
   for (var arquivo in arquivos) {
     String url = await arquivo.getDownloadURL();
     // Corrige a URL para evitar erros de CORS
     url = FirebaseStorageViewerUtils.fixStorageUrl(url);
     // Use a URL para exibir ou baixar o arquivo
   }
   ```

5. PARA CORRIGIR UMA URL EXISTENTE (por exemplo, vinda do Firestore):
   ```dart
   final String urlCorrigida = FirebaseStorageViewerUtils.fixStorageUrl(anexo.url);
   await launchUrl(Uri.parse(urlCorrigida));
   ```

6. PARA EXIBIR UMA IMAGEM DO STORAGE:
   ```dart
   Image.network(
     FirebaseStorageViewerUtils.fixStorageUrl(imageUrl),
     loadingBuilder: (context, child, loadingProgress) {
       if (loadingProgress == null) return child;
       return Center(child: CircularProgressIndicator());
     },
     errorBuilder: (context, error, stackTrace) {
       return Icon(Icons.error);
     },
   )
   ```

7. PARA FAZER DOWNLOAD DE UM ARQUIVO:
   ```dart
   final String urlCorrigida = FirebaseStorageViewerUtils.fixStorageUrl(anexo.url);
   await _dio.download(urlCorrigida, savePath);
   ```
*/
