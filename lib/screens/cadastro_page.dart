import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  String _formatCPF(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digitsOnly[i]);
    }
    return buffer.toString();
  }

  bool _validarCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}\$').hasMatch(cpf))
      return false;
    List<int> numbers = cpf.split('').map(int.parse).toList();
    for (int i = 9; i < 11; i++) {
      int sum = 0;
      for (int j = 0; j < i; j++) {
        sum += numbers[j] * ((i + 1) - j);
      }
      int digit = (sum * 10) % 11;
      if (digit == 10) digit = 0;
      if (digit != numbers[i]) return false;
    }
    return true;
  }

  void _cadastrar() {
    final cpf = _cpfController.text;
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (!_validarCPF(cpf)) {
      _showDialog('CPF inválido', 'Digite um CPF válido.');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showDialog('E-mail inválido', 'Digite um e-mail válido.');
      return;
    }

    if (senha.length < 6) {
      _showDialog('Senha inválida', 'A senha deve ter no mínimo 6 caracteres.');
      return;
    }

    // TODO: Enviar dados para Firestore
    print("Usuário cadastrado: CPF=$cpf, Email=$email");
    _showDialog(
        'Cadastro realizado', 'Seu cadastro foi realizado com sucesso.');
  }

  void _showDialog(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return TextEditingValue(
                      text: _formatCPF(newValue.text),
                      selection: TextSelection.collapsed(
                        offset: _formatCPF(newValue.text).length,
                      ),
                    );
                  }),
                ],
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _cadastrar,
                  child: const Text('Cadastrar'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
