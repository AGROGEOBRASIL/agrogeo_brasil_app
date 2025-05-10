import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importe as suas páginas reais
import 'painel_page.dart';

class PrimeiroAcessoPage extends StatefulWidget {
  const PrimeiroAcessoPage({super.key});

  @override
  State<PrimeiroAcessoPage> createState() => _PrimeiroAcessoPageState();
}

class _PrimeiroAcessoPageState extends State<PrimeiroAcessoPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void dispose() {
    _cpfController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // CORREÇÃO: Função para obter CPF sem máscara
  String _getUnmaskedCpf() {
    return _cpfMaskFormatter.getUnmaskedText();
  }

  // CORREÇÃO: Função para verificar se o CPF SEM MÁSCARA existe no campo 'cpfCnpj'
  Future<Map<String, dynamic>?> _checkIfClientExists(String unmaskedCpf) async {
    print(
        "PrimeiroAcesso: Verificando cliente com CPF (sem máscara): $unmaskedCpf");
    if (unmaskedCpf.isEmpty) {
      print("PrimeiroAcesso: CPF sem máscara está vazio.");
      return null;
    }
    try {
      final querySnapshot = await _firestore
          .collection('clientes')
          .where('cpfCnpj',
              isEqualTo: unmaskedCpf) // <-- CORRIGIDO: Campo e valor
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final clientDoc = querySnapshot.docs.first;
        print("PrimeiroAcesso: Cliente encontrado! Doc ID: ${clientDoc.id}");
        return {
          'docId': clientDoc.id,
          'nome': clientDoc.data()['nome'] as String? ?? 'Cliente',
        };
      }
      print(
          "PrimeiroAcesso: Nenhum cliente encontrado com o CPF $unmaskedCpf no campo 'cpfCnpj'.");
      return null;
    } catch (e) {
      print("PrimeiroAcesso: Erro ao verificar cliente: $e");
      return null;
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    // CORREÇÃO: Obter CPF sem máscara para a verificação
    final unmaskedCpf = _getUnmaskedCpf();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    print(
        "PrimeiroAcesso: Iniciando registro para CPF (sem máscara): $unmaskedCpf, Email: $email");

    try {
      // 1. Verificar se o CPF (sem máscara) existe na coleção 'clientes' usando o campo 'cpfCnpj'
      final clientData = await _checkIfClientExists(unmaskedCpf);

      if (clientData == null) {
        // CPF não encontrado no Firestore
        print(
            "PrimeiroAcesso: CPF não encontrado no Firestore, mostrando diálogo de contato.");
        _showContactSupportDialog();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // CPF encontrado, prosseguir com a criação no Firebase Auth
      final clientDocId = clientData['docId'] as String;
      final clientName = clientData['nome'] as String;
      print(
          "PrimeiroAcesso: CPF encontrado (Doc ID: $clientDocId). Tentando criar usuário no Auth...");

      // 2. Tentar criar usuário no Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print(
          "PrimeiroAcesso: Usuário criado no Auth com UID: ${userCredential.user?.uid}");

      // 3. (Opcional mas recomendado) Atualizar documento do cliente com o UID do Auth
      try {
        print(
            "PrimeiroAcesso: Atualizando documento do cliente $clientDocId com Auth UID...");
        await _firestore.collection('clientes').doc(clientDocId).update({
          'authUid': userCredential.user?.uid,
          // Pode adicionar/atualizar o email aqui também se necessário
          'email': email, // Atualiza o email no Firestore também
        });
        print("PrimeiroAcesso: Documento do cliente atualizado.");
      } catch (updateError) {
        print(
            "PrimeiroAcesso: Erro ao atualizar cliente com Auth UID: $updateError");
        // Considerar se deve parar o fluxo ou apenas logar o erro
      }

      // 4. Salvar dados localmente (ID do documento e nome)
      print("PrimeiroAcesso: Salvando dados localmente (SharedPreferences)...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('clienteDocId', clientDocId);
      await prefs.setString('clienteNome', clientName);
      print("PrimeiroAcesso: Dados salvos. Navegando para o Painel...");

      // 5. Navegar para o Painel
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PainelPage()),
          (Route<dynamic> route) => false, // Remove todas as rotas anteriores
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Já existe uma conta para este email.';
      } else if (e.code == 'invalid-email') {
        message = 'O formato do email é inválido.';
      } else {
        message = 'Ocorreu um erro durante o cadastro.';
        print(
            'PrimeiroAcesso: FirebaseAuthException on Register: ${e.code} - ${e.message}');
      }
      _showErrorSnackbar(message);
    } catch (e) {
      print('PrimeiroAcesso: Erro inesperado no cadastro: $e');
      _showErrorSnackbar('Ocorreu um erro inesperado. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showContactSupportDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cadastro incompleto'),
        content: const Text(
            'Seu CPF ainda não está vinculado a nenhum cliente AGROGEO.\n\nClique no botão abaixo para entrar em contato conosco.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final Uri whatsappUri = Uri.parse(
                  'https://wa.me/5593984144452'); // Substitua pelo número correto se necessário
              if (await canLaunchUrl(whatsappUri)) {
                await launchUrl(whatsappUri,
                    mode: LaunchMode.externalApplication);
              } else {
                _showErrorSnackbar('Não foi possível abrir o WhatsApp.');
              }
            },
            child: const Text('Falar com AGROGEO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4CAF50);
    const backgroundColor = Color(0xFFE8F5E9);
    const textColor = Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Primeiro Acesso / Cadastro'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Preencha os dados para criar seu acesso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        color: textColor,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _cpfController,
                    decoration: InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      prefixIcon:
                          const Icon(Icons.person_outline, color: primaryColor),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cpfMaskFormatter],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe seu CPF.';
                      }
                      if (value.length != 14) {
                        return 'CPF inválido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon:
                          const Icon(Icons.email_outlined, color: primaryColor),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe seu email.';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                        return 'Por favor, informe um email válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: primaryColor),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe uma senha.';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter no mínimo 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: primaryColor),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, confirme sua senha.';
                      }
                      if (value != _passwordController.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor))
                      : ElevatedButton(
                          onPressed: _register,
                          child: const Text('Criar Acesso'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
