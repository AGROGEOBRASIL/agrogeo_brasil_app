import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatação de data
// import 'package:agrogeo_brasil_app_main/screens/os_chat.dart'; // Comentado pois a navegação primária mudou
import 'package:agrogeo_brasil_app_main/screens/os_detalhes_etapas_page.dart'; // IMPORT ADICIONADO
import 'dart:developer' as developer;

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
    developer.log(
        '--- DIAGNÓSTICO DETALHADO: Listando todas as OS para o cliente ---',
        name: 'OrdensServicoDepartamentoPage');
    developer.log('Cliente para diagnóstico: [${widget.nomeCliente}]',
        name: 'OrdensServicoDepartamentoPage');
    try {
      final querySnapshot = await _firestore
          .collection('ordensServico')
          .where('nomeCliente', isEqualTo: widget.nomeCliente)
          .get();

      developer.log(
          'Diagnóstico: ${querySnapshot.docs.length} OS encontradas para este cliente.',
          name: 'OrdensServicoDepartamentoPage');

      if (querySnapshot.docs.isEmpty) {
        developer.log(
            'Diagnóstico: Nenhuma OS encontrada para este cliente no Firestore.',
            name: 'OrdensServicoDepartamentoPage');
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
          developer.log(
              '  -> OS ID: $docId | Cliente DB: [$clienteDb] | Fazenda DB: [$fazendaDb] | Depto DB: [$deptoDb] | TipoServico: [$tipoServicoDb] | OutroServico: [$outroServicoDb] | Status: [$statusDb]',
              name: 'OrdensServicoDepartamentoPage');
        }
      }
    } catch (e) {
      developer.log('!!! Erro no Diagnóstico Detalhado: $e',
          name: 'OrdensServicoDepartamentoPage');
    }
    developer.log("--- FIM DIAGNÓSTICO DETALHADO ---",
        name: 'OrdensServicoDepartamentoPage');
  }

  @override
  void initState() {
    super.initState();
    _runDetailedDiagnosis();
  }

  Color _getStatusColor(Map<String, dynamic> osData, String docId) {
    String? rawStatus = osData['status'];
    String status = (rawStatus ?? '').trim().toLowerCase();
    developer.log(
        'DEBUG COR: DocID: $docId | Status bruto: [$rawStatus] | Status processado: [$status]',
        name: 'OrdensServicoDepartamentoPage');
    if (status == 'finalizado' || status == 'concluido' || status == 'pronto') {
      developer.log('DEBUG COR: $docId -> COR VERDE (Finalizado)',
          name: 'OrdensServicoDepartamentoPage');
      return Colors.green.shade700;
    }
    if (status.contains('andamento') ||
        status == 'pausado' ||
        status == 'pausa') {
      developer.log('DEBUG COR: $docId -> COR LARANJA (Em andamento/Pausado)',
          name: 'OrdensServicoDepartamentoPage');
      return Colors.orange.shade700;
    }
    developer.log('DEBUG COR: $docId -> COR VERMELHA (Pendente/Outro)',
        name: 'OrdensServicoDepartamentoPage');
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
    developer.log(
        'DEBUG TÍTULO: DocID: $docId | TipoServico: [$tipoServico] | OutroServico: [$outroServico] | Título: [$titulo] | Resultado: [$resultado]',
        name: 'OrdensServicoDepartamentoPage');
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
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    developer.log('--- CONSULTA PRINCIPAL: Buscando OS para ---',
        name: 'OrdensServicoDepartamentoPage');
    developer.log('Cliente Filtro: [${widget.nomeCliente}]',
        name: 'OrdensServicoDepartamentoPage');
    developer.log('Fazenda Filtro: [${widget.nomeFazenda}]',
        name: 'OrdensServicoDepartamentoPage');
    developer.log('Departamento Filtro: [${widget.departamento}]',
        name: 'OrdensServicoDepartamentoPage');
    developer.log('------------------------------------------',
        name: 'OrdensServicoDepartamentoPage');

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
                developer.log(
                    '!!! Erro na Consulta Principal: ${snapshot.error}',
                    name: 'OrdensServicoDepartamentoPage');
                return Center(
                  child: Text(
                      'Erro ao carregar Ordens de Serviço: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
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
                            color: Colors.black.withOpacity(
                                0.1), // Mantido withOpacity por compatibilidade
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(
                                0, 2), // changes position of shadow
                          ),
                        ]),
                    child: const Text(
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
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                ],
              );

              developer.log(
                  'Consulta Principal Snapshot: hasData=${snapshot.hasData}, docs.length=${snapshot.data?.docs.length ?? 0}',
                  name: 'OrdensServicoDepartamentoPage');

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
                      developer.log(
                          'Erro ao formatar dataEmissao: $dataEmissaoString - $e',
                          name: 'OrdensServicoDepartamentoPage');
                      dataCriacaoFormatada = dataEmissaoString;
                      dataParaOsDetalhesPage =
                          Timestamp.now(); // Fallback crítico
                      developer.log(
                          'ALERTA: Usando Timestamp.now() como fallback para dataCriacaoOs para OS ID: $docId devido a erro de parse.',
                          name: 'OrdensServicoDepartamentoPage');
                    }
                  } else {
                    dataParaOsDetalhesPage =
                        Timestamp.now(); // Fallback crítico
                    developer.log(
                        'ALERTA: Usando Timestamp.now() como fallback para dataCriacaoOs para OS ID: $docId pois nenhuma data foi encontrada.',
                        name: 'OrdensServicoDepartamentoPage');
                  }
                }

                String tipoServicoDaOs = (data['tipoServico'] as String?) ?? '';
                if (tipoServicoDaOs.isEmpty) {
                  developer.log(
                      "ALERTA: tipoServico está vazio para OS ID: $docId. A busca de documentos da etapa pode falhar.",
                      name: 'OrdensServicoDepartamentoPage');
                  // Considerar um valor padrão se for absolutamente necessário, mas o ideal é ter o dado correto.
                  // tipoServicoDaOs = "ServicoNaoEspecificado";
                }

                developer.log(
                    'Consulta Principal: OS ID: $docId | Título: [$titulo] | Status: [$statusAtual] | Cor: ${color == Colors.orange.shade700 ? "LARANJA" : color == Colors.green.shade700 ? "VERDE" : "VERMELHA"} | Data Formatada: $dataCriacaoFormatada',
                    name: 'OrdensServicoDepartamentoPage');

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
                      developer.log(
                          'Botão OS Pressionado: ID: $docId, Título: $titulo. Navegando para Detalhes/Etapas.',
                          name: 'OrdensServicoDepartamentoPage');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OsDetalhesEtapasPage(
                            osId: docId,
                            osTitle: titulo,
                            nomeCliente: widget.nomeCliente,
                            nomeFazenda: widget.nomeFazenda,
                            tipoServicoOs: tipoServicoDaOs,
                            dataCriacaoOs: dataParaOsDetalhesPage,
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
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: $statusAtual',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Data: $dataCriacaoFormatada',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                0.49), // Mantido withOpacity por compatibilidade
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black87,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: ListView(
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
