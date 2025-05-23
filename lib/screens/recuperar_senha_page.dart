import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class RecuperarSenhaPage extends StatefulWidget {
  const RecuperarSenhaPage({super.key});

  @override
  State<RecuperarSenhaPage> createState() => _RecuperarSenhaPageState();
}

class _RecuperarSenhaPageState extends State<RecuperarSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccess = false;
    });

    final email = _emailController.text.trim();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() {
        _message = 'Link para redefinição de senha enviado para $email.';
        _isSuccess = true;
      });
      _showFeedbackSnackbar(_message!, isSuccess: true);
      // Optionally navigate back after a delay or show a success message
      // Future.delayed(Duration(seconds: 3), () => Navigator.of(context).pop());
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      if (e.code == 'user-not-found') {
        errorMsg = 'Nenhuma conta encontrada para este email.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'O formato do email é inválido.';
      } else {
        errorMsg = 'Ocorreu um erro. Tente novamente.';
        // Substituído print por developer.log
        developer.log('SendPasswordReset Error: ${e.code} - ${e.message}',
            name: 'RecuperarSenhaPage');
      }
      setState(() {
        _message = errorMsg;
      });
      _showFeedbackSnackbar(_message!, isSuccess: false);
    } catch (e) {
      // Substituído print por developer.log
      developer.log('Erro inesperado ao enviar email de recuperação: $e',
          name: 'RecuperarSenhaPage');
      setState(() {
        _message = 'Ocorreu um erro inesperado. Tente novamente.';
      });
      _showFeedbackSnackbar(_message!, isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFeedbackSnackbar(String message, {required bool isSuccess}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use colors consistent with LoginPage
    const primaryColor = Color(0xFF4CAF50);
    const backgroundColor = Color(0xFFE8F5E9);
    const textColor = Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
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
                    'Informe o email associado à sua conta para receber o link de redefinição de senha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon:
                          Icon(Icons.email_outlined, color: primaryColor),
                      // Using theme defaults for border, fill color etc.
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, informe seu email.';
                      }
                      // Basic email validation
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Por favor, informe um email válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor))
                      : ElevatedButton(
                          onPressed: _sendPasswordResetEmail,
                          // Using theme default style
                          child: const Text('Enviar Link'),
                        ),
                  // Feedback message area (optional, SnackBar is also used)
                  if (_message != null && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _isSuccess ? Colors.green : Colors.red,
                            fontSize: 14),
                      ),
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
