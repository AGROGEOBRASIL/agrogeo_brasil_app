import 'package:cloud_firestore/cloud_firestore.dart';

class Imovel {
  final String id;
  final String nomeCliente;
  final String nomeFazenda; // Nome da fazenda/imóvel
  final String tipoServico;
  final String status;
  final Map<String, dynamic> progresso; // Armazena o progresso das etapas
  final Timestamp criadoEm;
  // Adicione outros campos relevantes que possam existir no Firestore
  // final double? area; // Exemplo: se houver área

  Imovel({
    required this.id,
    required this.nomeCliente,
    required this.nomeFazenda,
    required this.tipoServico,
    required this.status,
    required this.progresso,
    required this.criadoEm,
    // this.area,
  });

  // Fábrica para criar uma instância de Imovel a partir de um DocumentSnapshot do Firestore
  factory Imovel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Mapeamento cuidadoso dos campos, tratando possíveis nulos
    return Imovel(
      id: doc.id,
      nomeCliente: data['nomeCliente'] ?? 'Cliente não informado',
      nomeFazenda: data['fazenda'] ??
          'Fazenda não informada', // Usando o campo 'fazenda' como nome
      tipoServico: data['tipoServico'] ?? 'Serviço não informado',
      status: data['status'] ?? 'pendente', // Status padrão como 'pendente'
      progresso: (data['progresso'] is Map<String, dynamic>)
          ? data['progresso'] as Map<String, dynamic>
          : {}, // Garante que progresso seja um Map
      criadoEm: data['criadoEm'] ?? Timestamp.now(), // Data de criação padrão
      // area: data['area'] as double?, // Exemplo: se houver área
    );
  }

  // Método para obter o status de uma etapa específica do progresso
  // Retorna 'N/A' se a etapa não existir ou não tiver status
  String getStatusEtapa(String nomeEtapaNormalizado) {
    final etapaId = nomeEtapaNormalizado.replaceAll(' ', '_').toLowerCase();
    if (progresso.containsKey(etapaId)) {
      final etapaData = progresso[etapaId];
      if (etapaData is Map && etapaData.containsKey('concluido')) {
        return etapaData['concluido'] == true ? 'Concluído' : 'Pendente';
      }
    }
    // Tentativa de mapear nomes como 'GEO', 'CAR' diretamente se não houver progresso estruturado
    // Isso é uma suposição baseada no código PainelPage.txt
    if (progresso.containsKey(nomeEtapaNormalizado)) {
      return progresso[nomeEtapaNormalizado]?.toString() ?? 'N/A';
    }
    return 'N/A'; // Retorna 'N/A' se não encontrar a etapa
  }
}
