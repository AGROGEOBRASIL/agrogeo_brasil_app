// lib/services/firebase_sync_service.dart

// Comentário: Adicionado comentário para indicar que é necessário adicionar a dependência
// cloud_functions: ^4.0.0 (ou versão compatível) no pubspec.yaml
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço responsável por sincronizar dados entre o painel-agrogeo e o app agrogeo-brasil-app
/// usando as Cloud Functions implementadas no projeto painel-agrogeo.
class FirebaseSyncService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Constantes para URLs do Firebase Storage
  static const String _storageBucketUrl =
      "https://firebasestorage.googleapis.com/v0/b/painel-agrogeo.firebasestorage.app";

  /// Construtor que inicializa as instâncias do Firebase
  FirebaseSyncService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Busca os dados do cliente no painel-agrogeo usando o CPF
  ///
  /// Parâmetros:
  /// - [cpf]: CPF do cliente a ser buscado (sem formatação)
  ///
  /// Retorna um mapa com os dados do cliente se encontrado
  Future<Map<String, dynamic>?> buscarClientePorCpf(String cpf) async {
    try {
      // Chama a Cloud Function getClientByCpf
      final HttpsCallable callable = _functions.httpsCallable('getClientByCpf');
      final result = await callable.call<Map<String, dynamic>>({
        'cpf': cpf,
      });

      final responseData = result.data;

      // Verifica se a busca foi bem-sucedida
      if (responseData['success'] == true && responseData['data'] != null) {
        // Cliente encontrado no painel

        // Salva os dados do cliente no Firestore do app
        await _salvarClienteNoApp(responseData['data']);

        // Salva informações básicas no SharedPreferences
        await _salvarDadosLocalmente(responseData['data']);

        return responseData['data'];
      } else {
        // Cliente não encontrado
        return null;
      }
    } catch (e) {
      // Erro ao buscar cliente por CPF
      rethrow;
    }
  }

  /// Salva os dados do cliente no Firestore do app agrogeo-brasil-app
  Future<void> _salvarClienteNoApp(Map<String, dynamic> clienteData) async {
    try {
      // Obtém o UID do usuário autenticado
      final String? userUid = _auth.currentUser?.uid;

      if (userUid == null) {
        throw Exception('Usuário não autenticado');
      }

      // Salva os dados do cliente na coleção 'clientes' usando o UID do usuário como ID do documento
      await _firestore.collection('clientes').doc(userUid).set({
        ...clienteData,
        'ultimaAtualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Dados do cliente salvos no Firestore do app
    } catch (e) {
      // Erro ao salvar cliente no app
      rethrow;
    }
  }

  /// Salva informações básicas do cliente no SharedPreferences para acesso offline
  Future<void> _salvarDadosLocalmente(Map<String, dynamic> clienteData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Salva informações básicas do cliente
      await prefs.setString('clienteNome', clienteData['nome'] ?? '');
      await prefs.setString('clienteCpf', clienteData['cpfCnpj'] ?? '');
      await prefs.setString('clienteTelefone', clienteData['telefone'] ?? '');
      await prefs.setString('clienteEmail', clienteData['email'] ?? '');

      // Se houver mais campos que você deseja salvar localmente, adicione aqui

      // Dados do cliente salvos localmente via SharedPreferences
    } catch (e) {
      // Erro ao salvar dados localmente
      // Não relança a exceção para não interromper o fluxo principal
    }
  }

  /// Sincroniza as Ordens de Serviço do cliente do painel-agrogeo para o app
  ///
  /// Parâmetros:
  /// - [cpfClientePainel]: CPF do cliente no painel (sem formatação)
  ///
  /// Retorna um mapa com o resultado da sincronização
  Future<Map<String, dynamic>> sincronizarOrdensServico(
      String cpfClientePainel) async {
    try {
      // Obtém o UID do usuário autenticado
      final String? userUid = _auth.currentUser?.uid;

      if (userUid == null) {
        throw Exception('Usuário não autenticado');
      }

      // Chama a Cloud Function syncOrdensServicoDoPainel
      final HttpsCallable callable =
          _functions.httpsCallable('syncOrdensServicoDoPainel');
      final result = await callable.call<Map<String, dynamic>>({
        'cpfClientePainel': cpfClientePainel,
        'userUidApp': userUid,
      });

      final responseData = result.data;

      // Sincronização de OS concluída
      return responseData;
    } catch (e) {
      // Erro ao sincronizar Ordens de Serviço
      rethrow;
    }
  }

  /// Sincroniza as etapas e os arquivos de uma Ordem de Serviço específica
  ///
  /// Parâmetros:
  /// - [osId]: ID da Ordem de Serviço (mesmo ID no painel e no app)
  ///
  /// Retorna um mapa com o resultado da sincronização
  Future<Map<String, dynamic>> sincronizarEtapasEArquivos(String osId) async {
    try {
      // Obtém o UID do usuário autenticado
      final String? userUid = _auth.currentUser?.uid;

      if (userUid == null) {
        throw Exception('Usuário não autenticado');
      }

      // Chama a Cloud Function syncEtapasEArquivosDaOs
      final HttpsCallable callable =
          _functions.httpsCallable('syncEtapasEArquivosDaOs');
      final result = await callable.call<Map<String, dynamic>>({
        'osIdPainel': osId,
        'osIdApp': osId, // Geralmente são o mesmo ID
        'userUidApp': userUid,
      });

      final responseData = result.data;

      // Sincronização de etapas/arquivos concluída
      return responseData;
    } catch (e) {
      // Erro ao sincronizar etapas e arquivos
      rethrow;
    }
  }

  /// Fluxo completo de sincronização após o login
  ///
  /// Parâmetros:
  /// - [cpf]: CPF do cliente (sem formatação)
  ///
  /// Executa a busca do cliente e a sincronização das Ordens de Serviço
  Future<bool> sincronizarDadosAposLogin(String cpf) async {
    try {
      // 1. Busca os dados do cliente
      final clienteData = await buscarClientePorCpf(cpf);

      if (clienteData == null) {
        // Não foi possível sincronizar: cliente não encontrado
        return false;
      }

      // 2. Sincroniza as Ordens de Serviço
      await sincronizarOrdensServico(cpf);

      return true;
    } catch (e) {
      // Erro no fluxo de sincronização após login
      return false;
    }
  }

  /// Método utilitário para construir URLs corretas para o Firebase Storage
  ///
  /// Este método garante que todas as URLs do Storage usem o domínio correto
  ///
  /// Parâmetros:
  /// - [path]: Caminho do arquivo no Storage (sem o domínio)
  /// - [alt]: Parâmetro alt para a URL (geralmente "media" para download)
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
}

