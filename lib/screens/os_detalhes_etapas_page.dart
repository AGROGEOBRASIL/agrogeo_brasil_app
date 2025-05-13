import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrogeo_brasil_app_main/screens/os_chat.dart'; // Assumindo que esta tela existe
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart'; // Import para Firebase Storage

// Modelo para representar um anexo de arquivo
class Anexo {
  final String nome;
  final String url;
  final String tipo; // Ex: "pdf", "png", "jpg", "doc"

  Anexo({
    required this.nome,
    required this.url,
    required this.tipo,
  });

  factory Anexo.fromMap(Map<String, dynamic> map) {
    String tipoInferido =
        map['tipo'] ?? map['nome']?.split('.').last ?? 'desconhecido';
    if (tipoInferido.isEmpty && map['nome'] != null) {
      tipoInferido = map['nome'].contains('.')
          ? map['nome'].split('.').last
          : 'desconhecido';
    }
    return Anexo(
      nome: map['nome'] ?? 'Arquivo sem nome',
      url: map['url'] ?? '',
      tipo: tipoInferido,
    );
  }
}

// Modelo para representar uma etapa combinada com seu progresso e anexos
class EtapaComProgresso {
  final String id;
  final String nome;
  final String status; // "Concluído", "Em Andamento", "Pendente"
  final String observacao;
  final List<Anexo> anexos; // Anexos diretamente da OS (se houver)
  final String caminhoPastaEtapa; // Caminho no Storage para documentos da etapa

  EtapaComProgresso({
    required this.id,
    required this.nome,
    this.status = "Pendente", // Valor padrão
    this.observacao = '',
    this.anexos = const [],
    required this.caminhoPastaEtapa,
  });
}

class OsDetalhesEtapasPage extends StatefulWidget {
  final String osId;
  final String osTitle;
  final String nomeCliente;
  final String nomeFazenda;
  final String tipoServicoOs;
  final Timestamp dataCriacaoOs; // Adicionado para construir o caminho da pasta

  const OsDetalhesEtapasPage({
    super.key,
    required this.osId,
    required this.osTitle,
    required this.nomeCliente,
    required this.nomeFazenda,
    required this.tipoServicoOs, // Receber o tipo de serviço da OS
    required this.dataCriacaoOs, // Receber a data de criação da OS
  });

  @override
  State<OsDetalhesEtapasPage> createState() => _OsDetalhesEtapasPageState();
}

class _OsDetalhesEtapasPageState extends State<OsDetalhesEtapasPage> {
  final Dio _dio = Dio();
  bool _isDownloading = false;
  final TextEditingController _messageController = TextEditingController();

  String _formatarDataParaPasta(Timestamp timestamp) {
    DateTime data = timestamp.toDate();
    return "${data.day.toString().padLeft(2, '0')}-${data.month.toString().padLeft(2, '0')}-${data.year}";
  }

