import 'dart:io';
// Removido import não utilizado: dart:typed_data
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrogeo_brasil_app_main/services/fcm_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderType;
  final Timestamp timestamp;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String type;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.type,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? 'unknown_id',
      senderName: data['senderName'] ?? 'Desconhecido',
      senderType: data['senderType'] ?? 'interno',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      fileUrl: data['fileURL'],
      fileName: data['fileName'],
      fileType: data['fileType'],
      type: data['type'] ?? 'text',
    );
  }
}

class OsChatScreen extends StatefulWidget {
  final String osId;
  final String osTitle;
  final String clienteNome;
  final String nomeFazenda;

  const OsChatScreen({
    super.key,
    required this.osId,
    required this.osTitle,
    required this.clienteNome,
    required this.nomeFazenda,
  });

  @override
  State<OsChatScreen> createState() => _OsChatScreenState();
}

class _OsChatScreenState extends State<OsChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FCMService _fcmService = FCMService();

  // Variáveis para upload de arquivos
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String _uploadProgress = '';

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? "ID_USUARIO_NAO_LOGADO";
  }

  String get _currentUserName {
    return FirebaseAuth.instance.currentUser?.displayName ?? "Usuário App";
  }

  String get _currentUserType => "cliente";

  @override
  void initState() {
    super.initState();

    // Inicializa FCM
    _fcmService.inicializarNotificacoes();

    // Salva token FCM para esta OS (implementação simplificada)
    _salvarTokenParaOS();

    // Marca mensagens como lidas quando o chat é aberto
    _marcarMensagensComoLidas();

    _textController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Método simplificado para salvar token para a OS
  Future<void> _salvarTokenParaOS() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Atualiza a OS para indicar que este usuário está inscrito nas notificações
        await FirebaseFirestore.instance
            .collection('ordensServico')
            .doc(widget.osId)
            .update({
          'usuariosInscritos': FieldValue.arrayUnion([user.uid]),
        });
      }
    } catch (e) {
      // Erro ao salvar token para OS
      debugPrint('Erro ao salvar token para OS: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _marcarMensagensComoLidas() async {
    try {
      // Busca mensagens não lidas enviadas por outros usuários
      // Removendo a condição where("lida", isEqualTo: false) para evitar erro de índice
      final querySnapshot = await FirebaseFirestore.instance
          .collection("ordensServico")
          .doc(widget.osId)
          .collection("mensagens")
          .where("senderId", isNotEqualTo: _currentUserId)
          .get();

      // Marca cada mensagem como lida, mas apenas se não estiver lida
      for (var doc in querySnapshot.docs) {
        // Verifica se a mensagem já está lida antes de atualizar
        if (doc.data()['lida'] != true) {
          await FirebaseFirestore.instance
              .collection("ordensServico")
              .doc(widget.osId)
              .collection("mensagens")
              .doc(doc.id)
              .update({"lida": true});

          // Se existir referência à mensagem global, atualiza lá também
          if (doc.data().containsKey('globalMsgId')) {
            final String? globalMsgId = doc.data()['globalMsgId'] as String?;
            if (globalMsgId != null) {
              await FirebaseFirestore.instance
                  .collection("mensagens")
                  .doc(globalMsgId)
                  .update({"lida": true});
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao marcar mensagens como lidas: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if ((text.trim().isEmpty && _selectedFile == null) || _isUploading) return;

    try {
      setState(() {
        _isUploading = _selectedFile != null;
        _uploadProgress = 'Preparando envio...';
      });

      String? fileURL;
      String? fileName;
      String? fileType;
      String messageType = 'text';

      // Se tiver arquivo selecionado, faz upload
      if (_selectedFile != null) {
        fileName = _selectedFile!.name;
        fileType = _getFileType(fileName);
        messageType = 'file';

        // Cria referência no Storage
        final storageRef = FirebaseStorage.instance.ref().child(
            'clientes/${widget.clienteNome}/fazendas/${widget.nomeFazenda}/${widget.osTitle}/mensagens/$fileName');

        // Inicia upload com monitoramento de progresso
        UploadTask uploadTask;

        if (kIsWeb) {
          // No Flutter Web, usamos bytes em vez de File
          if (_selectedFile!.bytes == null) {
            throw Exception("Arquivo sem dados para upload");
          }
          uploadTask = storageRef.putData(_selectedFile!.bytes!,
              SettableMetadata(contentType: 'application/octet-stream'));
        } else {
          // Em dispositivos móveis, usamos File
          if (_selectedFile!.path == null) {
            throw Exception("Caminho do arquivo não disponível");
          }
          final file = File(_selectedFile!.path!);
          uploadTask = storageRef.putFile(file);
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          if (mounted) {
            setState(() {
              _uploadProgress = 'Enviando: ${progress.toStringAsFixed(1)}%';
            });
          }
        });

        // Aguarda conclusão do upload
        await uploadTask.whenComplete(() {
          if (mounted) {
            setState(() {
              _uploadProgress = 'Upload concluído!';
            });
          }
        });

        // Obtém URL de download
        fileURL = await storageRef.getDownloadURL();
      }

      // Dados da mensagem
      final Map<String, dynamic> messageData = {
        "text": text.trim(),
        "senderId": _currentUserId,
        "senderName": _currentUserName,
        "senderType": _currentUserType,
        "type": messageType,
        "timestamp": Timestamp.now(),
        "lida": true, // Mensagens enviadas pelo próprio usuário já são lidas
      };

      // Adiciona dados do arquivo se existir
      if (fileURL != null) {
        messageData["fileURL"] = fileURL;
        messageData["fileName"] = fileName;
        messageData["fileType"] = fileType;
      }

      // 1. Adiciona na coleção principal de mensagens
      final globalMsgRef =
          await FirebaseFirestore.instance.collection("mensagens").add({
        ...messageData,
        "osId": widget.osId,
        "clienteNome": widget.clienteNome,
        "fazendaNome": widget.nomeFazenda,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2. Adiciona na subcoleção da OS com referência à mensagem global
      await FirebaseFirestore.instance
          .collection("ordensServico")
          .doc(widget.osId)
          .collection("mensagens")
          .add({
        ...messageData,
        "globalMsgId": globalMsgRef.id,
      });

      // 3. Atualiza a OS com a última mensagem
      await FirebaseFirestore.instance
          .collection("ordensServico")
          .doc(widget.osId)
          .update({
        "ultimaMensagemTexto": messageType == 'file'
            ? "[Arquivo] ${fileName ?? 'Anexo'}"
            : text.trim(),
        "ultimaMensagemTimestamp": messageData["timestamp"],
      });

      // Limpa inputs
      _textController.clear();
      if (mounted) {
        setState(() {
          _selectedFile = null;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
      debugPrint("Erro ao enviar mensagem: $e");
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'image';
    } else if (['pdf'].contains(extension)) {
      return 'pdf';
    } else if (['doc', 'docx'].contains(extension)) {
      return 'document';
    } else if (['xls', 'xlsx'].contains(extension)) {
      return 'spreadsheet';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return 'video';
    } else {
      return 'file';
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galeria de Fotos'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Câmera'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Documento'),
                  onTap: () => Navigator.pop(context, 'document'),
                ),
              ],
            ),
          );
        },
      );

      if (result == null) return;

      FilePickerResult? pickerResult;

      // Usar FilePicker para todos os tipos de arquivo
      if (result == 'gallery') {
        pickerResult = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: kIsWeb, // Importante para Web: carrega os bytes
        );
      } else if (result == 'camera') {
        // Não podemos usar câmera diretamente no Web
        if (kIsWeb) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Função de câmera não disponível no navegador. Por favor, use a galeria.')),
          );
          return;
        } else {
          // Em dispositivos móveis, usamos FilePicker para imagens
          pickerResult = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: kIsWeb,
          );
        }
      } else if (result == 'document') {
        pickerResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
          withData: kIsWeb, // Importante para Web: carrega os bytes
        );
      }

      if (pickerResult != null && pickerResult.files.isNotEmpty) {
        setState(() {
          _selectedFile = pickerResult!.files.first;
        });
      }
    } catch (e) {
      debugPrint("Erro ao selecionar arquivo: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
      );
    }
  }

  Future<void> _openFile(String url, String fileName) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o arquivo $fileName')),
        );
      }
    } catch (e) {
      debugPrint("Erro ao abrir arquivo: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir arquivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.osTitle,
            style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("ordensServico")
                  .doc(widget.osId)
                  .collection("mensagens")
                  .orderBy("timestamp", descending: false)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("Nenhuma mensagem ainda. Seja o primeiro!"));
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10.0),
                  children:
                      snapshot.data!.docs.map((DocumentSnapshot document) {
                    ChatMessage message = ChatMessage.fromFirestore(document);
                    return _buildMessageBubble(message);
                  }).toList(),
                );
              },
            ),
          ),
          if (_isUploading)
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: Colors.amber[100],
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadProgress,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _isUploading = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          if (_selectedFile != null && !_isUploading)
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(_selectedFile!.name),
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Arquivo: ${_selectedFile!.name.length > 20 ? _selectedFile!.name.substring(0, 20) + "..." : _selectedFile!.name}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickFile,
                    color: Colors.grey[700],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _selectedFile != null
                            ? "Adicione um comentário ao arquivo..."
                            : "Digite uma mensagem...",
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      minLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _textController.text.trim().isNotEmpty ||
                            _selectedFile != null
                        ? () => _sendMessage(_textController.text)
                        : null,
                    color: _textController.text.trim().isNotEmpty ||
                            _selectedFile != null
                        ? Colors.green
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final fileType = _getFileType(fileName);

    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'video':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isMe = message.senderId == _currentUserId;
    final bool isFile = message.type == 'file';
    final bool isImage = isFile && message.fileType == 'image';

    final time = DateFormat('HH:mm').format(message.timestamp.toDate());

    // Determina a cor do nome do remetente
    final Color nameColor = isMe ? Colors.green[700]! : Colors.blue[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Color.fromARGB(
                  204, nameColor.red, nameColor.green, nameColor.blue),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.green[100] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 12.0, right: 12.0, top: 8.0, bottom: 0),
                      child: Text(
                        // Limitar o nome para evitar problemas de ellipsis
                        message.senderName.length > 20
                            ? message.senderName.substring(0, 20)
                            : message.senderName,
                        style: TextStyle(
                          color: nameColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  if (isImage && message.fileUrl != null)
                    GestureDetector(
                      onTap: () => _openFile(
                          message.fileUrl!, message.fileName ?? 'imagem.jpg'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          message.fileUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.red),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (isFile && !isImage && message.fileUrl != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () => _openFile(
                            message.fileUrl!, message.fileName ?? 'arquivo'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(message.fileName ?? ''),
                                color: Colors.blue[700],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Usando interpolação de string
                                    Text(
                                      message.fileName != null &&
                                              message.fileName!.length > 15
                                          ? '${message.fileName!.substring(0, 15)}...'
                                          : message.fileName ?? 'Arquivo',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Toque para abrir',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        message.text,
                        style: const TextStyle(fontSize: 16),
                        maxLines: 20,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12.0, right: 12.0, bottom: 8.0, top: 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
