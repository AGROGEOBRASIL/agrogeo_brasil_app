import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatação de data
// import 'package:agrogeo_app_novo/screens/os_chat.dart'; // Comentado pois a navegação primária mudou
import 'package:agrogeo_app_novo/screens/os_detalhes_etapas_page.dart'; // IMPORT ADICIONADO

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

  // Função de diagnóstico detalhado
  Future<void> _runDetailedDiagnosis() async {
    print('--- DIAGNÓSTICO DETALHADO: Listando todas as OS para o cliente ---');
    print('Cliente para diagnóstico: [${widget.nomeCliente}]');
    try {
      final querySnapshot = await _firestore
          .collection('ordensServico')
          .where('nomeCliente', isEqualTo: widget.nomeCliente)
          .get();

      print(
          'Diagnóstico: ${querySnapshot.docs.length} OS encontradas para este cliente.');

      if (querySnapshot.docs.isEmpty) {
        print(
            'Diagnóstico: Nenhuma OS encontrada para este cliente no Firestore.');
      } else {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final docId = doc.id;
          final clienteDb = data['nomeCliente'] ?? 'N/A';
          final fazendaDb = data['fazenda'] ?? 'N/A';
          final deptoDb = data['departamentoRelacionado'] ?? 'N/A';
          final tipoServicoDb = data['tipoServico'] ?? 'N/A';
          final outroServicoDb = data['outroServico'] ?? 'N/A';
          final statusDb = data['status'] ?? 'N/A';
          print(
              '  -> OS ID: $docId | Cliente DB: [$clienteDb] | Fazenda DB: [$fazendaDb] | Depto DB: [$deptoDb] | TipoServico: [$tipoServicoDb] | OutroServico: [$outroServicoDb] | Status: [$statusDb]');
        }
      }
    } catch (e) {
      print('!!! Erro no Diagnóstico Detalhado: $e');
    }
    print("--- FIM DIAGNÓSTICO DETALHADO ---");
  }

  @override
  void initState() {
    super.initState();
    _runDetailedDiagnosis();
  }

  Color _getStatusColor(Map<String, dynamic> osData, String docId) {
    String? rawStatus = osData['status'];
    String status = (rawStatus ?? '').trim().toLowerCase();
    print(
        'DEBUG COR: DocID: $docId | Status bruto: [$rawStatus] | Status processado: [$status]');
    if (status == 'finalizado' || status == 'concluido' || status == 'pronto') {
      print('DEBUG COR: $docId -> COR VERDE (Finalizado)');
      return Colors.green.shade700;
    }
    if (status.contains('andamento') ||
        status == 'pausado' ||
        status == 'pausa') {
      print('DEBUG COR: $docId -> COR LARANJA (Em andamento/Pausado)');
      return Colors.orange.shade700;
    }
    print('DEBUG COR: $docId -> COR VERMELHA (Pendente/Outro)');
    return Colors.red.shade700;
  }

  String _getOSTitulo(Map<String, dynamic> osData, String docId) {
    String? tipoServico = osData['tipoServico'];
    String? outroServico = osData['outroServico'];
    String? titulo = osData['titulo'];
    tipoServico = (tipoServico ?? '').trim();
    outroServico = (outroServico ?? '').trim();
    titulo = (titulo ?? '').trim();
    String resultado = '';
    if (tipoServico.isNotEmpty) {
      resultado = tipoServico;
    } else if (outroServico.isNotEmpty) {
      resultado = outroServico;
    } else if (titulo.isNotEmpty) {
      resultado = titulo;
    } else {
      resultado = 'OS #${docId.substring(0, 6)}';
    }
    print(
        'DEBUG TÍTULO: DocID: $docId | TipoServico: [$tipoServico] | OutroServico: [$outroServico] | Título: [$titulo] | Resultado: [$resultado]');
    return resultado;
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.red.shade700, 'Não feito'),
          _buildLegendItem(Colors.orange.shade700, 'Em Andamento / Pausado'),
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
        Text(label, style: TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('--- CONSULTA PRINCIPAL: Buscando OS para ---');
    print('Cliente Filtro: [${widget.nomeCliente}]');
    print('Fazenda Filtro: [${widget.nomeFazenda}]');
    print('Departamento Filtro: [${widget.departamento}]');
    print('------------------------------------------');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios, color: Colors.grey.shade600, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0)
              .copyWith(bottom: 10.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('ordensServico')
                .where('nomeCliente', isEqualTo: widget.nomeCliente)
                .where('fazenda', isEqualTo: widget.nomeFazenda)
                .where('departamentoRelacionado',
                    isEqualTo: widget.departamento)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('!!! Erro na Consulta Principal: ${snapshot.error}');
                return Center(
                  child: Text(
                      'Erro ao carregar Ordens de Serviço: ${snapshot.error}',
                      style: TextStyle(color: Colors.red)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              Widget header = Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                        color: Colors.green.shade700, // Fundo verde
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(0, 2), // changes position of shadow
                          ),
                        ]),
                    child: Text(
                      'AGROGEO BRASIL',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16), // Texto branco
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
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                ],
              );

              print(
                  'Consulta Principal Snapshot: hasData=${snapshot.hasData}, docs.length=${snapshot.data?.docs.length ?? 0}');

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhuma Ordem de Serviço encontrada para ${widget.departamento} na fazenda ${widget.nomeFazenda}.\n(Verifique os filtros e dados no console e os índices no Firestore)',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    _buildLegend(),
                  ],
                );
              }

              final ordens = snapshot.data!.docs;

              List<Widget> osButtons = ordens.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final titulo = _getOSTitulo(data, docId);
                final color = _getStatusColor(data, docId);
                final statusAtual = (data['status'] ?? 'N/A').toString().trim();

                final dataCriacaoTimestamp = data['dataCriacao'] as Timestamp?;
                String dataCriacaoFormatada = 'Data não informada';
                Timestamp
                    dataParaOsDetalhesPage; // Variável para armazenar o Timestamp a ser passado

                final dynamic tsCriadoEm =
                    data['criadoEm']; // Priorizar 'criadoEm'
                final dynamic tsDataCriacao =
                    data['dataCriacao']; // Fallback para 'dataCriacao'

                if (tsCriadoEm is Timestamp) {
                  dataParaOsDetalhesPage = tsCriadoEm;
                  dataCriacaoFormatada =
                      DateFormat('dd/MM/yyyy').format(tsCriadoEm.toDate());
                } else if (tsDataCriacao is Timestamp) {
                  dataParaOsDetalhesPage = tsDataCriacao;
                  dataCriacaoFormatada =
                      DateFormat('dd/MM/yyyy').format(tsDataCriacao.toDate());
                } else {
                  final dataEmissaoString = data['dataEmissao'] as String?;
                  if (dataEmissaoString != null &&
                      dataEmissaoString.isNotEmpty) {
                    try {
                      DateTime parsedDate =
                          DateFormat('yyyy-MM-dd').parse(dataEmissaoString);
                      dataCriacaoFormatada =
                          DateFormat('dd/MM/yyyy').format(parsedDate);
                      dataParaOsDetalhesPage = Timestamp.fromDate(parsedDate);
                    } catch (e) {
                      print(
                          'Erro ao formatar dataEmissao: $dataEmissaoString - $e');
                      dataCriacaoFormatada = dataEmissaoString;
                      dataParaOsDetalhesPage =
                          Timestamp.now(); // Fallback crítico
                      print(
                          'ALERTA: Usando Timestamp.now() como fallback para dataCriacaoOs para OS ID: $docId devido a erro de parse.');
                    }
                  } else {
                    dataParaOsDetalhesPage =
                        Timestamp.now(); // Fallback crítico
                    print(
                        'ALERTA: Usando Timestamp.now() como fallback para dataCriacaoOs para OS ID: $docId pois nenhuma data foi encontrada.');
                  }
                }

                String tipoServicoDaOs = (data['tipoServico'] as String?) ?? '';
                if (tipoServicoDaOs.isEmpty) {
                  print(
                      "ALERTA: tipoServico está vazio para OS ID: $docId. A busca de documentos da etapa pode falhar.");
                  // Considerar um valor padrão se for absolutamente necessário, mas o ideal é ter o dado correto.
                  // tipoServicoDaOs = "ServicoNaoEspecificado";
                }

                print(
                    'Consulta Principal: OS ID: $docId | Título: [$titulo] | Status: [$statusAtual] | Cor: ${color == Colors.orange.shade700 ? "LARANJA" : color == Colors.green.shade700 ? "VERDE" : "VERMELHA"} | Data Formatada: $dataCriacaoFormatada');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () {
                      print(
                          'Botão OS Pressionado: ID: $docId, Título: $titulo. Navegando para Detalhes/Etapas.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OsDetalhesEtapasPage(
                            osId: docId,
                            osTitle: titulo,
                            nomeCliente: widget.nomeCliente,
                            nomeFazenda: widget.nomeFazenda,
                            tipoServicoOs:
                                tipoServicoDaOs, // CORRIGIDO: Passando o tipo de serviço da OS
                            dataCriacaoOs:
                                dataParaOsDetalhesPage, // CORRIGIDO: Passando o Timestamp de criação/emissão da OS
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1, // Adicionado para evitar quebra de linha excessiva
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Data: $dataCriacaoFormatada',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                );
              }).toList(); // Convertendo o map para uma lista de widgets

              return Column(
                children: [
                  header,
                  _buildLegend(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8.0),
                      children: osButtons,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

