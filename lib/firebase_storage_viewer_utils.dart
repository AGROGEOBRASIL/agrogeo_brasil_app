import 'package:url_launcher/url_launcher.dart';

// Classe utilitária para funcionalidades relacionadas à visualização de arquivos no Firebase Storage.
class FirebaseStorageViewerUtils {
  // Constantes para o projeto Firebase
  static const String _projectId = "painel-agrogeo";
  static const String _bucketName = "painel-agrogeo.firebasestorage.app";

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
      // Por exemplo, mostrar uma mensagem para o usuário.
      print('Não foi possível abrir a URL: $urlString');
      // Você pode querer lançar uma exceção ou mostrar um Snackbar/Toast no app Flutter.
      // throw 'Não foi possível abrir a URL: $urlString';
    }
  }
}

/*
COMO USAR ESTE UTILITÁRIO NO SEU APLICATIVO FLUTTER (por exemplo, na sua OsDetalhesEtapasPage.dart):

1.  ADICIONE A DEPENDÊNCIA `url_launcher`:
    No seu arquivo `pubspec.yaml`, adicione a seguinte linha na seção `dependencies`:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      url_launcher: ^6.0.0 # Use a versão mais recente disponível
    ```
    Depois, execute `flutter pub get` no seu terminal.

2.  IMPORTE ESTE ARQUIVO NA SUA PÁGINA DE DETALHES DA ETAPA:
    ```dart
    import 'caminho/para/firebase_storage_viewer_utils.dart'; // Ajuste o caminho conforme necessário
    ```

3.  CRIE UM BOTÃO "VISUALIZAR ARQUIVOS" PARA CADA ETAPA:
    Dentro do widget que exibe cada etapa, adicione um botão. Supondo que você tenha as informações
    `nomeClienteAtual`, `nomeFazendaAtual`, `nomeDaOSComDataAtual` e `etapa.storageFolder` (onde `etapa` é o objeto da sua etapa atual):

    ```dart
    // Exemplo de um botão dentro da sua lista de etapas:
    ElevatedButton(
      child: Text("Visualizar Arquivos da Etapa"),
      onPressed: () async {
        // Supondo que você tenha as seguintes variáveis disponíveis no contexto:
        // String nomeCliente = "LUIS FERNANDO CORREA BRITO"; // Exemplo
        // String nomeFazenda = "teste 02"; // Exemplo
        // String nomeServicoData = "DECLARAÇÃO DE POSSE 04-05-2025"; // Exemplo, o nome da pasta da OS
        // String nomePastaDestaEtapa = etapa.storageFolder; // Ex: "reunir_documentos_pessoais_e_da_propriedade"

        // Verifique se os dados da OS e da etapa estão disponíveis
        // if (nomeCliente != null && nomeFazenda != null && nomeServicoData != null && nomePastaDestaEtapa != null) {
          try {
            await FirebaseStorageViewerUtils.abrirPastaEtapaNoConsole(
              nomeCliente: nomeClienteAtual, 
              nomeFazenda: nomeFazendaAtual,
              nomeServicoData: nomeDaOSComDataAtual,
              nomePastaEtapa: nomePastaDestaEtapa, // O nome da pasta da etapa específica
            );
          } catch (e) {
            print("Erro ao tentar abrir a pasta da etapa: $e");
            // Mostrar um feedback para o usuário, como um SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Erro ao abrir link: $e")),
            );
          }
        // } else {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text("Dados da OS ou da etapa incompletos para visualizar arquivos.")),
        //   );
        // }
      },
    )
    ```

4.  OBTENHA OS DADOS NECESSÁRIOS:
    - `nomeClienteAtual`: Você já parece ter isso na `OrdensServicoDepartamentoPage` (widget.nomeCliente).
    - `nomeFazendaAtual`: Similarmente, `widget.nomeFazenda`.
    - `nomeDaOSComDataAtual`: Este é o nome da pasta da Ordem de Serviço específica que contém as etapas. 
      No seu código `OrdensServicoDepartamentoPage`, você tem `_getOSTitulo(data, docId)` e `dataCriacaoFormatada`.
      Você precisará garantir que o `OsDetalhesEtapasPage` receba o nome exato da pasta da OS no Storage.
      Pela sua estrutura `gs://painel-agrogeo.firebasestorage.app/clientes/LUIS FERNANDO CORREA BRITO/fazendas/teste 02/DECLARAÇÃO DE POSSE 04-05-2025/etapas`,
      o `nomeServicoData` seria "DECLARAÇÃO DE POSSE 04-05-2025".
    - `nomePastaDestaEtapa`: Este viria do campo `storageFolder` (ou similar) do seu objeto de etapa no Firestore, para cada etapa listada na `OsDetalhesEtapasPage`.

Lembre-se de ajustar os nomes das variáveis e a forma como você obtém esses dados para corresponder à estrutura exata do seu aplicativo.
*/
