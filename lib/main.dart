// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/painel_page.dart';
import 'screens/os_chat.dart';
import 'services/fcm_service.dart';

/// Chave global para navegação fora do contexto de widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handler para mensagens recebidas em background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('⚠️ Firebase já inicializado (background): $e');
  }

  print('🔔 Mensagem recebida em background: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('⚠️ Firebase já inicializado: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AgroGeoApp());
}

class AgroGeoApp extends StatefulWidget {
  const AgroGeoApp({super.key});

  @override
  State<AgroGeoApp> createState() => _AgroGeoAppState();
}

class _AgroGeoAppState extends State<AgroGeoApp> {
  @override
  void initState() {
    super.initState();

    // Inicializa notificações FCM (permissão, token, listeners)
    FCMService().inicializarNotificacoes();

    // Quando app está aberto e recebe notificação
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('📲 Notificação foreground: ${message.notification!.title}');
      }
    });

    // Quando o app é aberto ao tocar na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final osId = message.data['osId'];
      final osTitle = message.data['osTitle'];

      if (osId != null && osTitle != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => OsChatScreen(
              osId: osId,
              osTitle: osTitle,
              clienteNome: 'Cliente', // Substituir se tiver dados reais
              nomeFazenda: 'Fazenda',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGROGEO BRASIL',
      navigatorKey: navigatorKey, // Necessário para navegação global
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF0FFF0),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48.0,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          titleLarge: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const PainelPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
