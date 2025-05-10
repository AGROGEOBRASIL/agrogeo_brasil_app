// lib/utils/fazendas_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; // <--- ADICIONADO ESTE IMPORT

// Import da nova tela de Departamentos OS
import '../screens/departamentos_os_page.dart'; // Ajustado path relativo
// Import da tela de detalhes (se existir)
// import '../screens/fazenda_detalhes_page.dart';

class FazendasPage extends StatefulWidget {
  final String nomeCliente;

  const FazendasPage(this.nomeCliente, {super.key});

  @override
  State<FazendasPage> createState() => _FazendasPageState();
}

class _FazendasPageState extends State<FazendasPage> {
  List<String> pastasFazendas = [];
  String fazendaSelecionada = '';
  bool carregando = true;
  bool enviando = false;
  bool mostrandoFormulario = false;
  final TextEditingController _nomeFazendaCtrl =
      TextEditingController(); // Mantido caso use no futuro
  final TextEditingController _municipioCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    carregarPastasFazendas();
  }

  Future<void> carregarPastasFazendas() async {
    final storage = FirebaseStorage.instance;
    final refCliente = storage.ref('clientes/${widget.nomeCliente}/fazendas');
    try {
      final pastas = await refCliente.listAll();
      // Verifica se o widget ainda está montado antes de chamar setState
      if (!mounted) return;
      setState(() {
        pastasFazendas = pastas.prefixes.map((p) => p.name).toList();
        carregando = false;
      });
    } catch (e) {
      // Verifica se o widget ainda está montado antes de chamar setState
      if (!mounted) return;
      setState(() {
        carregando = false;
      });
      print(
          'Erro ao carregar pastas: $e'); // Manter print para debug temporário
    }
  }

  void abrirFormulario(String nomeFazenda) {
    setState(() {
      fazendaSelecionada = nomeFazenda;
      mostrandoFormulario = true;
    });
  }

  Future<void> enviarDocumento() async {
    // final firestore = FirebaseFirestore.instance; // Variável não usada

    // Usar o contexto antes do await se possível, ou verificar if (mounted) depois
    final contextBeforeAwait = context;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles();
    } catch (e) {
      print("Erro ao abrir FilePicker: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(contextBeforeAwait).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir seletor de arquivos.')),
      );
      return;
    }

    if (picked?.files.isEmpty ?? true) return;

    final file = picked!.files.first;
    final fileBytes = file.bytes;
    final fileName = file.name;

    if (fileBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(contextBeforeAwait).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível ler o arquivo selecionado.')),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref(
          'clientes/${widget.nomeCliente}/fazendas/$fazendaSelecionada/$fileName');
      await ref.putData(fileBytes);

      // Verificar se o widget ainda está montado antes de usar o context
      if (!mounted) return;
      ScaffoldMessenger.of(contextBeforeAwait).showSnackBar(
        // Usar contexto salvo
        const SnackBar(content: Text('✅ Documento enviado com sucesso!')),
      );
    } catch (e) {
      print(e); // Manter print para debug temporário
      // Verificar se o widget ainda está montado antes de usar o context
      if (!mounted) return;
      ScaffoldMessenger.of(contextBeforeAwait).showSnackBar(
        // Usar contexto salvo
        const SnackBar(content: Text('❌ Erro ao enviar o documento.')),
      );
    }

    // Verificar se o widget ainda está montado antes de usar setState
    if (mounted) {
      setState(() => enviando = false);
    }
  }

  // Função para navegar para a tela de Departamentos OS
  void _navegarParaDepartamentos(String nomeFazenda) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartamentosOsPage(
          nomeCliente: widget.nomeCliente,
          nomeFazenda: nomeFazenda,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fazendas de ${widget.nomeCliente}'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (pastasFazendas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Nenhuma fazenda encontrada."),
                  ),
                Expanded(
                  // Adicionado Expanded para a lista rolar
                  child: ListView.builder(
                    itemCount: pastasFazendas.length,
                    itemBuilder: (context, index) {
                      final nome = pastasFazendas[index];
                      return ListTile(
                        leading:
                            const Icon(Icons.agriculture, color: Colors.green),
                        title: Text(nome),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.dashboard_customize_outlined,
                                  color: Colors.blueGrey),
                              tooltip: 'Ver Ordens de Serviço por Departamento',
                              onPressed: () => _navegarParaDepartamentos(nome),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Colors
                                      .grey), // Ícone para formulário/detalhes
                              tooltip: 'Abrir formulário/detalhes',
                              onPressed: () => abrirFormulario(nome),
                            ),
                          ],
                        ),
                        // onTap: () => abrirFormulario(nome), // Removido onTap principal para evitar conflito
                      );
                    },
                  ),
                ),
                if (mostrandoFormulario) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      "📄 Formulário da Fazenda: $fazendaSelecionada",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _municipioCtrl,
                      decoration: const InputDecoration(labelText: "Município"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _areaCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: "Área Total (ha)"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: ElevatedButton.icon(
                      onPressed: enviando ? null : enviarDocumento,
                      icon: enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file),
                      label: Text(enviando
                          ? 'Enviando...'
                          : 'Enviar Documento da Fazenda'),
                    ),
                  )
                ]
              ],
            ),
    );
  }
}
