import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrogeo_brasil_app_main/services/fcm_service.dart'; // Adicionado import do FCMService

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderType;
  final Timestamp timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderType,
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
    FCMService()
        .inicializarNotificacoes(); // Adicionada inicialização do FCMService

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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final messageData = {
      "text": text.trim(),
      "senderId": _currentUserId,
      "senderName": _currentUserName,
      "senderType": _currentUserType,
      "type": "text",
      "timestamp": Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection("ordensServico")
        .doc(widget.osId)
        .collection("mensagens")
        .add(messageData);

    _textController.clear();
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
                Text(message.text,
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

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: "Digite uma mensagem...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          if (_textController.text.trim().isNotEmpty)
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: () => _sendMessage(_textController.text.trim()),
              tooltip: "Enviar mensagem",
              iconSize: 30,
            ),
        ],
      ),
    );
  }
}
