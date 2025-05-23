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
import 'dart:convert'; // Para funções de codificação/decodificação
import 'package:firebase_storage/firebase_storage.dart'; // Import para Firebase Storage
import 'package:intl/intl.dart';

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

  // Cache para resultados de listAll para evitar múltiplas chamadas
  final Map<String, Map<String, bool>> _cacheArquivosControle = {};

  // Função para normalizar nome de pasta (transformar em slug)
  String _normalizeFolderName(String nome) {
    // Remove acentos usando uma abordagem compatível com Dart
    String withoutAccents = nome.toLowerCase();

    // Mapeamento de caracteres acentuados para não acentuados
    final Map<String, String> accentMap = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };

    // Substitui cada caractere acentuado pelo equivalente sem acento
    for (var entry in accentMap.entries) {
      withoutAccents = withoutAccents.replaceAll(entry.key, entry.value);
    }

    // Substitui tudo que não seja letra, número ou underscore por underscore
    return withoutAccents.replaceAll(RegExp(r'[^\w]'), '_');
  }

  String _formatarDataParaPasta(Timestamp timestamp) {
    DateTime data = timestamp.toDate();
    return "${data.day.toString().padLeft(2, '0')}-${data.month.toString().padLeft(2, '0')}-${data.year}";
  }

  String _normalizarNomeServico(String nome) {
    return nome
        .trim()
        .replaceAll(
            RegExp(r'[^\w\s-]'), '') // remove caracteres especiais e acentos
        .replaceAll(RegExp(r'\s+'), ' ') // normaliza espaços
        .replaceAll('/', '-') // substitui barra por traço
        .toUpperCase(); // tudo em MAIÚSCULO para consistência
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

  // Função para corrigir URLs do Storage
  String _corrigirUrlStorage(String url) {
    if (url.contains('painel-agrogeo.appspot.com')) {
      return url.replaceAll(
          'painel-agrogeo.appspot.com', 'painel-agrogeo.firebasestorage.app');
    }
    return url;
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
    // Corrige a URL do Storage antes de visualizar
    String urlCorrigida = _corrigirUrlStorage(anexo.url);

    developer.log('Tentando visualizar URL: $urlCorrigida para ${anexo.nome}',
        name: 'OsDetalhesEtapasPage._visualizarArquivo');
    if (urlCorrigida.isEmpty) {
      developer.log('URL do anexo está vazia.',
          name: 'OsDetalhesEtapasPage._visualizarArquivo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL do arquivo inválida.')),
        );
      }
      return;
    }

    final Uri uri = Uri.parse(urlCorrigida);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        developer.log(
            'Não foi possível abrir a URL: $urlCorrigida (canLaunchUrl retornou false)',
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
      developer.log('Erro ao tentar abrir URL: $urlCorrigida - Erro: $e',
          name: 'OsDetalhesEtapasPage._visualizarArquivo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir arquivo: $e')),
        );
      }
    }
  }

  Future<void> _baixarArquivo(Anexo anexo) async {
    // Corrige a URL do Storage antes de baixar
    String urlCorrigida = _corrigirUrlStorage(anexo.url);

    if (urlCorrigida.isEmpty) {
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
          urlCorrigida,
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

  // Função para verificar arquivos de controle (.keep e .visivel)
  Future<Map<String, bool>> verificarArquivosDeControle(
      String caminhoPastaEtapa) async {
    // Verifica se já temos o resultado em cache
    if (_cacheArquivosControle.containsKey(caminhoPastaEtapa)) {
      return _cacheArquivosControle[caminhoPastaEtapa]!;
    }

    try {
      final ref = FirebaseStorage.instance.ref(caminhoPastaEtapa);
      final ListResult result = await ref.listAll();

      // Adiciona logs para depuração
      developer.log('Listando arquivos em $caminhoPastaEtapa:',
          name: 'verificarArquivosDeControle');
      for (var item in result.items) {
        developer.log('  • encontrado: ${item.name}',
            name: 'verificarArquivosDeControle');
      }

      bool temKeep = result.items.any((item) => item.name == '.keep');
      bool temVisivel = result.items.any((item) => item.name == '.visivel');

      // Armazena o resultado em cache
      _cacheArquivosControle[caminhoPastaEtapa] = {
        'concluido': temKeep,
        'visivel': temVisivel,
      };

      return {
        'concluido': temKeep,
        'visivel': temVisivel,
      };
    } catch (e) {
      developer.log('Erro ao verificar arquivos da etapa: $e');
      return {
        'concluido': false,
        'visivel': false,
      };
    }
  }

  // Método para construir o widget de anexos
  Widget _buildAnexos(List<Anexo> anexos) {
    if (anexos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 8, bottom: 8),
          child: Text('Anexos da OS:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
        ),
        ...anexos.map((anexo) => Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Row(
                children: [
                  Icon(_getIconForFileType(anexo.tipo),
                      size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text(anexo.nome, style: const TextStyle(fontSize: 14)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () => _visualizarArquivo(anexo),
                    tooltip: 'Visualizar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download, size: 20),
                    onPressed:
                        _isDownloading ? null : () => _baixarArquivo(anexo),
                    tooltip: 'Baixar',
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // Método para construir o botão de visualizar documentos
  Widget _buildVisualizarBotao(bool mostrarBotao, EtapaComProgresso etapa) {
    if (!mostrarBotao) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Visualizar Documentos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pasta =
                  'clientes/${widget.nomeCliente}/fazendas/${widget.nomeFazenda}/'
                  '${_normalizarNomeServico(widget.tipoServicoOs)} '
                  '${_formatarDataParaPasta(widget.dataCriacaoOs)}/'
                  'etapas/${_normalizeFolderName(etapa.nome)}';

              // Navegar para a tela de documentos
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentosEtapaPage(pasta: pasta),
                ),
              );
            },
          ),
        ),
      ],
    );
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
                nomesEtapasDefinidas = (tipoTrabalhoData['etapas'] as List)
                    .map((etapa) => etapa.toString())
                    .toList();
              }

              if (nomesEtapasDefinidas.isEmpty) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'Nenhuma etapa definida para este tipo de serviço.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center)));
              }

              // Construir o caminho base para a pasta da OS no Storage
              String nomeServicoNormalizado =
                  _normalizarNomeServico(widget.tipoServicoOs);
              String dataFormatada =
                  _formatarDataParaPasta(widget.dataCriacaoOs);
              String caminhoBaseOs =
                  'clientes/${widget.nomeCliente}/fazendas/${widget.nomeFazenda}/$nomeServicoNormalizado $dataFormatada';

              // Preparar a lista de etapas com progresso
              List<EtapaComProgresso> listaEtapasComProgresso = [];

              // Para cada etapa definida no tipo de trabalho
              for (String nomeEtapa in nomesEtapasDefinidas) {
                String etapaId = nomeEtapa.replaceAll(' ', '_').toLowerCase();
                Map<String, dynamic> progressoEtapaMap =
                    progressoData[etapaId] as Map<String, dynamic>? ?? {};

                String statusEtapa = _inferStatus(progressoEtapaMap);

                // Construir o caminho para a pasta da etapa no Storage usando o nome normalizado
                final pastaNormalizada = _normalizeFolderName(nomeEtapa);
                String caminhoPastaEtapa =
                    '$caminhoBaseOs/etapas/$pastaNormalizada';

                // Verificar se há anexos específicos para esta etapa na OS
                List<Anexo> anexosDaOs = [];
                if (osData.containsKey('anexos') &&
                    osData['anexos'] is Map &&
                    osData['anexos'].containsKey(etapaId) &&
                    osData['anexos'][etapaId] is List) {
                  anexosDaOs =
                      (osData['anexos'][etapaId] as List).map((anexoMap) {
                    Anexo anexo = Anexo.fromMap(anexoMap);
                    // Corrigir URL do Storage para cada anexo
                    anexo = Anexo(
                      nome: anexo.nome,
                      url: _corrigirUrlStorage(anexo.url),
                      tipo: anexo.tipo,
                    );
                    return anexo;
                  }).toList();
                }

                // Adicionar à lista de etapas com progresso
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

                    return FutureBuilder<Map<String, bool>>(
                      future:
                          verificarArquivosDeControle(etapa.caminhoPastaEtapa),
                      builder: (context, snapshot) {
                        // Status padrão da etapa
                        String statusFinal = etapa.status;
                        bool mostrarBotaoVisualizar = false;

                        // Se a verificação foi concluída com sucesso
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          // Se tem arquivo .keep, marca como concluído
                          if (snapshot.data!['concluido'] == true) {
                            statusFinal = 'Concluído';
                          }

                          // Se tem arquivo .visivel, mostra botão de visualizar
                          mostrarBotaoVisualizar =
                              snapshot.data!['visivel'] == true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
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
                                        Icon(_getIconForStatus(statusFinal),
                                            color:
                                                _getColorForStatus(statusFinal),
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
                                      child: Text('Status: $statusFinal',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700])),
                                    ),
                                    if (etapa.observacao.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 34, top: 4),
                                        child: Text(
                                            'Observação: ${etapa.observacao}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700])),
                                      ),
                                    const SizedBox(height: 10),

                                    // Anexos da OS para esta etapa
                                    _buildAnexos(etapa.anexos),

                                    // Botão para visualizar documentos da etapa
                                    _buildVisualizarBotao(
                                        mostrarBotaoVisualizar, etapa),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirChat,
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Abrir Chat da OS',
      ),
    );
  }
}