/// Exemplos de uso do FirebaseSyncService nas telas do aplicativo:

/*
// 1. No login ou primeiro acesso:
// ==============================

// Em primeiro_acesso.dart ou login_page.dart:
final syncService = FirebaseSyncService();

// Após autenticar o usuário com Firebase Auth:
void _onLoginSuccess() async {
  final cpf = _cpfController.text.replaceAll(RegExp(r'[^\d]'), ''); // Remove formatação
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final sincronizado = await syncService.sincronizarDadosAposLogin(cpf);
    
    if (sincronizado) {
      // Navega para a tela principal
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Exibe mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível sincronizar os dados. Tente novamente.')),
      );
    }
  } catch (e) {
    // Trata o erro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao sincronizar: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// 2. Ao abrir uma Ordem de Serviço específica:
// ===========================================

// Em os_detalhes_etapas_page.dart:
final syncService = FirebaseSyncService();

@override
void initState() {
  super.initState();
  _sincronizarEtapas();
}

Future<void> _sincronizarEtapas() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    await syncService.sincronizarEtapasEArquivos(widget.osId);
    // Após sincronizar, os dados já estarão no Firestore local
    // e serão exibidos pelo StreamBuilder que observa a coleção de etapas
  } catch (e) {
    // Trata o erro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao sincronizar etapas: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// 3. Botão de atualização manual (opcional):
// ========================================

// Em qualquer tela que liste Ordens de Serviço:
ElevatedButton(
  onPressed: () async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Obtém o CPF do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cpf = prefs.getString('clienteCpf') ?? '';
      
      if (cpf.isEmpty) {
        throw Exception('CPF não encontrado');
      }
      
      await syncService.sincronizarOrdensServico(cpf);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ordens de Serviço atualizadas com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e')),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  },
  child: Text('Atualizar Ordens de Serviço'),
)

// 4. Exemplo de como usar o método buildStorageUrl para construir URLs corretas:
// ===========================================================================

// Em qualquer lugar onde você precise construir uma URL para o Firebase Storage:
String caminhoArquivo = "clientes/LUIS FERNANDO CORREA BRITO/fazendas/teste 02/DECLARAÇÃO DE POSSE 04-05-2025/etapas/arquivo.pdf";
String urlCorreta = FirebaseSyncService.buildStorageUrl(caminhoArquivo);

// Agora você pode usar esta URL para download ou exibição de arquivos
// Por exemplo, com um widget Image para exibir uma imagem:
Image.network(
  FirebaseSyncService.buildStorageUrl("caminho/para/imagem.jpg"),
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return Center(child: CircularProgressIndicator());
  },
  errorBuilder: (context, error, stackTrace) {
    return Text('Erro ao carregar imagem');
  },
)
*/
