import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String nome;
  final String cpfCnpj;
  final String? rgIe;
  final String? email;
  final String? telefone;
  final String? endereco;
  final String municipio;
  final String? estado;
  final String? dataNascimento;
  final String? clienteDesde;
  final String? observacoes;
  final Timestamp criadoEm;

  Cliente({
    required this.id,
    required this.nome,
    required this.cpfCnpj,
    this.rgIe,
    this.email,
    this.telefone,
    this.endereco,
    required this.municipio,
    this.estado,
    this.dataNascimento,
    this.clienteDesde,
    this.observacoes,
    required this.criadoEm,
  });

  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Cliente(
      id: doc.id,
      nome: data['nome'] ?? '',
      cpfCnpj: data['cpfCnpj'] ?? '',
      rgIe: data['rgIe'],
      email: data['email'],
      telefone: data['telefone'],
      endereco: data['endereco'],
      municipio: data['municipio'] ?? '',
      estado: data['estado'],
      dataNascimento: data['dataNascimento'],
      clienteDesde: data['clienteDesde'],
      observacoes: data['observacoes'],
      criadoEm: data['criadoEm'] ?? Timestamp.now(),
    );
  }
}
