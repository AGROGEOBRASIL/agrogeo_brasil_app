import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Removido import não utilizado: import 'package:intl/intl.dart';

// Removido import de os_detalhes_page.dart pois não será usado agora

class OrdensServicoDepartamentoPage extends StatefulWidget {
  final String nomeCliente;
  final String nomeFazenda;
  final String departamento;

  const OrdensServicoDepartamentoPage({
    super.key,
    required this.nomeCliente,
    required this.nomeFazenda,
    required this.departamento,
  });

  @override
  State<OrdensServicoDepartamentoPage> createState() =>
      _OrdensServicoDepartamentoPageState();
}

class _OrdensServicoDepartamentoPageState
    extends State<OrdensServicoDepartamentoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Função para determinar a cor do status (mantida)
  Color _getStatusColor(Map<String, dynamic> osData) {
    String status = osData['status']?.toLowerCase() ?? 'pendente';

    // Removidas variáveis não utilizadas:
    // Timestamp? ultimaAtualizacaoTimestamp = osData['ultimaAtualizacaoStatus'];
    // Timestamp? criadoEmTimestamp = osData['criadoEm'];
    // Timestamp? dataReferenciaTimestamp = ultimaAtualizacaoTimestamp ?? criadoEmTimestamp;

    // Mapeamento de status para cores conforme imagem
    if (status == 'finalizado' || status == 'concluido' || status == 'pronto') {
      return Colors.green.shade700; // Verde escuro para 'Pronto'
    }
    if (status == 'em andamento') {
      return Colors.orange.shade700; // Laranja para 'Em andamento'
    }
    // Se não for nenhum dos acima, consideramos 'Não feito' ou similar
    return Colors.red.shade700; // Vermelho para 'Não feito'

    /* Lógica anterior de tempo (removida para simplificar conforme imagem)
    if (dataReferenciaTimestamp != null) {
      DateTime dataReferencia = dataReferenciaTimestamp.toDate();
      DateTime umMesAtras = DateTime.now().subtract(const Duration(days: 30));
      if (dataReferencia.isBefore(umMesAtras)) {
        return Colors.red;
      }
    }
    return Colors.grey; // Cinza removido, usando vermelho como padrão para não pronto/andamento
    */
  }

  // Função para construir a legenda (NOVO)
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.red.shade700, 'Não feito'),
          _buildLegendItem(Colors.orange.shade700, 'Em andamento'),
          _buildLegendItem(Colors.green.shade700, 'Pronto'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)), // Adicionado const
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removido para seguir o layout da imagem
      // appBar: AppBar(
      //   title: Text('${widget.departamento} - ${widget.nomeFazenda}'),
      //   backgroundColor: Colors.green[700],
      // ),
      backgroundColor: Colors.white, // Fundo branco como na imagem
      body: SafeArea(
        // Garante que o conteúdo não fique sob barras do sistema
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('ordensServico')
                .where('cliente', isEqualTo: widget.nomeCliente)
                .where('fazenda', isEqualTo: widget.nomeFazenda)
                .where('departamentoRelacionado',
                    isEqualTo: widget.departamento)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                      'Erro ao carregar Ordens de Serviço: ${snapshot.error}',
                      style: const TextStyle(
                          color: Colors.red)), // Adicionado const
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Cabeçalho (NOVO)
              Widget header = Column(
                children: [
                  // Placeholder para o Logo AGROGEO BRASIL (ajustar path se necessário)
                  // Image.asset('assets/logo_agrogeo.png', height: 50), // Exemplo
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.green.shade700, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'AGROGEO BRASIL',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade400)),
                    child: Text(
                      widget.nomeFazenda.toUpperCase(),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.departamento.toUpperCase(),
                    style: const TextStyle(
                        // Adicionado const
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                ],
              );

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Centraliza o conteúdo
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // Estica o conteúdo horizontalmente
                  children: [
                    header, // Mostra o cabeçalho mesmo sem OS
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhuma Ordem de Serviço encontrada para ${widget.departamento} na fazenda ${widget.nomeFazenda}.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    _buildLegend(), // Mostra a legenda mesmo sem OS
                  ],
                );
              }

              final ordens = snapshot.data!.docs;

              // Corpo com os botões (NOVO)
              List<Widget> osButtons = ordens.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final titulo =
                    data['titulo'] ?? data['outroServico'] ?? 'OS Sem Título';
                final color = _getStatusColor(data);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      minimumSize: const Size(double.infinity,
                          50), // Adicionado const, garante largura total
                    ),
                    onPressed: () {
                      // Ação ao clicar no botão (a ser definida depois)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Clicou em: $titulo (Ação não implementada)')),
                      );
                    },
                    child: Text(
                      titulo.toUpperCase(),
                      style: const TextStyle(
                          // Adicionado const
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }).toList();

              // Layout final com Cabeçalho, Botões e Legenda
              return Column(
                children: [
                  header,
                  Expanded(
                    child: ListView(
                      // Usar ListView permite scroll se houver muitas OS
                      children: osButtons,
                    ),
                  ),
                  _buildLegend(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
