import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/imovel.dart';
import '../models/cliente.dart';
import 'dart:developer' as developer;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch client data based on logged-in user's email (assuming it's the CPF)
  Future<Cliente?> getClienteAtual() async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      developer.log("Usuário não logado ou sem email (CPF).",
          name: "FirestoreService");
      return null;
    }

    final String userCpf = user.email!;
    developer.log("Buscando cliente com CPF (email): $userCpf",
        name: "FirestoreService");

    try {
      // Query 'clientes' collection where 'cpfCnpj' matches the user's email (CPF)
      // IMPORTANT: This query requires a Firestore index on the 'cpfCnpj' field in the 'clientes' collection.
      // Create this index in your Firebase console.
      QuerySnapshot querySnapshot = await _db
          .collection('clientes')
          .where('cpfCnpj',
              isEqualTo:
                  userCpf) // Assumes user.email stores the raw CPF used in 'cpfCnpj'
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        developer.log("Cliente encontrado: ${querySnapshot.docs.first.id}",
            name: "FirestoreService");
        return Cliente.fromFirestore(querySnapshot.docs.first);
      } else {
        developer.log("Cliente não encontrado para CPF: $userCpf",
            name: "FirestoreService");
        // Fallback: Try querying by 'email' field if 'cpfCnpj' fails or isn't the login identifier
        /*
        developer.log("Tentando buscar por campo 'email'...", name: "FirestoreService");
        querySnapshot = await _db
            .collection('clientes')
            .where('email', isEqualTo: userCpf)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          developer.log("Cliente encontrado pelo campo 'email': ${querySnapshot.docs.first.id}", name: "FirestoreService");
          return Cliente.fromFirestore(querySnapshot.docs.first);
        } else {
          developer.log("Cliente também não encontrado pelo campo 'email'.", name: "FirestoreService");
          return null;
        }
        */
        return null;
      }
    } catch (e) {
      developer.log("Erro ao buscar cliente no Firestore: $e",
          name: "FirestoreService");
      // Consider specific error handling (e.g., index missing)
      if (e is FirebaseException && e.code == 'failed-precondition') {
        developer.log(
            "Erro: Índice do Firestore provavelmente ausente para a consulta 'clientes' por 'cpfCnpj'. Crie o índice no console do Firebase.",
            name: "FirestoreService");
      }
      return null;
    }
  }

  // Get a stream of 'Imovel' (Fazendas from ordensServico) associated with a client name
  Stream<List<Imovel>> getFazendasStream(String clienteNome) {
    developer.log("Buscando fazendas para o cliente: $clienteNome",
        name: "FirestoreService");
    try {
      // Query 'ordensServico' collection where 'nomeCliente' matches
      // IMPORTANT: This query requires a Firestore index on the 'nomeCliente' field in the 'ordensServico' collection.
      // Create this index in your Firebase console.
      return _db
          .collection('ordensServico')
          .where('nomeCliente', isEqualTo: clienteNome)
          // .orderBy('criadoEm', descending: true) // Add ordering if needed (requires composite index)
          .snapshots()
          .map((snapshot) {
        developer.log(
            "Recebidos ${snapshot.docs.length} documentos de ordensServico para $clienteNome",
            name: "FirestoreService");
        return snapshot.docs.map((doc) => Imovel.fromFirestore(doc)).toList();
      }).handleError((error) {
        developer.log("Erro no stream de fazendas para $clienteNome: $error",
            name: "FirestoreService");
        if (error is FirebaseException && error.code == 'failed-precondition') {
          developer.log(
              "Erro: Índice do Firestore provavelmente ausente para a consulta 'ordensServico' por 'nomeCliente'. Crie o índice no console do Firebase.",
              name: "FirestoreService");
        }
        return <Imovel>[]; // Return empty list on error
      });
    } catch (e) {
      developer.log("Erro ao criar stream de fazendas: $e",
          name: "FirestoreService");
      return Stream.value(<Imovel>[]); // Return empty stream on error
    }
  }
}