// Classe para visualização de documentos da etapa
class DocumentosEtapaPage extends StatefulWidget {
  final String pasta;
  const DocumentosEtapaPage({Key? key, required this.pasta}) : super(key: key);

  @override
  _DocumentosEtapaPageState createState() => _DocumentosEtapaPageState();
}

class _DocumentosEtapaPageState extends State<DocumentosEtapaPage> {
  late Future<List<Reference>> _futureFiles;
  bool _isLoading = false;
  bool _isDownloading = false;
  String _currentDownloadingFile = '';
  double _downloadProgress = 0.0;
  final Dio _dio = Dio();

  // Mapa para armazenar metadados dos arquivos
  final Map<String, Map<String, dynamic>> _metadataCache = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
    developer.log('Carregando arquivos da pasta: ${widget.pasta}',
        name: 'DocumentosEtapaPage');
  }

  void _loadFiles() {
    setState(() {
      _isLoading = true;
    });

    _futureFiles =
        FirebaseStorage.instance.ref(widget.pasta).listAll().then((result) {
      developer.log('Encontrados ${result.items.length} arquivos',
          name: 'DocumentosEtapaPage');
      return result.items;
    }).catchError((error) {
      developer.log('Erro ao listar arquivos: $error',
          name: 'DocumentosEtapaPage');
      throw error;
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<Map<String, dynamic>> _getFileMetadata(Reference ref) async {
    // Verifica se já temos os metadados em cache
    if (_metadataCache.containsKey(ref.fullPath)) {
      return _metadataCache[ref.fullPath]!;
    }

    try {
      final metadata = await ref.getMetadata();
      final url = await ref.getDownloadURL();

      final result = {
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'updated': metadata.updated,
        'url': url,
      };

      // Armazena em cache
      _metadataCache[ref.fullPath] = result;

      return result;
    } catch (e) {
      developer.log('Erro ao obter metadados: $e', name: 'DocumentosEtapaPage');
      return {
        'size': null,
        'contentType': null,
        'timeCreated': null,
        'updated': null,
        'url': null,
      };
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Tamanho desconhecido';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Data desconhecida';

    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(dateTime);
  }

  IconData _getIconForFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (['pdf'].contains(extension)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']
        .contains(extension)) {
      return Icons.image;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) {
      return Icons.archive;
    } else if (['mp4', 'avi', 'mov', 'wmv'].contains(extension)) {
      return Icons.video_file;
    } else if (['mp3', 'wav', 'ogg', 'aac'].contains(extension)) {
      return Icons.audio_file;
    } else if (['txt', 'rtf', 'md'].contains(extension)) {
      return Icons.text_snippet;
    }

    return Icons.insert_drive_file;
  }

  Future<void> _visualizarArquivo(Reference ref, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Não foi possível abrir o arquivo: ${ref.name}')),
          );
        }
      }
    } catch (e) {
      developer.log('Erro ao abrir URL: $e', name: 'DocumentosEtapaPage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir arquivo: $e')),
        );
      }
    }
  }

  Future<void> _baixarArquivo(Reference ref, String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('URL do arquivo inválida para download.')),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _currentDownloadingFile = ref.name;
      _downloadProgress = 0.0;
    });

    PermissionStatus status;
    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      try {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory();
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        }

        if (dir == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Não foi possível obter o diretório de download.')),
            );
          }
          setState(() {
            _isDownloading = false;
          });
          return;
        }

        String savePath = "${dir.path}/${ref.name}";
        developer.log('Caminho para salvar: $savePath',
            name: 'DocumentosEtapaPage');

        await _dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadProgress = received / total;
              });
              developer.log(
                "Progresso: ${(_downloadProgress * 100).toStringAsFixed(0)}%",
                name: 'DocumentosEtapaPage',
              );
            }
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Download de "${ref.name}" concluído! Salvo em: ${dir.path}'),
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
            name: 'DocumentosEtapaPage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro no download: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0.0;
          });
        }
      }
    } else {
      developer.log('Permissão de armazenamento negada.',
          name: 'DocumentosEtapaPage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Permissão de armazenamento negada para realizar o download.')),
        );
      }
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos da Etapa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    _loadFiles();
                  },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Reference>>(
              future: _futureFiles,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erro: ${snap.error}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFiles,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final files = snap.data!;

                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Nenhum arquivo encontrado nesta etapa.'),
                        const SizedBox(height: 8),
                        Text(
                          'Pasta: ${widget.pasta}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (_, i) {
                        final ref = files[i];

                        // Pula arquivos de controle
                        if (ref.name == '.keep' || ref.name == '.visivel') {
                          return const SizedBox.shrink();
                        }

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getFileMetadata(ref),
                          builder: (context, metadataSnap) {
                            final metadata = metadataSnap.data ?? {};
                            final fileSize = metadata['size'] as int?;
                            final lastModified =
                                metadata['updated'] as DateTime?;
                            final url = metadata['url'] as String?;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                  _getIconForFileType(ref.name),
                                  size: 36,
                                  color: Colors.blue[700],
                                ),
                                title: Text(
                                  ref.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (fileSize != null)
                                      Text(
                                          'Tamanho: ${_formatFileSize(fileSize)}'),
                                    if (lastModified != null)
                                      Text(
                                          'Modificado: ${_formatDateTime(lastModified)}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          color: Colors.blue),
                                      onPressed: url != null
                                          ? () => _visualizarArquivo(ref, url)
                                          : null,
                                      tooltip: 'Visualizar',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.file_download,
                                          color: Colors.green),
                                      onPressed: (_isDownloading || url == null)
                                          ? null
                                          : () => _baixarArquivo(ref, url),
                                      tooltip: 'Baixar',
                                    ),
                                  ],
                                ),
                                onTap: url != null
                                    ? () => _visualizarArquivo(ref, url)
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Indicador de progresso de download
                    if (_isDownloading)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Baixando $_currentDownloadingFile',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: Colors.grey[700],
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
