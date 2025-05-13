// lib/screens/departamentos_os_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import da nova tela que listará as OS de um departamento
import 'ordens_servico_departamento_page.dart';

class DepartamentosOsPage extends StatefulWidget {
  final String nomeCliente;
  final String nomeFazenda;

  const DepartamentosOsPage({
    super.key,
    required this.nomeCliente,
    required this.nomeFazenda,
  });

  @override
  State<DepartamentosOsPage> createState() => _DepartamentosOsPageState();
}

class _DepartamentosOsPageState extends State<DepartamentosOsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper para obter ícone baseado no departamento
  IconData _getIconForDepartamento(String departamento) {
    switch (departamento.toLowerCase()) {
      case 'ambiental':
        return Icons.eco; // Folha
      case 'fundiário':
        return Icons.warning_amber_rounded; // Alerta (ou Icons.map)
      case 'fiscal e jurídico':
        return Icons.gavel; // Martelo (ou Icons.description para ITR)
      case 'bancos':
        return Icons.account_balance; // Banco
      default:
        return Icons.folder_special; // Pasta genérica
    }
  }

  // Função para navegar para a lista de OS do departamento
  void _navegarParaOrdensDepartamento(String departamento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdensServicoDepartamentoPage(
          nomeCliente: widget.nomeCliente,
          nomeFazenda: widget.nomeFazenda,
          departamento: departamento,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OS - ${widget.nomeFazenda}'),
        backgroundColor: Colors.green[700],
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('ordensServico') // Coleção raiz de OS
            .where('cliente', isEqualTo: widget.nomeCliente)
            .where('fazenda', isEqualTo: widget.nomeFazenda)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                  'Erro ao carregar Ordens de Serviço: ${snapshot.error}',
                  style: TextStyle(color: Colors.red)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                  'Nenhuma Ordem de Serviço encontrada para esta fazenda.'),
            );
          }

          // Agrupa as ordens por departamento
          final ordens = snapshot.data!.docs;
          final Map<String, List<DocumentSnapshot>> ordensPorDepartamento = {};

          for (var doc in ordens) {
            final data = doc.data() as Map<String, dynamic>?;
            final departamento = data?['departamentoRelacionado'] as String? ??
                'Não Classificado';
            if (ordensPorDepartamento.containsKey(departamento)) {
              ordensPorDepartamento[departamento]!.add(doc);
            } else {
              ordensPorDepartamento[departamento] = [doc];
            }
          }

          // Ordena os departamentos (opcional, pode definir uma ordem específica)
          final departamentosOrdenados = ordensPorDepartamento.keys.toList()
            ..sort();

          // Constrói a lista de botões de departamento
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: departamentosOrdenados.length,
            itemBuilder: (context, index) {
              final departamento = departamentosOrdenados[index];
              final ordensDoDepartamento = ordensPorDepartamento[departamento]!;
              final count = ordensDoDepartamento.length;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Material(
                  color: Colors.green[600], // Cor de fundo do botão
                  borderRadius: BorderRadius.circular(
                      12), // Bordas levemente arredondadas
                  elevation: 3.0,
                  shadowColor: Colors.black.withOpacity(0.2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    // MODIFICADO: onTap agora chama a função de navegação
                    onTap: () => _navegarParaOrdensDepartamento(departamento),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(_getIconForDepartamento(departamento),
                              color: Colors.white, size: 30),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              departamento,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Badge com a contagem
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
