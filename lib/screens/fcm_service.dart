import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Canal de notificação para Android
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'chat_messages_channel',
    'Mensagens de Chat',
    description: 'Notificações de novas mensagens no chat',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  // Inicializa as notificações
  Future<void> inicializarNotificacoes() async {
    // Solicita permissão para notificações
    await _solicitarPermissoes();

    // Configura canais de notificação para Android
    await _configurarCanaisAndroid();

    // Configura handlers para mensagens
    _configurarHandlersMensagens();

    // Obtém e salva o token FCM
    await _obterESalvarToken();
  }

  // Solicita permissões para notificações
  Future<void> _solicitarPermissoes() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Permissão de notificação: ${settings.authorizationStatus}');

      // Configura notificações em primeiro plano no iOS
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Erro ao solicitar permissões: $e');
    }
  }

  // Configura canais de notificação para Android
  Future<void> _configurarCanaisAndroid() async {
    try {
      // Inicializa plugin de notificações locais
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Tratamento para quando o usuário toca na notificação
          debugPrint('Notificação tocada: ${response.payload}');
          _processarPayloadNotificacao(response.payload);
        },
      );

      // Cria canal de notificação no Android
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      debugPrint('Erro ao configurar canais Android: $e');
    }
  }

  // Configura handlers para mensagens FCM
  void _configurarHandlersMensagens() {
    // Handler para mensagens em primeiro plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          'Mensagem recebida em primeiro plano: ${message.notification?.title}');
      _mostrarNotificacaoLocal(message);
    });

    // Handler para mensagens em segundo plano que são clicadas
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          'Mensagem aberta em segundo plano: ${message.notification?.title}');
      _processarMensagemClicada(message);
    });

    // Verificar mensagens iniciais (quando o app é aberto a partir de uma notificação)
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('Mensagem inicial: ${message.notification?.title}');
        _processarMensagemClicada(message);
      }
    });
  }

  // Obtém e salva o token FCM
  Future<void> _obterESalvarToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('Token FCM: $token');
        await _salvarTokenNoFirestore(token);
      }

      // Listener para atualizações de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('Token FCM atualizado: $newToken');
        _salvarTokenNoFirestore(newToken);
      });
    } catch (e) {
      debugPrint('Erro ao obter token FCM: $e');
    }
  }

  // Salva o token no Firestore
  Future<void> _salvarTokenNoFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'ultimaAtualizacaoToken': FieldValue.serverTimestamp(),
          'plataforma':
              kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        }, SetOptions(merge: true));

        // Salva localmente também
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', token);
      }
    } catch (e) {
      debugPrint('Erro ao salvar token no Firestore: $e');
    }
  }

  // Salva o token para uma OS específica
  Future<void> salvarTokenParaOS(String osId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          // Registra o token para esta OS específica
          await FirebaseFirestore.instance
              .collection('ordensServico')
              .doc(osId)
              .collection('tokens')
              .doc(user.uid)
              .set({
            'token': token,
            'userId': user.uid,
            'userName': user.displayName ?? 'Usuário App',
            'ultimaAtualizacao': FieldValue.serverTimestamp(),
            'plataforma':
                kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
          });

          // Também atualiza a OS para indicar que este usuário está inscrito nas notificações
          await FirebaseFirestore.instance
              .collection('ordensServico')
              .doc(osId)
              .update({
            'usuariosInscritos': FieldValue.arrayUnion([user.uid]),
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar token para OS: $e');
    }
  }

  // Mostra notificação local a partir de uma mensagem FCM
  Future<void> _mostrarNotificacaoLocal(RemoteMessage message) async {
    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Verifica se é uma notificação válida e estamos no Android
      if (notification != null && android != null && !kIsWeb) {
        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? 'mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'Nova mensagem',
              color: Colors.green,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: json.encode(message.data),
        );
      }
      // Para iOS ou quando não há notificação Android específica
      else if (notification != null && !kIsWeb) {
        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: json.encode(message.data),
        );
      }
    } catch (e) {
      debugPrint('Erro ao mostrar notificação local: $e');
    }
  }

  // Processa mensagem quando o usuário clica na notificação
  void _processarMensagemClicada(RemoteMessage message) {
    try {
      if (message.data.isNotEmpty) {
        _processarPayloadNotificacao(json.encode(message.data));
      }
    } catch (e) {
      debugPrint('Erro ao processar mensagem clicada: $e');
    }
  }

  // Processa o payload da notificação
  void _processarPayloadNotificacao(String? payload) {
    try {
      if (payload != null) {
        final data = json.decode(payload) as Map<String, dynamic>;

        // Salva informações da OS para navegação
        if (data.containsKey('osId')) {
          _salvarOsParaNavegacao(data);
        }
      }
    } catch (e) {
      debugPrint('Erro ao processar payload da notificação: $e');
    }
  }

  // Salva informações da OS para navegação posterior
  Future<void> _salvarOsParaNavegacao(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Salva o ID da OS para navegação
      if (data.containsKey('osId')) {
        await prefs.setString('notificacao_osId', data['osId']);
      }

      // Salva outras informações úteis
      if (data.containsKey('osTitle')) {
        await prefs.setString('notificacao_osTitle', data['osTitle']);
      }

      if (data.containsKey('clienteNome')) {
        await prefs.setString('notificacao_clienteNome', data['clienteNome']);
      }

      if (data.containsKey('nomeFazenda')) {
        await prefs.setString('notificacao_nomeFazenda', data['nomeFazenda']);
      }

      // Marca que há uma notificação pendente
      await prefs.setBool('temNotificacaoPendente', true);
    } catch (e) {
      debugPrint('Erro ao salvar OS para navegação: $e');
    }
  }

  // Verifica e processa notificações pendentes
  Future<Map<String, String>?>
      verificarEProcessarNotificacoesPendentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final temNotificacao = prefs.getBool('temNotificacaoPendente') ?? false;

      if (temNotificacao) {
        final osId = prefs.getString('notificacao_osId');
        final osTitle = prefs.getString('notificacao_osTitle');
        final clienteNome = prefs.getString('notificacao_clienteNome');
        final nomeFazenda = prefs.getString('notificacao_nomeFazenda');

        // Limpa as notificações pendentes
        await prefs.setBool('temNotificacaoPendente', false);
        await prefs.remove('notificacao_osId');
        await prefs.remove('notificacao_osTitle');
        await prefs.remove('notificacao_clienteNome');
        await prefs.remove('notificacao_nomeFazenda');

        if (osId != null) {
          return {
            'osId': osId,
            'osTitle': osTitle ?? 'Ordem de Serviço',
            'clienteNome': clienteNome ?? 'Cliente',
            'nomeFazenda': nomeFazenda ?? 'Fazenda',
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('Erro ao verificar notificações pendentes: $e');
      return null;
    }
  }

  // Método para obter o token FCM atual
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}
