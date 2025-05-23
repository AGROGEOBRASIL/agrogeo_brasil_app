// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart'; // Gerado pelo FlutterFire CLI
import 'screens/login_page.dart'; // Verifique se o caminho está correto
import 'screens/painel_page.dart'; // Verifique se o caminho está correto
import 'screens/os_chat.dart'; // Verifique se o caminho está correto
import 'services/fcm_service.dart'; // Verifique se o caminho está correto

/// Chave global para navegação fora do contexto de widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handler para mensagens recebidas em background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Garante que os bindings do Flutter estejam inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase para o handler de background.
  // É importante ter isso caso a app não esteja rodando quando a mensagem chega.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase pode já estar inicializado se outro handler de background rodou antes.
    // Erro de inicialização do Firebase (background handler)
  }

  // Mensagem recebida em background
  // Aqui você pode adicionar lógica para processar a mensagem em background,
  // como salvar dados localmente ou agendar uma notificação local se necessário.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase para o app principal (agrogeo-brasil-app)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Pode acontecer em alguns cenários de hot restart/reload, mas geralmente não em produção.
    // Erro de inicialização do Firebase (main)
  }

  // Registra o handler para mensagens FCM em background.
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

    // Inicializa o serviço de FCM para permissões, token e listeners foreground.
    FCMService()
        .inicializarNotificacoes(); // Certifique-se que FCMService está implementado corretamente

    // Listener para mensagens FCM recebidas enquanto o app está em primeiro plano.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Notificação recebida em primeiro plano
      if (message.notification != null) {
        // Título e corpo da notificação recebidos
        // Aqui você pode exibir uma notificação local (snackbar, dialog, etc.)
        // já que o sistema não mostra notificações heads-up automaticamente para apps em foreground.
      }
    });

    // Listener para quando o usuário toca em uma notificação e abre o app (se estava em background/terminado).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // App aberto via notificação
      final osId = message.data['osId'];
      final osTitle = message.data[
          'osTitle']; // Você mencionou osTitle, mas não está no seu exemplo de payload da CF.
      // Ajuste conforme a payload real da sua CF.

      // Exemplo de navegação para uma tela específica da OS
      if (osId != null) {
        // Adicione os dados que você realmente precisa para a tela OsChatScreen
        // Os valores 'Cliente' e 'Fazenda' são placeholders.
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => OsChatScreen(
              osId: osId,
              osTitle: osTitle ??
                  "Detalhes da OS", // Use um título padrão se não vier
              clienteNome: message.data['clienteNome'] ??
                  'Cliente', // Exemplo, ajuste conforme sua payload
              nomeFazenda: message.data['nomeFazenda'] ??
                  'Fazenda', // Exemplo, ajuste conforme sua payload
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
      navigatorKey: navigatorKey,
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
          // Usuário está logado
          return const PainelPage(); // Ou sua HomePage/Dashboard principal
        } else {
          // Usuário não está logado
          return const LoginPage();
        }
      },
    );
  }
}

// Nota: Certifique-se de que os caminhos de import para 'screens' e 'services'
// estão corretos conforme a estrutura do seu projeto.
