import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importe suas páginas reais e o novo serviço
import 'painel_page.dart'; // Exemplo, substitua pelo nome real da sua página de painel
import '../services/firebase_import_service.dart'; // Novo serviço de importação

class PrimeiroAcessoPage extends StatefulWidget {
  const PrimeiroAcessoPage({super.key});

  @override
  State<PrimeiroAcessoPage> createState() => _PrimeiroAcessoPageState();
}

class _PrimeiroAcessoPageState extends State<PrimeiroAcessoPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _emailController =
      TextEditingController(); // Email do formulário (contato)
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseImportService _importService =
      FirebaseImportService(); // Instância do serviço de importação

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

  String _getUnmaskedCpf() {
    return _cpfMaskFormatter.getUnmaskedText();
  }

  // Verifica se o cliente (CPF não mascarado) existe no Firestore do APP ATUAL (agrogeo-brasil-app)
  // usando o campo 'cpfCnpj'. Retorna dados do cliente se existir, ou null.
  Future<Map<String, dynamic>?> _checkIfClientExistsInApp(
      String unmaskedCpf) async {
    // Verificando cliente no APP ATUAL com CPF (sem máscara)
    if (unmaskedCpf.isEmpty) {
      // CPF sem máscara está vazio
      return null;
    }
    try {
      final querySnapshot = await _firestore
          .collection('clientes')
          .where('cpfCnpj', isEqualTo: unmaskedCpf)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final clientDoc = querySnapshot.docs.first;
        // Cliente encontrado no App Atual
        return {
          'docId': clientDoc.id,
          'nome': clientDoc.data()['nome'] as String? ?? 'Cliente',
          'authUid': clientDoc.data()['authUid'] as String?,
          // Adicione outros campos se necessário para o fluxo original
        };
      }
      // Nenhum cliente encontrado com o CPF no campo 'cpfCnpj'
      return null; // Cliente NÃO existe no app atual
    } catch (e) {
      // Erro ao verificar cliente
      return null;
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    final unmaskedCpf = _getUnmaskedCpf();
    final emailForm =
        _emailController.text.trim(); // Email de contato do formulário
    final password = _passwordController.text;

    // Iniciando processo para CPF (sem máscara)

    try {
      // Passo 1: Verificar se o cliente JÁ EXISTE no Firestore do app atual (agrogeo-brasil-app)
      final clientDataInApp = await _checkIfClientExistsInApp(unmaskedCpf);

      if (clientDataInApp != null) {
        // Cliente JÁ EXISTE no Firestore do app atual.
        // Não deve importar. Segue fluxo original de tentativa de criação de Auth com o email do FORMULÁRIO.
        // Cliente encontrado no Firestore do app atual. Prosseguindo com criação/vinculação de Auth

        final clientDocId = clientDataInApp['docId'] as String;
        final clientName = clientDataInApp['nome'] as String;

        // Tentar criar usuário no Firebase Auth com o email do formulário
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: emailForm, // Email do formulário
          password: password,
        );
        // Usuário Auth criado/logado para email do formulário

        // Atualizar documento do cliente com o UID do Auth e o email do formulário
        await _firestore.collection('clientes').doc(clientDocId).update({
          'authUid': userCredential.user?.uid,
          'email':
              emailForm, // Atualiza/define o email de contato no Firestore do app
        });
        // Documento do cliente (existente no app) atualizado com Auth UID e email do formulário

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('clienteDocId', clientDocId);
        await prefs.setString('clienteNome', clientName);
        // Dados salvos localmente

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const PainelPage()), // Substitua por sua PainelPage real
            (Route<dynamic> route) => false,
          );
        }
      } else {
        // Cliente NÃO EXISTE no Firestore do app atual.
        // TENTAR IMPORTAÇÃO DO painel-agrogeo.
        // Cliente NÃO encontrado no Firestore do app atual. Tentando importação do painel-agrogeo

        // Passo 2: Buscar dados do cliente no painel-agrogeo (usando o serviço)
        final dadosClientePainel =
            await _importService.buscarDadosClientePainelAgrogeo(unmaskedCpf);

        if (dadosClientePainel != null) {
          // Cliente ENCONTRADO no painel-agrogeo. Proceder com a importação.
          // Cliente encontrado no painel-agrogeo. Tentando importar cliente para o app atual

          UserCredential? importedUserCredential =
              await _importService.importarClienteParaAppAtual(
            unmaskedCpf, // CPF sem máscara, para gerar CPF@agrogeo.app
            dadosClientePainel, // Dados do cliente vindos do painel
            password, // Senha do formulário
          );

          if (importedUserCredential != null &&
              importedUserCredential.user != null) {
            // Importação bem-sucedida

            final clientDocIdInApp = importedUserCredential
                .user!.uid; // UID do Auth é o docId no app
            final clientName =
                dadosClientePainel['nome'] as String? ?? 'Cliente Importado';
            // O email do formulário (_emailController.text) pode ser salvo como um email de contato adicional se desejado.
            // O FirebaseImportService já salva os dados do painel. Se 'email_contato' for um campo importante,
            // e o do formulário for mais recente, pode-se atualizar o doc após a importação.
            // Por ora, mantemos a cópia dos dados do painel + UID, email_login (CPF@agrogeo.app), cpfCnpj.
            // Ex: Se quiser salvar o email do formulário como contato principal:
            // await _firestore.collection('clientes').doc(clientDocIdInApp).update({'email_contato_principal': emailForm});

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('clienteDocId', clientDocIdInApp);
            await prefs.setString('clienteNome', clientName);
            // Dados do cliente importado salvos localmente

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const PainelPage()), // Substitua por sua PainelPage real
                (Route<dynamic> route) => false,
              );
            }
          } else {
            // Falha ao importar cliente do painel para o app atual
            _showErrorSnackbar(
                "Não foi possível importar seus dados. Verifique os dados ou contate o suporte.");
          }
        } else {
          // Cliente NÃO encontrado no painel-agrogeo
          _showContactSupportDialog(); // Mostrar diálogo de contato original
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message =
            'Este CPF ou email já possui um acesso. Tente fazer login ou recuperar sua senha.';
      } else if (e.code == 'invalid-email') {
        message = 'O formato do email fornecido é inválido.';
      } else {
        message = 'Ocorreu um erro durante o cadastro/importação.';
        // FirebaseAuthException: ${e.code} - ${e.message}
      }
      _showErrorSnackbar(message);
    } catch (e) {
      // Erro inesperado
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
            'Seu CPF ainda não está vinculado a nenhum cliente AGROGEO BRASIL.\n\nClique no botão abaixo para entrar em contato conosco.'), // Atualizado para AGROGEO BRASIL
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
            child: const Text(
                'Falar com AGROGEO BRASIL'), // Atualizado para AGROGEO BRASIL
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
                    decoration: const InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      prefixIcon:
                          Icon(Icons.person_outline, color: primaryColor),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cpfMaskFormatter],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe seu CPF.';
                      }
                      // A máscara já garante o formato, mas a validação de tamanho é boa.
                      if (_cpfMaskFormatter.getUnmaskedText().length != 11 &&
                          value.isNotEmpty) {
                        return 'CPF inválido.'; // Verifica se o CPF não mascarado tem 11 dígitos
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email de Contato',
                      prefixIcon:
                          Icon(Icons.email_outlined, color: primaryColor),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe seu email de contato.';
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
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
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
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Senha',
                      prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
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
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: _register,
                          child: const Text('CRIAR ACESSO'),
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
