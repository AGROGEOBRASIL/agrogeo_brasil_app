// lib/screens/departamentos_os_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Adicionado para acesso direto ao Firestore
import '../services/auth_service.dart'; // Ajuste o caminho se necessário

// Import da nova tela que listará as OS de um departamento
import 'ordens_servico_departamento_page.dart'; // Ajuste o caminho se necessário

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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Acesso direto ao Firestore
  late final AuthService _authService;
  String? _cpfCliente;
  bool _isLoadingCpf = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadCpfCliente();
  }

  Future<void> _loadCpfCliente() async {
    try {
      // Busca os dados locais do usuário, que devem incluir o CPF
      final userData = await _authService.getLocalUserData();
      if (mounted) {
        setState(() {
          _cpfCliente =
              userData['cpf']; // Certifique-se que a chave 'cpf' está correta
          _isLoadingCpf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCpf = false;
        });
      }
      // Erro ao carregar CPF do usuário para DepartamentosOsPage
      // Considerar mostrar uma mensagem para o usuário
    }
  }

  // Helper para obter ícone baseado no departamento (mantido original)
  IconData _getIconForDepartamento(String departamento) {
    switch (departamento.toLowerCase()) {
      case 'ambiental':
        return Icons.eco;
      case 'fundiário':
        return Icons.map; // Alterado para Icons.map para melhor semântica
      case 'fiscal e jurídico':
        return Icons.gavel;
      case 'bancos':
        return Icons.account_balance;
      default:
        return Icons.folder_special;
    }
  }

  // Função para navegar para a lista de OS do departamento (mantido original)
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
      body: _isLoadingCpf
          ? const Center(
              child: CircularProgressIndicator(
                  semanticsLabel: "Carregando dados do usuário..."))
          : _cpfCliente == null || _cpfCliente!.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Não foi possível carregar as informações do usuário (CPF) para buscar as Ordens de Serviço. Verifique seu login.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                )
              : FutureBuilder<QuerySnapshot>(
                  // Consulta direta ao Firestore
                  future: _firestore.collection('ordensServico').get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                            'Erro ao carregar Ordens de Serviço: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma Ordem de Serviço encontrada.'),
                      );
                    }

                    // Convertendo documentos para Map e filtrando
                    final List<Map<String, dynamic>> todasOrdens = snapshot
                        .data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList();

                    // Filtrando as ordens para o cliente e fazenda específicos
                    // NOTA: Ajuste os nomes dos campos conforme sua estrutura de dados
                    final List<Map<String, dynamic>> ordens =
                        todasOrdens.where((os) {
                      // Tenta diferentes possíveis nomes de campos para cliente
                      final bool clienteMatch =
                          (os['nomeCliente'] == widget.nomeCliente) ||
                              (os['cliente'] == widget.nomeCliente) ||
                              (os['razaoSocial'] == widget.nomeCliente);

                      // Tenta diferentes possíveis nomes de campos para fazenda
                      final bool fazendaMatch =
                          (os['nomeFazenda'] == widget.nomeFazenda) ||
                              (os['fazenda'] == widget.nomeFazenda) ||
                              (os['propriedade'] == widget.nomeFazenda);

                      return clienteMatch && fazendaMatch;
                    }).toList();

                    if (ordens.isEmpty) {
                      return const Center(
                        child: Text(
                            'Nenhuma Ordem de Serviço encontrada para esta fazenda e cliente.'),
                      );
                    }

                    // Agrupa as ordens por departamento
                    final Map<String, List<Map<String, dynamic>>>
                        ordensPorDepartamento = {};

                    for (var os in ordens) {
                      // Tenta diferentes possíveis nomes de campos para departamento
                      String departamento = 'Não Classificado';

                      if (os['departamentoRelacionado'] != null &&
                          os['departamentoRelacionado'].toString().isNotEmpty) {
                        departamento = os['departamentoRelacionado'].toString();
                      } else if (os['departamento'] != null &&
                          os['departamento'].toString().isNotEmpty) {
                        departamento = os['departamento'].toString();
                      } else if (os['setor'] != null &&
                          os['setor'].toString().isNotEmpty) {
                        departamento = os['setor'].toString();
                      }

                      if (ordensPorDepartamento.containsKey(departamento)) {
                        ordensPorDepartamento[departamento]!.add(os);
                      } else {
                        ordensPorDepartamento[departamento] = [os];
                      }
                    }

                    final departamentosOrdenados =
                        ordensPorDepartamento.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: departamentosOrdenados.length,
                      itemBuilder: (context, index) {
                        final departamento = departamentosOrdenados[index];
                        final ordensDoDepartamento =
                            ordensPorDepartamento[departamento]!;
                        final count = ordensDoDepartamento.length;

                        // UI do item da lista mantida original, apenas corrigido o withOpacity
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Material(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(12),
                            elevation: 3.0,
                            // Corrigido: withOpacity → withValues
                            shadowColor: Colors.black
                                .withValues(alpha: 51), // 0.2 * 255 = 51
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  _navegarParaOrdensDepartamento(departamento),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        // Corrigido: withOpacity → withValues
                                        color: Colors.white.withValues(
                                            alpha: 230), // 0.9 * 255 = 230
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

/* 
NOTA IMPORTANTE: 

Esta implementação:

1. Acessa diretamente o Firestore em vez de depender de OsService
2. Tenta vários nomes possíveis de campos para cliente, fazenda e departamento
3. Filtra os resultados no lado do cliente em vez de na consulta

Se você quiser melhorar a eficiência, considere:

1. Implementar um método em OsService que faça a consulta correta
2. Usar where() diretamente na consulta do Firestore para filtrar no servidor
3. Padronizar os nomes dos campos em seus documentos

Exemplo de implementação em OsService:

```dart
// Em lib/services/os_service.dart
Future<List<Map<String, dynamic>>> getOrdensServicoByClienteFazenda(
    String nomeCliente, String nomeFazenda) async {
  final snapshot = await _firestore
      .collection('ordensServico')
      .where('nomeCliente', isEqualTo: nomeCliente)
      .where('nomeFazenda', isEqualTo: nomeFazenda)
      .get();
  
  return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
}
```
*/
