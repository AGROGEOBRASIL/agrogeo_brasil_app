import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Se precisar do Firestore

// Import corrigido para login_page.dart (assumindo que ele está em lib/screens/)
import '../screens/login_page.dart';

// Removido: import 'documentos_cliente.dart'; // Import desnecessário (auto-importação)

class DocumentosCliente extends StatefulWidget {
  final String nomeCliente; // Parâmetro visto na HomePage

  const DocumentosCliente(this.nomeCliente, {super.key});

  @override
  State<DocumentosCliente> createState() => _DocumentosClienteState();
}

class _DocumentosClienteState extends State<DocumentosCliente> {
  // Placeholder para lista de documentos do cliente e estado de carregamento
  List<String> documentos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocumentos();
  }

  Future<void> _loadDocumentos() async {
    // Placeholder: Substitua pela lógica real para carregar os documentos de widget.nomeCliente
    // Exemplo:
    /*
    try {
      // Lógica para buscar documentos do cliente
    } catch (e) {
      print("Erro ao carregar documentos do cliente: $e");
    }
    */
    await Future.delayed(const Duration(seconds: 1)); // Simula carregamento
    if (mounted) {
      setState(() {
        documentos = [
          'Documento_Cliente_1.pdf',
          'RG_Frente.jpg'
        ]; // Dados fictícios
        isLoading = false;
      });
    }
  }

  // Exemplo de função que poderia usar LoginPage (embora não faça sentido aqui, apenas para teste)
  void _goToLogin() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar pode ser tratado pela HomePage
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : documentos.isEmpty
              ? Center(
                  child: Text(
                      'Nenhum documento encontrado para ${widget.nomeCliente}.'))
              : ListView.builder(
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final docName = documentos[index];
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(docName),
                      onTap: () {
                        // Placeholder: Adicione lógica para visualizar/baixar o documento
                        print('Visualizar documento: $docName');
                      },
                    );
                  },
                ),
      // Exemplo de botão usando a importação corrigida (apenas para teste)
      /*
       floatingActionButton: FloatingActionButton(
         onPressed: _goToLogin,
         tooltip: 'Ir para Login (Teste)',
         child: const Icon(Icons.login),
       ),
       */
    );
  }
}
