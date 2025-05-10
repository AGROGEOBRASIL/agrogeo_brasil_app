import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart'; // Para formatar a hora da mensagem e data no path
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderType;
  final String type;
  final String? audioUrl;
  final Timestamp timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.type,
    this.audioUrl,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? 'unknown_id',
      senderName: data['senderName'] ?? 'Desconhecido',
      senderType: data['senderType'] ?? 'interno',
      type: data['type'] ?? 'text',
      audioUrl: data['audioUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  String? _currentlyPlayingUrl;
  PlayerState _playerState = PlayerState.stopped;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

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
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _audioDuration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _audioPosition = newPosition);
    });
    _textController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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

  Future<void> _sendMessage(String text,
      {String type = "text", String? audioUrl}) async {
    if (text.trim().isEmpty && type == "text") return;

    final messageData = {
      "text": text.trim(),
      "senderId": _currentUserId,
      "senderName": _currentUserName,
      "senderType": _currentUserType,
      "type": type,
      "audioUrl": audioUrl,
      "timestamp": Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection("ordensServico")
        .doc(widget.osId)
        .collection("mensagens")
        .add(messageData);

    if (type == "text") {
      _textController.clear();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndUpload();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        if (kIsWeb) {
          // CORREÇÃO: Usar AudioEncoder.opus para web.
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.opus),
            path: "", // Path é ignorado para web, mas o parâmetro é necessário
          );
          _recordingPath = null;
          print("[Web] Iniciada gravação para blob com Opus.");
        } else {
          final directory = await getApplicationDocumentsDirectory();
          _recordingPath =
              "${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
          await _audioRecorder.start(
              const RecordConfig(encoder: AudioEncoder.aacLc),
              path: _recordingPath!);
          print("[Mobile] Iniciada gravação para o caminho: $_recordingPath");
        }
        if (mounted) setState(() => _isRecording = true);
      } else {
        print("Permissão de microfone negada.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permissão de microfone negada.")),
          );
        }
      }
    } catch (e) {
      print("Erro ao iniciar gravação: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao iniciar gravação: $e")),
        );
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    if (!_isRecording) return;

    final String? recordPathOrUrl = await _audioRecorder.stop();
    if (mounted) setState(() => _isRecording = false);

    if (recordPathOrUrl == null) {
      print("Gravação parada, mas nenhum caminho/URL foi retornado.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Falha ao obter o áudio gravado.")),
        );
      }
      return;
    }

    print("Gravação parada. Caminho/URL: $recordPathOrUrl");

    final fileName =
        "audio_${DateTime.now().millisecondsSinceEpoch}${kIsWeb ? '.webm' : '.m4a'}";

    // CORREÇÃO: Ajustar o storagePath conforme a estrutura de pastas do AGROGEO BRASIL
    final String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final storagePath =
        "clientes/${widget.clienteNome}/fazendas/${widget.nomeFazenda}/${widget.osTitle} $currentDate/chat_audios/$fileName";

    try {
      String downloadUrl;
      if (kIsWeb) {
        print("[Web] Buscando dados de áudio da URL do blob: $recordPathOrUrl");
        final response = await http.get(Uri.parse(recordPathOrUrl));
        if (response.statusCode == 200) {
          final audioBytes = response.bodyBytes;
          print(
              "[Web] Dados de áudio buscados (${audioBytes.length} bytes). Fazendo upload para o Storage...");
          // ContentType para web (Opus gravado é geralmente em WebM)
          UploadTask uploadTask = FirebaseStorage.instance
              .ref(storagePath)
              .putData(audioBytes, SettableMetadata(contentType: 'audio/webm'));
          TaskSnapshot snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
          print("[Web] Áudio enviado. URL: $downloadUrl");
        } else {
          throw Exception(
              "Falha ao buscar dados do áudio da URL do blob: ${response.statusCode}");
        }
      } else {
        final audioFile = File(recordPathOrUrl);
        if (!await audioFile.exists()) {
          print(
              "[Mobile] Arquivo de áudio não existe no caminho: $recordPathOrUrl");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Arquivo de áudio gravado não encontrado.")),
            );
          }
          return;
        }
        print(
            "[Mobile] Fazendo upload do arquivo de áudio de: $recordPathOrUrl");
        // ContentType para mobile (AAC gravado é em m4a)
        UploadTask uploadTask = FirebaseStorage.instance
            .ref(storagePath)
            .putFile(audioFile, SettableMetadata(contentType: 'audio/m4a'));
        TaskSnapshot snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
        print(
            "[Mobile] Áudio enviado. URL: $downloadUrl. Deletando arquivo local...");
        await audioFile.delete();
        print("[Mobile] Arquivo local deletado.");
      }

      await _sendMessage("Mensagem de áudio",
          type: "audio", audioUrl: downloadUrl);
    } catch (e) {
      print("Erro ao enviar áudio: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar áudio: $e")),
        );
      }
    }
    _recordingPath = null;
  }

  Future<void> _playAudio(String url) async {
    if (_currentlyPlayingUrl == url && _playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else if (_currentlyPlayingUrl == url &&
        _playerState == PlayerState.paused) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.stop();
      try {
        await _audioPlayer.play(UrlSource(url));
        if (mounted) setState(() => _currentlyPlayingUrl = url);
      } catch (e) {
        print("Erro ao reproduzir áudio: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao reproduzir áudio: $e")),
          );
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
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
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isMyMessage = message.senderType == _currentUserType;
    final alignment =
        isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMyMessage ? Colors.green[600] : Colors.white;
    final textColor = isMyMessage ? Colors.white : Colors.black87;
    final nameColor = isMyMessage ? Colors.white70 : Colors.black54;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18.0),
      topRight: const Radius.circular(18.0),
      bottomLeft: Radius.circular(isMyMessage ? 18.0 : 4.0),
      bottomRight: Radius.circular(isMyMessage ? 4.0 : 18.0),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
                left: isMyMessage ? 0 : 12.0,
                right: isMyMessage ? 12.0 : 0,
                bottom: 2),
            child: Text(message.senderName,
                style: TextStyle(fontSize: 12.0, color: nameColor)),
          ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
                color: color,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ]),
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                message.type == "audio" && message.audioUrl != null
                    ? _buildAudioPlayer(message.audioUrl!, isMyMessage)
                    : Text(message.text,
                        style: TextStyle(fontSize: 16.0, color: textColor)),
                const SizedBox(height: 4.0),
                Text(
                  DateFormat('HH:mm').format(message.timestamp.toDate()),
                  style: TextStyle(
                      fontSize: 10.0, color: nameColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(String url, bool isMyMessage) {
    final bool isCurrentlyPlayingThisAudio = _currentlyPlayingUrl == url;
    final iconColor = isMyMessage ? Colors.white : Colors.black54;
    final progressColor = isMyMessage ? Colors.white70 : Colors.black38;

    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              isCurrentlyPlayingThisAudio && _playerState == PlayerState.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: iconColor,
              size: 30.0,
            ),
            onPressed: () => _playAudio(url),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCurrentlyPlayingThisAudio)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: progressColor,
                      inactiveTrackColor: progressColor.withOpacity(0.3),
                      trackHeight: 2.0,
                      thumbColor: progressColor,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayColor: progressColor.withAlpha(0x29),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12.0),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: _audioDuration.inMilliseconds.toDouble() > 0
                          ? _audioDuration.inMilliseconds.toDouble()
                          : 1.0,
                      value: _audioPosition.inMilliseconds.toDouble().clamp(
                          0.0,
                          _audioDuration.inMilliseconds.toDouble() > 0
                              ? _audioDuration.inMilliseconds.toDouble()
                              : 1.0),
                      onChanged: (value) async {
                        final position = Duration(milliseconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    isCurrentlyPlayingThisAudio
                        ? "${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}"
                        : _formatDuration(Duration.zero),
                    style: TextStyle(
                        fontSize: 10.0, color: iconColor.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.3),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, -2),
        ),
      ]),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                    hintText: "Digite uma mensagem...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0)),
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(text),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          _isRecording
              ? IconButton(
                  icon: const Icon(Icons.stop_circle,
                      color: Colors.red, size: 30),
                  onPressed: _toggleRecording,
                )
              : IconButton(
                  icon: Icon(
                    _textController.text.isEmpty ? Icons.mic : Icons.send,
                    color: Theme.of(context).primaryColor,
                    size: 30,
                  ),
                  onPressed: _textController.text.isEmpty
                      ? _toggleRecording
                      : () => _sendMessage(_textController.text),
                ),
        ],
      ),
    );
  }
}
