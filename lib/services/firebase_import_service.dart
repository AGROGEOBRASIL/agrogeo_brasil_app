import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:http/http.dart' as http; // Para chamadas HTTP à Cloud Function
// import 'dart:convert'; // Para jsonEncode e jsonDecode

class FirebaseImportService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatarCpfParaEmail(String cpf) {
    return '${cpf.replaceAll(RegExp(r'[.-]'), '')}@agrogeo.app';
  }

  Future<bool> verificarClienteExistenteAppAtualPorCPF(String cpf) async {
    try {
      // Tenta buscar pelo e-mail formatado, que é a chave de login
      String email = _formatarCpfParaEmail(cpf);
      // Firebase Auth não tem um método direto para verificar se um email existe sem tentar criar/logar.
      // Uma abordagem comum é verificar se há um documento no Firestore associado a esse CPF/email.
      // Ou, se o objetivo é apenas verificar se o usuário já existe no Auth do app atual antes de importar,
      // a lógica de criação de usuário já lidaria com isso (lançaria exceção se já existir).
      // Para este contexto, vamos verificar na coleção 'clientes' do app atual.
      final querySnapshot = await _firestore
          .collection('clientes')
          .where('cpf',
              isEqualTo:
                  cpf) // Supondo que você armazena o CPF original no documento
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar cliente existente no app atual: $e');
      return false; // Considera que não existe em caso de erro, para permitir fluxo de importação
    }
  }

  // Retorna os dados do cliente ou null se não encontrado/erro
  Future<Map<String, dynamic>?> buscarDadosClientePainelAgrogeo(
      String cpf) async {
    // ========================== IMPORTANTE ==========================
    // ESTA FUNÇÃO É UM PLACEHOLDER.
    // A busca de dados no Firestore 'painel-agrogeo' DEVE ser feita
    // através de uma Cloud Function segura nesse projeto Firebase.
    // O app Flutter (agrogeo-brasil-app) chamaria essa Cloud Function.
    // Exemplo de chamada (requer 'http' e configuração da Cloud Function):
    /*
    try {
      // Substitua pela URL da sua Cloud Function
      final url = Uri.parse('URL_DA_SUA_CLOUD_FUNCTION_BUSCAR_CLIENTE?cpf=$cpf');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['exists'] == true) {
          return Map<String, dynamic>.from(data['clienteData']);
        }
        return null; // Cliente não encontrado no painel-agrogeo
      } else {
        print('Erro ao buscar dados no painel-agrogeo: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar dados no painel-agrogeo: $e');
      return null;
    }
    */
    // ================================================================

    // Placeholder: Simula a busca e o retorno dos dados do cliente.
    // No cenário real, esta lógica estaria na Cloud Function.
    // O script main.dart fornecido usa Admin SDK, que é para backend.
    print(
        'Simulando busca de dados para o CPF: $cpf no painel-agrogeo (usar Cloud Function)');
    // Se você tiver uma forma de testar a lógica do main.dart (ex: rodando localmente com credenciais),
    // você pode adaptar a resposta aqui para simular um cliente encontrado ou não.
    // Por agora, vamos simular que o cliente foi encontrado se o CPF for '12345678900'
    if (cpf == '12345678900') {
      // CPF de exemplo para simular cliente encontrado
      return {
        'nome': 'Cliente Exemplo Painel',
        'cpf': cpf, // CPF original com formatação
        'email_contato':
            'cliente.exemplo@email.com', // Email de contato, não o de login
        // ... outros campos relevantes do cliente vindos do painel-agrogeo
        'endereco': 'Rua Exemplo, 123',
        'cidade': 'Exemplópolis',
        'estado': 'EX',
        'telefone': '(00) 91234-5678',
      };
    }
    return null; // Cliente não encontrado no painel-agrogeo
  }

  // Retorna o UserCredential se sucesso, null caso contrário
  Future<UserCredential?> importarClienteParaAppAtual(
      String cpf, Map<String, dynamic> dadosCliente, String senha) async {
    String email = _formatarCpfParaEmail(cpf);

    try {
      // 1. Criar usuário no Firebase Auth do app atual (agrogeo-brasil-app)
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha, // A senha informada pelo usuário no primeiro acesso
      );
      print('Usuário criado no Auth para: $email');

      // 2. Salvar os mesmos dados do cliente na coleção 'clientes' do projeto atual
      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        Map<String, dynamic> dadosParaSalvar = {
          ...dadosCliente, // Copia todos os dados vindos do painel-agrogeo
          'uid': uid, // Adiciona o UID do Auth
          'email_login': email, // Adiciona o email de login
          'cpf':
              cpf, // Garante que o CPF original (com formatação) esteja salvo
          'data_importacao': FieldValue.serverTimestamp(),
        };

        // Remove campos que não devem ser duplicados ou que são específicos do painel
        // Ex: se 'email' já existe em dadosCliente e é diferente do email_login
        // dadosParaSalvar.remove('algumCampoEspecificoDoPainel');

        await _firestore.collection('clientes').doc(uid).set(dadosParaSalvar);
        print(
            'Dados do cliente salvos no Firestore do app atual para UID: $uid');
        return userCredential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('Erro: O email $email já está em uso no Auth do app atual.');
        // Isso não deveria acontecer se verificarClienteExistenteAppAtualPorCPF funcionar corretamente
        // ou se a lógica de fluxo garantir que só se importe quem não existe.
      } else if (e.code == 'weak-password') {
        print('Erro: A senha fornecida é muito fraca.');
      } else {
        print(
            'Erro FirebaseAuth ao importar cliente: ${e.message} (código: ${e.code})');
      }
      return null;
    } catch (e) {
      print('Erro geral ao importar cliente para o app atual: $e');
      return null;
    }
  }
}
