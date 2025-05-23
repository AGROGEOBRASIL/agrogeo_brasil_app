// lib/screens/painel_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

// **** MODIFICADO: Importa a tela correta ****
import 'fazenda_departamentos_page.dart';

// --- Placeholder Model (Use your actual Imovel model) ---
class Imovel {
  final String id;
  final String nomeFazenda; // Confirmed field name from user's text file

  Imovel({required this.id, required this.nomeFazenda});

  factory Imovel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    // Use 'nomeFazenda' as confirmed from the text file
    return Imovel(
      id: doc.id,
      nomeFazenda: data['nomeFazenda'] ?? 'Nome Indisponível',
    );
  }
}
// --- End Placeholder Model ---

class PainelPage extends StatefulWidget {
  const PainelPage({super.key});

  @override
  State<PainelPage> createState() => _PainelPageState();
}

class _PainelPageState extends State<PainelPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _displayUserName = ""; // For display (e.g., first name)
  String? _fullUserName; // For query (full name from prefs)
  Stream<List<Imovel>>? _fazendasStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndSetupStream();
  }

  Future<void> _loadUserDataAndSetupStream() async {
    setState(() {
      _isLoading = true;
    });
    developer.log("Iniciando carregamento de dados...", name: "PainelPage");
    try {
      final prefs = await SharedPreferences.getInstance();
      _fullUserName = prefs.getString('clienteNome');
      _displayUserName = _fullUserName?.split(' ').first ?? "Cliente";

      developer.log("Nome completo carregado para query: $_fullUserName",
          name: "PainelPage");
      developer.log("Nome para exibição: $_displayUserName",
          name: "PainelPage");

      if (_fullUserName != null && _fullUserName!.isNotEmpty) {
        developer.log(
            "Configurando stream para coleção principal 'fazendas' onde 'cliente' == $_fullUserName",
            name: "PainelPage");
        _fazendasStream = _firestore
            .collection('fazendas')
            .where('cliente', isEqualTo: _fullUserName)
            .snapshots()
            .map((snapshot) {
          developer.log(
              "Recebido snapshot da coleção 'fazendas'. Docs: ${snapshot.docs.length}",
              name: "PainelPage");
          if (snapshot.docs.isEmpty) {
            developer.log(
                "Nenhum documento encontrado na coleção 'fazendas' para o cliente '$_fullUserName'.",
                name: "PainelPage");
          }
          return snapshot.docs.map((doc) {
            developer.log("Mapeando doc fazenda: ${doc.id} -> ${doc.data()}",
                name: "PainelPage");
            return Imovel.fromFirestore(doc);
          }).toList();
        }).handleError((error) {
          developer.log("Erro no stream de fazendas: $error",
              name: "PainelPage");
          // Retorna lista vazia em caso de erro para não quebrar o StreamBuilder
          return <Imovel>[];
        });
      } else {
        developer.log(
            "Nome completo do cliente nulo ou vazio. Nenhuma fazenda será carregada.",
            name: "PainelPage");
        _displayUserName = "Visitante";
        _fazendasStream = Stream.value([]); // Emite lista vazia
      }
    } catch (e) {
      developer.log(
          "Erro ao carregar dados do SharedPreferences ou configurar stream: $e",
          name: "PainelPage");
      _displayUserName = "Erro";
      _fazendasStream = Stream.error(e); // Propaga o erro para o StreamBuilder
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        developer.log("Carregamento inicial concluído.", name: "PainelPage");
      }
    }
  }

  Future<void> _logout() async {
    developer.log("Iniciando logout...", name: "PainelPage");
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('clienteDocId');
      await prefs.remove('clienteNome');
      developer.log(
          "Logout bem-sucedido. Navegando para Login (via AuthWrapper).",
          name: "PainelPage");
      // O AuthWrapper cuidará da navegação
    } catch (e) {
      developer.log("Erro ao fazer logout: $e", name: "PainelPage");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao sair. Tente novamente.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // **** ADICIONADO/CORRIGIDO: Função para navegar para a tela de Departamentos da Fazenda ****
  void _navegarParaFazendaDepartamentos(String nomeFazenda) {
    if (_fullUserName == null) {
      developer.log(
          "Erro: Nome completo do cliente não disponível para navegação.",
          name: "PainelPage");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao obter dados do cliente.')),
      );
      return;
    }
    developer.log(
        'Navegando para Fazenda Departamentos: Cliente=$_fullUserName, Fazenda=$nomeFazenda',
        name: "PainelPage");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FazendaDepartamentosPage(
          nomeCliente: _fullUserName!, // Passa o nome completo usado na query
          nomeFazenda: nomeFazenda,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color topGradientColor = Color(0xFFB3E5FC);
    const Color bottomGradientColor = Color(0xFFC8E6C9);
    const Color agrogeoGreen = Color(0xFF388E3C);
    const Color brasilYellow = Color(0xFFFFD600);
    const Color cardBackground = Colors.white;
    const Color textColor = Colors.black87;
    const Color plantColor = agrogeoGreen; // Definição mantida e correta

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: agrogeoGreen),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topGradientColor, bottomGradientColor],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: 20.0, bottom: 20.0, left: 20.0, right: 20.0),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            height: 1.1),
                        children: [
                          TextSpan(
                              text: 'AGROGEO\n',
                              style: TextStyle(color: agrogeoGreen)),
                          TextSpan(
                              text: 'BRASIL',
                              style: TextStyle(color: brasilYellow)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator(color: agrogeoGreen)
                        : Text(
                            'Bem-vindo, $_displayUserName',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: textColor),
                          ),
                  ],
                ),
              ),
              // --- Fazendas List Section ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: agrogeoGreen))
                      : StreamBuilder<List<Imovel>>(
                          stream: _fazendasStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _fazendasStream != null) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: agrogeoGreen));
                            }
                            if (snapshot.hasError) {
                              return Center(
                                  child: Text(
                                      'Erro ao carregar fazendas: ${snapshot.error}',
                                      textAlign: TextAlign.center));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: cardBackground.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                      'Nenhuma fazenda encontrada.',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              );
                            }

                            final fazendas = snapshot.data!;

                            return ListView.builder(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 20),
                              itemCount: fazendas.length,
                              itemBuilder: (context, index) {
                                final fazenda = fazendas[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Material(
                                    color: cardBackground,
                                    borderRadius: BorderRadius.circular(30),
                                    elevation: 4.0,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(30),
                                      // **** MODIFICADO: onTap agora navega para FazendaDepartamentosPage ****
                                      onTap: () =>
                                          _navegarParaFazendaDepartamentos(
                                              fazenda.nomeFazenda),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical:
                                                16.0, // Padding vertical original
                                            horizontal: 16.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .center, // Centraliza o nome
                                          children: [
                                            // Nome da Fazenda
                                            Expanded(
                                              child: Text(
                                                fazenda.nomeFazenda,
                                                textAlign: TextAlign
                                                    .center, // Centraliza o texto
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // **** REMOVIDO: IconButton de dashboard ****
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              // --- Bottom Plant Decoration ---
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Icon(
                  Icons.local_florist,
                  color: plantColor.withOpacity(0.8),
                  size: 50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
