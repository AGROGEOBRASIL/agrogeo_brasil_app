// lib/screens/fazenda_departamentos_page.dart
import 'package:flutter/material.dart';
import 'ordens_servico_departamento_page.dart'; // Importa a tela de lista de OS

class FazendaDepartamentosPage extends StatelessWidget {
  final String nomeCliente;
  final String nomeFazenda;

  const FazendaDepartamentosPage({
    super.key,
    required this.nomeCliente,
    required this.nomeFazenda,
  });

  // Função para navegar para a lista de OS filtrada
  void _navegarParaListaOS(BuildContext context, String departamento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdensServicoDepartamentoPage(
          nomeCliente: nomeCliente,
          nomeFazenda: nomeFazenda,
          departamento: departamento,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cores baseadas na imagem
    const Color agrogeoGreen = Color(0xFF388E3C); // Verde escuro
    const Color brasilYellow = Color(0xFFFFD600); // Amarelo
    const Color backgroundGradientStart = Color(0xFFFFFFFF); // Branco (topo)
    const Color backgroundGradientEnd =
        Color(0xFFE8F5E9); // Verde muito claro (base)
    // Removida variável não utilizada buttonTextColor

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Fundo transparente para o gradiente
        elevation: 0,
        title: RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
            children: [
              TextSpan(
                  text: 'AGROGEO\n', style: TextStyle(color: agrogeoGreen)),
              TextSpan(text: 'BRASIL', style: TextStyle(color: brasilYellow)),
            ],
          ),
        ),
        centerTitle: true,
        iconTheme:
            const IconThemeData(color: agrogeoGreen), // Cor do botão voltar
      ),
      extendBodyBehindAppBar:
          true, // Permite que o gradiente fique atrás da AppBar
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundGradientStart, backgroundGradientEnd],
            stops: [0.0, 0.7], // Ajuste para o gradiente
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment
                  .center, // Centraliza os botões verticalmente
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20), // Espaço após AppBar
                Text(
                  nomeFazenda, // Nome da fazenda recebido
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: agrogeoGreen,
                  ),
                ),
                const SizedBox(height: 40), // Espaço antes dos botões

                // Botão Ambiental
                _buildDepartmentButton(
                  context,
                  icon: Icons.eco, // Ícone de folha
                  text: 'Ambiental',
                  onPressed: () => _navegarParaListaOS(context, 'Ambiental'),
                ),
                const SizedBox(height: 20),

                // Botão Fundiário
                _buildDepartmentButton(
                  context,
                  icon: Icons.warning_amber_rounded, // Ícone de aviso
                  text: 'Fundiário',
                  onPressed: () => _navegarParaListaOS(context, 'Fundiário'),
                ),
                const SizedBox(height: 20),

                // Botão Fiscal e Jurídico
                _buildDepartmentButton(
                  context,
                  icon: Icons.assignment, // Ícone de documento/ITR
                  text: 'Fiscal e Jurídico',
                  onPressed: () =>
                      _navegarParaListaOS(context, 'Fiscal e Jurídico'),
                ),
                const SizedBox(height: 20),

                // Botão Bancos
                _buildDepartmentButton(
                  context,
                  icon: Icons.account_balance, // Ícone de banco
                  text: 'Bancos',
                  onPressed: () => _navegarParaListaOS(context, 'Bancos'),
                ),
                const Spacer(), // Empurra para baixo se houver espaço
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para criar os botões de departamento
  Widget _buildDepartmentButton(BuildContext context,
      {required IconData icon,
      required String text,
      required VoidCallback onPressed}) {
    const Color agrogeoGreen = Color(0xFF388E3C);
    const Color buttonTextColor = Colors.white;

    return ElevatedButton.icon(
      icon: Icon(icon, color: buttonTextColor, size: 28),
      label: Text(
        text,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: buttonTextColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: agrogeoGreen,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12), // Bordas levemente arredondadas
        ),
        elevation: 4,
        // Mantido withOpacity para compatibilidade com a versão do Flutter do usuário
        // Alternativa seria usar Color.fromRGBO(0, 0, 0, 0.3) se compatível
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed: onPressed,
    );
  }
}
