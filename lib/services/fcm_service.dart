// lib/services/fcm_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/os_chat.dart'; // Ajuste o caminho se necessário
import '../main.dart'; // Deve conter navigatorKey

class FCMService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Plugin de notificações locais
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Solicita permissão de notificação (Android 13+ e iOS)
  Future<void> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permissão de notificação concedida');
    } else {
      debugPrint('🚫 Permissão de notificação negada');
    }
  }

  /// Salva o token FCM no Firestore
  Future<void> salvarToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore
          .collection('dispositivosTokens')
          .doc(user.uid)
          .set({'token': token}, SetOptions(merge: true));
      debugPrint('🔐 Token FCM salvo com sucesso: $token');
    }
  }

  /// Inicializa notificações FCM e locais
  Future<void> inicializarNotificacoes() async {
    await requestPermission();
    await salvarToken();
    await _configurarNotificacoesLocais();
    _ouvirMensagens();
  }

  /// Configura notificações locais para foreground
  Future<void> _configurarNotificacoesLocais() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _localNotifications.initialize(initSettings);
  }

  /// Escuta mensagens em tempo real e redirecionamento por clique
  void _ouvirMensagens() {
    // Quando app está aberto (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notificacao = message.notification;
      if (notificacao != null && notificacao.title != null) {
        _exibirNotificacaoLocal(
          titulo: notificacao.title!,
          corpo: notificacao.body ?? '',
        );
      }
    });

    // Quando app é aberto por uma notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 App aberto por notificação');
      final data = message.data;
      final osId = data['osId'];
      final osTitle = data['osTitle'];

      if (osId != null && osTitle != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => OsChatScreen(
              osId: osId,
              osTitle: osTitle,
              clienteNome: 'Cliente', // Se tiver nome real, substitua aqui
              nomeFazenda: 'Fazenda', // Idem
            ),
          ),
        );
      } else {
        debugPrint(
            '⚠️ Dados insuficientes na notificação para redirecionamento.');
      }
    });
  }

  /// Exibe uma notificação local
  Future<void> _exibirNotificacaoLocal({
    required String titulo,
    required String corpo,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_os_channel',
      'Notificações de Chat',
      channelDescription: 'Mensagens enviadas nas Ordens de Serviço',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      corpo,
      notificationDetails,
    );
  }
}