  String _inferStatus(Map<String, dynamic> progressoEtapaMap) {
    if (progressoEtapaMap.containsKey('status') &&
        progressoEtapaMap['status'] != null) {
      return progressoEtapaMap['status'].toString();
    }
    if (progressoEtapaMap.containsKey('concluido') &&
        progressoEtapaMap['concluido'] is bool) {
      return progressoEtapaMap['concluido'] ? "Concluído" : "Pendente";
    }
    return "Pendente"; // Default
  }

  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OsChatScreen(
          osId: widget.osId,
          osTitle: widget.osTitle,
          clienteNome: widget.nomeCliente,
          nomeFazenda: widget.nomeFazenda,
        ),
      ),
    );
  }

  Future<void> _visualizarArquivo(Anexo anexo) async {
    developer.log('Tentando visualizar URL: ${anexo.url} para ${anexo.nome}',
        name: 'OsDetalhesEtapasPage._visualizarArquivo');
    if (anexo.url.isEmpty) {
      developer.log('URL do anexo está vazia.',
          name: 'OsDetalhesEtapasPage._visualizarArquivo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL do arquivo inválida.')),
        );
      }
      return;
    }

    final Uri uri = Uri.parse(anexo.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        developer.log(
            'Não foi possível abrir a URL: ${anexo.url} (canLaunchUrl retornou false)',
            name: 'OsDetalhesEtapasPage._visualizarArquivo');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Não foi possível abrir o arquivo: ${anexo.nome}')),
          );
        }
      }
    } catch (e) {
      developer.log('Erro ao tentar abrir URL: ${anexo.url} - Erro: $e',
          name: 'OsDetalhesEtapasPage._visualizarArquivo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir arquivo: $e')),
        );
      }
    }
  }

  Future<void> _baixarArquivo(Anexo anexo) async {
    if (anexo.url.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('URL do arquivo inválida para download.')));
      return;
    }

    if (mounted) {
      setState(() {
        _isDownloading = true;
      });
    }

    PermissionStatus status;
    if (Platform.isIOS) {
      status = await Permission.photos
          .request(); // iOS usa permissão de fotos para salvar na galeria
    } else {
      // Android e outras plataformas
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      try {
        Directory? dir;
        if (Platform.isAndroid) {
          dir =
              await getExternalStorageDirectory(); // ou getApplicationDocumentsDirectory();
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        }

        if (dir == null) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Não foi possível obter o diretório de download.')));
          if (mounted)
            setState(() {
              _isDownloading = false;
            });
          return;
        }

        String savePath = "${dir.path}/${anexo.nome}";
        developer.log('Caminho para salvar: $savePath',
            name: 'OsDetalhesEtapasPage._baixarArquivo');

        await _dio.download(
          anexo.url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              developer.log(
                  "Progresso: ${(received / total * 100).toStringAsFixed(0)}%",
                  name: 'OsDetalhesEtapasPage._baixarArquivo');
            }
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Download de "${anexo.nome}" concluído! Salvo em: ${dir.path}'),
              action: SnackBarAction(
                label: 'ABRIR',
                onPressed: () {
                  OpenFilex.open(savePath);
                },
              ),
              duration: const Duration(seconds: 7),
            ),
          );
        }
      } catch (e) {
        developer.log('Erro durante o download: $e',
            name: 'OsDetalhesEtapasPage._baixarArquivo');
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erro no download: $e')));
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
      }
    } else {
      developer.log('Permissão de armazenamento negada.',
          name: 'OsDetalhesEtapasPage._baixarArquivo');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Permissão de armazenamento negada para realizar o download.')));
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  IconData _getIconForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluído':
      case 'concluido':
        return Icons.check_circle;
      case 'em andamento':
      case 'em-andamento':
        return Icons.hourglass_top_rounded;
      case 'pendente':
        return Icons.radio_button_unchecked;
      default:
        return Icons.help_outline;
    }
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluído':
      case 'concluido':
        return Colors.green;
      case 'em andamento':
      case 'em-andamento':
        return Colors.orange;
      case 'pendente':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForFileType(String tipo) {
    String ext = tipo.toLowerCase();
    if (ext.contains('pdf')) return Icons.picture_as_pdf;
    if (ext.contains('doc') || ext.contains('docx')) return Icons.description;
    if (ext.contains('xls') || ext.contains('xlsx')) return Icons.table_chart;
    if (ext.contains('ppt') || ext.contains('pptx')) return Icons.slideshow;
    if (ext.contains('png') ||
        ext.contains('jpg') ||
        ext.contains('jpeg') ||
        ext.contains('gif') ||
        ext.contains('webp')) return Icons.image;
    if (ext.contains('zip') || ext.contains('rar')) return Icons.archive;
    return Icons.attach_file; // Ícone padrão
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'AGROGEO BRASIL',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.osTitle.toUpperCase(),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordensServico')
            .doc(widget.osId)
            .snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> osSnapshot) {
          if (osSnapshot.hasError) {
            developer.log('Erro no StreamBuilder da OS: ${osSnapshot.error}',
                name: 'OsDetalhesEtapasPage');
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                        'Erro ao carregar dados da OS: ${osSnapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center)));
          }
          if (osSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!osSnapshot.hasData || !osSnapshot.data!.exists) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Ordem de Serviço não encontrada.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center)));
          }

          Map<String, dynamic> osData =
              osSnapshot.data!.data() as Map<String, dynamic>;
          // String tipoServico = osData['tipoServico'] ?? ''; // Usar o tipoServico passado pelo widget
          Map<String, dynamic> progressoData =
              (osData['progresso'] as Map<String, dynamic>?) ?? {};

          if (widget.tipoServicoOs.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Tipo de serviço não definido para esta OS.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center)));
          }

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('tiposTrabalho')
                .where('nome',
                    isEqualTo: widget
                        .tipoServicoOs) // Usar o tipoServico passado pelo widget
                .limit(1)
                .get(),
            builder:
                (context, AsyncSnapshot<QuerySnapshot> tipoTrabalhoSnapshot) {
              if (tipoTrabalhoSnapshot.hasError) {
                developer.log(
                    'Erro no FutureBuilder do tipoTrabalho: ${tipoTrabalhoSnapshot.error}',
                    name: 'OsDetalhesEtapasPage');
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Erro ao carregar definição do serviço: ${tipoTrabalhoSnapshot.error}',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center)));
              }
              if (tipoTrabalhoSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (tipoTrabalhoSnapshot.data == null ||
                  tipoTrabalhoSnapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'Definição do tipo de serviço não encontrada.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center)));
              }

              DocumentSnapshot tipoTrabalhoDoc =
                  tipoTrabalhoSnapshot.data!.docs.first;
              Map<String, dynamic> tipoTrabalhoData =
                  tipoTrabalhoDoc.data() as Map<String, dynamic>;
              List<String> nomesEtapasDefinidas = [];

              if (tipoTrabalhoData.containsKey('etapas') &&
                  tipoTrabalhoData['etapas'] is List &&
                  (tipoTrabalhoData['etapas'] as List).isNotEmpty) {
                if ((tipoTrabalhoData['etapas'] as List)
                    .every((item) => item is String)) {
                  nomesEtapasDefinidas = (tipoTrabalhoData['etapas'] as List)
                      .map((item) => item.toString())
                      .toList();
                }
              } else if (tipoTrabalhoData.containsKey('checklist') &&
                  tipoTrabalhoData['checklist'] is List) {
                nomesEtapasDefinidas = (tipoTrabalhoData['checklist'] as List)
                    .where((item) =>
                        item is Map<String, dynamic> &&
                        item.containsKey('nome'))
                    .map((item) =>
                        (item as Map<String, dynamic>)['nome'].toString())
                    .toList();
              } else {
                developer.log(
                    "Estrutura de checklist/etapas não encontrada ou inesperada em 'tiposTrabalho' para '${widget.tipoServicoOs}'. Usando fallback.",
                    name: 'OsDetalhesEtapasPage');
                nomesEtapasDefinidas = [
                  "REUNIR DOCUMENTOS PESSOAIS E DA PROPRIEDADE",
                  "CROQUI DO IMÓVEL",
                  "DOCUMENTOS ADMINISTRATIVOS",
                  "ATENDIMENTO DE NOTIFICAÇÃO SE HOUVER",
                  "RECEBIMENTO DA CERTIDÃO DE POSSE"
                ];
              }

              List<EtapaComProgresso> listaEtapasComProgresso = [];
              for (String nomeEtapa in nomesEtapasDefinidas) {
                String etapaId = nomeEtapa
                    .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
                    .toLowerCase();
                Map<String, dynamic> progressoEtapaMap =
                    (progressoData[etapaId] as Map<String, dynamic>?) ?? {};
                List<Anexo> anexosDaOs =
                    []; // Anexos que já vêm da OS (se houver)
                if (progressoEtapaMap.containsKey('arquivos') &&
                    progressoEtapaMap['arquivos'] is List) {
                  List<dynamic> arquivosDynamic = progressoEtapaMap['arquivos'];
                  anexosDaOs = arquivosDynamic
                      .where((item) => item is Map<String, dynamic>)
                      .map((map) => Anexo.fromMap(map as Map<String, dynamic>))
                      .toList();
                }
                String statusEtapa = _inferStatus(progressoEtapaMap);

                // Construção do caminho da pasta da etapa
                String nomeServicoComData =
                    "${widget.tipoServicoOs} ${_formatarDataParaPasta(widget.dataCriacaoOs)}";
                String nomeEtapaFormatado = nomeEtapa
                    .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
                    .replaceAll(' ', '_');
                String caminhoPastaEtapa =
                    'clientes/${widget.nomeCliente}/fazendas/${widget.nomeFazenda}/$nomeServicoComData/etapas/$nomeEtapaFormatado/';

                listaEtapasComProgresso.add(EtapaComProgresso(
                  id: etapaId,
                  nome: nomeEtapa,
                  status: statusEtapa,
                  observacao: progressoEtapaMap['observacao']?.toString() ?? '',
                  anexos: anexosDaOs, // Mantém os anexos originais da OS
                  caminhoPastaEtapa: caminhoPastaEtapa,
                ));
              }

              if (listaEtapasComProgresso.isEmpty) {
                return const Center(
                    child: Text(
                        'Nenhuma etapa encontrada para este tipo de serviço.',
                        style: TextStyle(fontSize: 16)));
              }

              return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  itemCount: listaEtapasComProgresso.length,
                  itemBuilder: (context, index) {
                    final etapa = listaEtapasComProgresso[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_getIconForStatus(etapa.status),
                                    color: _getColorForStatus(etapa.status),
                                    size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      'ETAPA: ${etapa.nome.toUpperCase()}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 34),
                              child: Text('Status: ${etapa.status}',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700])),
                            ),
                            if (etapa.observacao.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 34, top: 4),
                                child: Text('Observação: ${etapa.observacao}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic)),
                              ),
                            // A seção de anexos da OS (se houver) continua aqui
                            if (etapa.anexos.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 34, top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Anexos (OS):',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    ...etapa.anexos.map((anexo) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(
                                                _getIconForFileType(anexo.tipo),
                                                color: Colors.grey[700],
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(anexo.nome,
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            IconButton(
                                              icon: Icon(Icons.visibility,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  size: 20),
                                              tooltip:
                                                  'Visualizar ${anexo.nome}',
                                              onPressed: () =>
                                                  _visualizarArquivo(anexo),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                  Icons
                                                      .download_for_offline_outlined,
                                                  color: Theme.of(context)
                                                      .primaryColorDark,
                                                  size: 20),
                                              tooltip: 'Baixar ${anexo.nome}',
                                              onPressed: _isDownloading
                                                  ? null
                                                  : () => _baixarArquivo(anexo),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  });
            },
          );
        },
      ),
      bottomNavigationBar: GestureDetector(
        onTap: _abrirChat,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          margin: const EdgeInsets.only(
              left: 16.0, right: 16.0, bottom: 24.0, top: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(25.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Digite uma mensagem...',
                  style: TextStyle(color: Colors.black54, fontSize: 16.0),
                ),
              ),
              Icon(Icons.message_outlined,
                  color: Colors.black54), // Ícone de mensagem, sem microfone
            ],
          ),
        ),
      ),
    );
  }
}
