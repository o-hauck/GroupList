

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Para navegar de volta para a tela principal

class GroupOptionsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupOptionsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupOptionsScreen> createState() => _GroupOptionsScreenState();
}

class _GroupOptionsScreenState extends State<GroupOptionsScreen> {
  late Future<Map<String, dynamic>> _groupDetailsFuture;

  @override
  void initState() {
    super.initState();
    _groupDetailsFuture = _fetchGroupDetails();
  }

  // Função para buscar todos os dados necessários de uma vez
  Future<Map<String, dynamic>> _fetchGroupDetails() async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();
        
    if (!groupDoc.exists) {
      throw 'Grupo não encontrado!';
    }
    
    final groupData = groupDoc.data()!;
    final memberUids = List<String>.from(groupData['membersUids'] ?? []);

    List<Map<String, String>> memberDetails = [];
    if(memberUids.isNotEmpty) {
      final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: memberUids)
        .get();
      
      memberDetails = usersSnapshot.docs.map((doc) => {
        'uid': doc.id,
        'email': doc.data()['email'] as String? ?? 'Email não encontrado',
      }).toList();
    }

    return {
      'createdByUid': groupData['createdByUid'],
      'memberDetails': memberDetails,
    };
  }
  
  // Navega para a tela inicial limpando as rotas anteriores
  void _navigateHome() {
     if(mounted) {
       Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), 
        (route) => false,
      );
     }
  }

  // Função para o usuário atual sair do grupo
  Future<void> _leaveGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    Navigator.of(context).pop(); // Fecha o dialog de confirmação
    _navigateHome();
    
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
      'membersUids': FieldValue.arrayRemove([currentUser.uid])
    });
  }

  // Função para o dono apagar o grupo e todos os seus itens
  Future<void> _deleteGroup() async {
    Navigator.of(context).pop(); // Fecha o dialog de confirmação
    _navigateHome();
    
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final itemsSnapshot = await groupRef.collection('items').get();

    // Cria uma operação em lote para apagar tudo de uma vez
    final batch = FirebaseFirestore.instance.batch();

    // 1. Apaga todos os itens da subcoleção
    for (var doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    // 2. Apaga o documento principal do grupo
    batch.delete(groupRef);

    await batch.commit();
  }
  
  // Dialog de confirmação genérico
  void _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
     showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            TextButton(
              onPressed: onConfirm,
              child: Text(confirmText, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Opções do Grupo')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Erro ao carregar detalhes: ${snapshot.error}'));
          }

          final details = snapshot.data!;
          final createdByUid = details['createdByUid'];
          final memberDetails = details['memberDetails'] as List<Map<String, String>>;
          final isOwner = currentUserUid == createdByUid;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Text(
                  'Participantes (${memberDetails.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: memberDetails.length,
                    itemBuilder: (context, index) {
                      final member = memberDetails[index];
                      final bool isThisMemberTheOwner = member['uid'] == createdByUid;
                      
                      return ListTile(
                        leading: Icon(isThisMemberTheOwner ? Icons.star : Icons.person_outline),
                        title: Text(member['email']!),
                        trailing: isThisMemberTheOwner ? const Text('(Dono)', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)) : null,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  // Mostra um botão diferente dependendo se o usuário é o dono
                  child: isOwner
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Apagar Grupo Permanentemente'),
                        onPressed: () => _showConfirmationDialog(
                          title: 'Apagar Grupo',
                          content: 'Esta ação é irreversível e irá apagar o grupo e todos os seus itens para todos os membros. Deseja continuar?',
                          confirmText: 'Apagar',
                          onConfirm: _deleteGroup,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Sair do Grupo'),
                        onPressed: () => _showConfirmationDialog(
                          title: 'Sair do Grupo',
                          content: 'Tem certeza que deseja sair deste grupo? Você perderá o acesso a ele.',
                          confirmText: 'Sair',
                          onConfirm: _leaveGroup,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                        ),
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}