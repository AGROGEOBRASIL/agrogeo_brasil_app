import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Corrigido: firebase_functions → cloud_functions
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _appFirestore =
      FirebaseFirestore.instance; // App: agrogeo-brasil-app
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
      region: 'southamerica-east1'); // Especifique sua região

  // Chaves para SharedPreferences
  static const String _userIdKey = "userId";
  static const String _userCpfKey = "userCPF";
  static const String _clienteNomeKey = "clienteNome";
  static const String _clienteTelefoneKey = "clienteTelefone";
  // Adicione outras chaves conforme necessário

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<User?> signInWithCpfAndPassword(String cpf, String password) async {
    try {
      final String sanitizedCpf = cpf.trim();
      final String email = '$sanitizedCpf@agrogeo.app'; // Convenção de email

      // Passo 1: Chamar Cloud Function para buscar dados do cliente no painel-agrogeo
      // Chamando Cloud Function getClientByCpf
      final HttpsCallable callable = _functions.httpsCallable('getClientByCpf');
      final HttpsCallableResult<Map<String, dynamic>> result =
          await callable.call<Map<String, dynamic>>({
        'cpf': sanitizedCpf,
      });

      if (result.data.isEmpty) {
        // Cliente não encontrado no painel
        throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Cliente não encontrado no sistema do painel.');
      }

      final Map<String, dynamic> clientDataFromPanel =
          Map<String, dynamic>.from(result.data);
      // Dados recebidos do painel

      // Passo 2: Autenticar ou criar usuário no Firebase Auth do agrogeo-brasil-app
      UserCredential userCredential;
      try {
        // Tentando login
        userCredential = await _firebaseAuth.signInWithEmailAndPassword(
            email: email, password: password);
        // Login bem-sucedido
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Usuário não encontrado, tentando criar usuário
          userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
              email: email, password: password);
          // Usuário criado com sucesso
        } else {
          // Erro no Firebase Auth
          rethrow;
        }
      }

      User? user = userCredential.user;
      if (user != null) {
        // Passo 3: Salvar/Atualizar dados do cliente no Firestore do agrogeo-brasil-app
        // Salvando dados do cliente no Firestore do app
        await _appFirestore
            .collection('clientes')
            .doc(user.uid)
            .set(clientDataFromPanel, SetOptions(merge: true));
        // Dados do cliente salvos no Firestore do app

        // Passo 4: Salvar dados relevantes no SharedPreferences
        await _saveUserDataToPrefs(clientDataFromPanel, user.uid);
        // Dados do cliente salvos no SharedPreferences
        return user;
      }
      return null;
    } on FirebaseFunctionsException catch (functionError) {
      // Erro na Cloud Function
      // Mapear erros da Cloud Function para FirebaseAuthException ou uma exceção customizada
      if (functionError.code == 'not-found') {
        throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Cliente não encontrado no sistema do painel (via CF).');
      } else if (functionError.code == 'invalid-argument') {
        throw Exception('CPF inválido ou não fornecido.');
      }
      throw Exception(
          'Erro ao comunicar com o servidor de dados do cliente: ${functionError.message}');
    } catch (e) {
      // Erro inesperado
      throw Exception('Ocorreu um erro inesperado durante o login.');
    }
  }

  Future<void> _saveUserDataToPrefs(
      Map<String, dynamic> userData, String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, uid);
    // Use os nomes de campo corretos que vêm da sua coleção 'clientes' no painel
    await prefs.setString(
        _userCpfKey, userData['cpfCnpj'] ?? userData['cpf'] ?? '');
    await prefs.setString(
        _clienteNomeKey, userData['nome'] ?? userData['razaoSocial'] ?? '');
    await prefs.setString(
        _clienteTelefoneKey, userData['telefone'] ?? userData['celular'] ?? '');
    // Salve outros campos relevantes que você precisa para acesso rápido
    // Ex: await prefs.setString('clienteEmail', userData['email'] ?? '');
  }

  // Método para carregar dados do usuário do SharedPreferences (exemplo)
  Future<Map<String, String?>> getLocalUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userIdKey),
      'cpf': prefs.getString(_userCpfKey),
      'nome': prefs.getString(_clienteNomeKey),
      'telefone': prefs.getString(_clienteTelefoneKey),
    };
  }

  // Listener para dados do cliente no Firestore do app (agrogeo-brasil-app)
  Stream<DocumentSnapshot?> getClienteStream(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _appFirestore.collection('clientes').doc(userId).snapshots();
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      // Limpar SharedPreferences ao sair
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userCpfKey);
      await prefs.remove(_clienteNomeKey);
      await prefs.remove(_clienteTelefoneKey);
      // Limpe outras chaves relevantes
      // Usuário deslogado e SharedPreferences limpos
    } catch (e) {
      // Erro ao fazer signOut
      throw Exception('Erro ao tentar sair da conta.');
    }
  }

  // O método signUpWithCpfAndPassword original pode não ser necessário se o fluxo
  // sempre envolve buscar um cliente existente no painel. Se for necessário um cadastro
  // que não dependa do painel, ele precisaria de uma lógica diferente.
  // Por ora, comentei-o, pois o fluxo principal é signInWithCpfAndPassword que já lida com a criação do usuário no Auth.
  /*
  Future<UserCredential?> signUpWithCpfAndPassword(
      String cpf, String password) async {
    try {
      final String email = '${cpf.trim()}@agrogeo.app';
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      // ATENÇÃO: Este fluxo de signup não busca dados do painel.
      // Se um novo usuário se cadastra aqui, ele não terá dados do painel sincronizados
      // a menos que você adicione essa lógica ou tenha um fluxo separado.
      // Considere se este método é realmente necessário ou se o signInWithCpfAndPassword
      // (que já cria o usuário no Auth se não existir) é suficiente.
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception('An unexpected error occurred during sign up.');
    }
  }
  */
}
