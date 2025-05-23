import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Modelo para Ordem de Serviço (simplificado, ajuste conforme seus dados reais no app)
class OrdemServico {
  final String id;
  final String nomeCliente;
  final String cpfCliente; // Adicionado para possível filtro ou referência
  final String fazenda;
  final String tipoServico;
  final String? outroServico; // Se tipoServico for "Outro"
  final String descricao;
  final double valorTotal;
  final String status;
  final String? colaborador;
  final Timestamp criadoEm;
  final String?
      caminhoPastaStoragePainel; // Referência ao caminho original no painel
  final String? userUid; // UID do usuário do app associado a esta OS
  final String? departamentoRelacionado;

  OrdemServico({
    required this.id,
    required this.nomeCliente,
    required this.cpfCliente,
    required this.fazenda,
    required this.tipoServico,
    this.outroServico,
    required this.descricao,
    required this.valorTotal,
    required this.status,
    this.colaborador,
    required this.criadoEm,
    this.caminhoPastaStoragePainel,
    this.userUid,
    this.departamentoRelacionado,
  });

  factory OrdemServico.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrdemServico(
      id: doc.id,
      nomeCliente: data['nomeCliente'] ?? '',
      cpfCliente: data['cpfCliente'] ?? '', // Campo do painel
      fazenda: data['fazenda'] ?? '',
      tipoServico: data['tipoServico'] ?? '',
      outroServico: data['outroServico'],
      descricao: data['descricao'] ?? '',
      valorTotal: (data['valorTotal'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pendente',
      colaborador: data['colaborador'],
      criadoEm: data['criadoEm'] ?? Timestamp.now(),
      caminhoPastaStoragePainel: data['caminhoPasta'], // Do painel
      userUid:
          data['userUid'], // UID do usuário no app, adicionado na sincronização
      departamentoRelacionado: data['departamentoRelacionado'],
    );
  }
}

// Modelo para Etapa da Ordem de Serviço
class EtapaOS {
  final String id;
  final String nome;
  final int ordem;
  final bool exigeUpload;
  final String? arquivoUrl; // URL do arquivo no Storage do app após cópia
  final String? nomeArquivo;
  // Adicione outros campos como status da etapa, data de conclusão, etc.

  EtapaOS({
    required this.id,
    required this.nome,
    required this.ordem,
    required this.exigeUpload,
    this.arquivoUrl,
    this.nomeArquivo,
  });

  factory EtapaOS.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EtapaOS(
      id: doc.id,
      nome: data['nome'] ?? '',
      ordem: (data['ordem'] as num?)?.toInt() ?? 0,
      exigeUpload: data['exigeUpload'] ?? false,
      arquivoUrl: data[
          'arquivoUrl'], // Salvo após cópia do arquivo do painel para o app storage
      nomeArquivo: data['nomeArquivo'],
    );
  }
}

class OsService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // App: agrogeo-brasil-app
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
      bucket: 'agrogeo-brasil-app.appspot.com'); // Bucket do App

  // --- Ordens de Serviço ---

  // Stream para O.S. associadas ao UID do usuário do app
  // Supõe que ao sincronizar a O.S. do painel para o app, você adicione um campo 'userUid'
  // com o FirebaseAuth.instance.currentUser.uid do usuário do app.
  Stream<List<OrdemServico>> getOrdensServicoStream(String userUid) {
    if (userUid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('ordensServico')
        .where('userUid',
            isEqualTo: userUid) // Filtra pelo UID do usuário do app
        // .orderBy('criadoEm', descending: true) // Exemplo de ordenação
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrdemServico.fromFirestore(doc))
          .toList();
    });
  }

  // Alternativamente, se você buscar pelo CPF que está na OS (e esse CPF é o do usuário logado)
  // Isso requer que o campo 'cpfCliente' na OS seja o CPF do usuário logado no app.
  Stream<List<OrdemServico>> getOrdensServicoStreamByCpf(String cpfCliente) {
    if (cpfCliente.isEmpty) return Stream.value([]);
    return _firestore
        .collection('ordensServico')
        .where('cpfCliente',
            isEqualTo: cpfCliente) // Filtra pelo CPF do cliente
        // .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrdemServico.fromFirestore(doc))
          .toList();
    });
  }

  // Obter uma única Ordem de Serviço
  Future<OrdemServico?> getOrdemServicoById(String osId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('ordensServico').doc(osId).get();
      if (doc.exists) {
        return OrdemServico.fromFirestore(doc);
      }
    } catch (e) {
      print('Erro ao buscar Ordem de Serviço por ID: $e');
    }
    return null;
  }

  // --- Etapas da Ordem de Serviço ---

  // Stream para etapas de uma O.S. específica
  Stream<List<EtapaOS>> getEtapasStream(String osId) {
    if (osId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('ordensServico')
        .doc(osId)
        .collection('etapas')
        .orderBy('ordem') // Ordena pela ordem definida no checklist
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EtapaOS.fromFirestore(doc)).toList();
    });
  }

  // --- Arquivos do Storage (para etapas) ---

  // Obter URL de download de um arquivo no Storage do app
  // O 'storagePath' deve ser o caminho completo do arquivo no bucket do app,
  // ex: 'ordensServico/OS_ID_APP/etapas/nome_do_arquivo.pdf'
  Future<String?> getDownloadUrl(String storagePath) async {
    if (storagePath.isEmpty) return null;
    try {
      final ref = _storage.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Erro ao obter URL de download do Storage: $e');
      if (e is FirebaseException && e.code == 'object-not-found') {
        print('Arquivo não encontrado em: $storagePath');
      }
      return null;
    }
  }

  // --- Sincronização (Chamada a Cloud Functions - a ser implementada) ---

  // Exemplo de como você poderia chamar uma Cloud Function para iniciar a sincronização
  // de O.S. e arquivos do painel para o app. A Cloud Function faria o trabalho pesado.
  /*
  Future<void> solicitarSincronizacaoDeNovasOS(String clienteCpfNoPainel) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'sua-regiao').httpsCallable('syncOrdensServicoDoPainel');
      final response = await callable.call(<String, dynamic>{
        'cpfClientePainel': clienteCpfNoPainel,
        'userUidApp': FirebaseAuth.instance.currentUser?.uid, // Para associar no app
      });
      print('Resposta da sincronização: ${response.data}');
    } on FirebaseFunctionsException catch (e) {
      print('Erro ao chamar função de sincronização de OS: ${e.code} - ${e.message}');
    } catch (e) {
      print('Erro inesperado ao solicitar sincronização de OS: $e');
    }
  }
  */

  // Adicione aqui outros métodos que possam ser úteis, como:
  // - Atualizar status de uma etapa
  // - Fazer upload de um arquivo para uma etapa (se o app permitir)
}
