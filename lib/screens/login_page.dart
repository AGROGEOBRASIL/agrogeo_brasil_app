import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
// Removido import não utilizado: import 'package:url_launcher/url_launcher.dart';

// Importe as suas páginas reais
import 'painel_page.dart';
import 'primeiro_acesso_page.dart';
import 'recuperar_senha_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _passwordController.dispose();
    super.dispose();
  }

  // CORREÇÃO: Função para obter CPF sem máscara
  String _getUnmaskedCpf() {
    return _cpfMaskFormatter.getUnmaskedText();
  }

  // CORREÇÃO: Função para buscar dados do cliente (incluindo email e ID do documento) pelo CPF SEM MÁSCARA no campo 'cpfCnpj'
  Future<Map<String, dynamic>?> _getClientDataByUnmaskedCpf(
      String unmaskedCpf) async {
    // Verificando cliente com CPF (sem máscara)
    if (unmaskedCpf.isEmpty) {
      // CPF sem máscara está vazio
      return null;
    }
    try {
      // Busca na coleção 'clientes' pelo campo 'cpfCnpj'
      final querySnapshot = await _firestore
          .collection('clientes')
          .where('cpfCnpj',
              isEqualTo: unmaskedCpf) // <-- CORRIGIDO: Campo e valor
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final clientDoc = querySnapshot.docs.first;
        // Cliente encontrado
        // Retorna o email, nome e o ID do documento
        return {
          'email': clientDoc.data()['email'] as String?,
          'nome': clientDoc.data()['nome'] as String?,
          'docId': clientDoc.id, // ID aleatório do documento
        };
      }
      // Nenhum cliente encontrado com o CPF no campo 'cpfCnpj'
      return null;
    } catch (e) {
      // Erro ao buscar dados do cliente pelo CPF
      return null;
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    // CORREÇÃO: Obter CPF SEM máscara para a busca no Firestore
    final unmaskedCpf = _getUnmaskedCpf();
    final password = _passwordController.text;
    // Iniciando login para CPF (sem máscara)

    try {
      // 1. Buscar dados do cliente (incluindo email) pelo CPF SEM MÁSCARA no campo 'cpfCnpj'
      final clientData = await _getClientDataByUnmaskedCpf(unmaskedCpf);

      if (clientData == null || clientData['email'] == null) {
        // CPF não encontrado ou sem email associado
        _handleLoginError('CPF não encontrado ou não associado a um email.');
        return;
      }

      final email = clientData['email'] as String;
      final clientName = clientData['nome'] as String? ?? 'Cliente';
      final clientDocId =
          clientData['docId'] as String; // ID do documento Firestore
      // Cliente encontrado. Tentando autenticar no Auth...

      // 2. Tentar autenticar com Firebase Auth usando o email encontrado
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Autenticação no Auth bem-sucedida

      // 3. Se autenticado, salvar dados localmente (ID do documento e nome)
      // Salvando dados localmente (SharedPreferences)...
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'clienteDocId', clientDocId); // Salva o ID do Documento
      await prefs.setString('clienteNome', clientName);
      // Dados salvos. Navegando para o Painel...

      // 4. Navegar para o painel
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PainelPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'CPF ou senha inválidos.';
      } else if (e.code == 'invalid-email') {
        message = 'Erro interno: formato de email inválido associado ao CPF.';
      } else {
        message = 'Ocorreu um erro no login. Tente novamente.';
        // FirebaseAuthException: ${e.code} - ${e.message}
      }
      _handleLoginError(message);
    } catch (e) {
      // Erro inesperado no login
      _handleLoginError('Ocorreu um erro inesperado. Tente novamente.');
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleLoginError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar(message);
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

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecuperarSenhaPage()),
    );
  }

  void _goToFirstAccess() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrimeiroAcessoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4CAF50);
    const secondaryColor = Color(0xFFFFEB3B);
    const backgroundColor = Color(0xFFE8F5E9);
    const textColor = Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
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
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.2),
                      children: [
                        TextSpan(
                            text: 'AGROGEO\n',
                            style: TextStyle(color: primaryColor)),
                        TextSpan(
                            text: 'BRASIL',
                            style: TextStyle(color: secondaryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Entre em sua conta da AGROGEO',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textColor),
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
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: primaryColor),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe sua senha.';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter no mínimo 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : _goToForgotPassword,
                        child: const Text('Esqueci minha senha',
                            style: TextStyle(color: primaryColor)),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _goToFirstAccess,
                        child: const Text('Primeiro acesso',
                            style: TextStyle(color: primaryColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor))
                      : ElevatedButton(
                          onPressed: _signIn,
                          child: const Text('Entrar'),
                        ),
                  const SizedBox(height: 32),
                  const Text(
                    'v1.0.0', // Atualize conforme necessário
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seu CPF deve estar vinculado a um cliente existente.\nSe tiver dúvidas, entre em contato conosco.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
