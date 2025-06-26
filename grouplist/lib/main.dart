// lib/main.dart (VERSÃO FINAL E COMPLETA)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'about.dart';
import 'list.dart';
import 'newgroup.dart';
import 'groupdata.dart';
import 'splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_screen.dart'; // Importa a tela de autenticação

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GroupList',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    GroupsScreen(),
    AboutPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Grupos'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Sobre'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final Set<String> _selectedGroupIds = {};
  bool _selectionMode = false;

  // Função para adicionar um novo grupo no Firestore
  Future<void> _addGroup(GroupData group) async {
    try {
      await FirebaseFirestore.instance.collection('groups').add(group.toJson());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar grupo: $e')),
      );
    }
  }

  // Função para apagar os grupos selecionados
  Future<void> _removeSelectedGroups() async {
    if (_selectedGroupIds.isEmpty) return;
    
    // Mostra um diálogo de confirmação
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Apagar Grupos'),
          content: Text('Deseja apagar permanentemente ${_selectedGroupIds.length} grupo(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  for (var groupId in _selectedGroupIds) {
                    batch.delete(FirebaseFirestore.instance.collection('groups').doc(groupId));
                  }
                  await batch.commit();
                  setState(() {
                    _selectedGroupIds.clear();
                    _selectionMode = false;
                  });
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao remover grupos: $e')),
                  );
                }
              },
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );
  }

  void _toggleSelection(String groupId) {
    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
      _selectionMode = _selectedGroupIds.isNotEmpty;
    });
  }
  
  void _navigateToNewGroupForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewGroupForm(onCreate: _addGroup),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Se o usuário não estiver logado, mostra uma tela para fazer login.
    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Você precisa estar logado para ver seus grupos.'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Fazer Login ou Cadastrar'),
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Grupos'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _removeSelectedGroups,
            )
        ],
      ),
      // USA UM STREAMBUILDER PARA ATUALIZAR A LISTA EM TEMPO REAL
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('membersUids', arrayContains: currentUser.uid) // A MÁGICA ACONTECE AQUI!
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Ocorreu um erro ao carregar os grupos.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhum grupo encontrado.\nCrie um novo no botão "+".', textAlign: TextAlign.center),
            );
          }

          // Converte os documentos do Firestore para objetos GroupData
          final groups = snapshot.data!.docs.map((doc) {
            return GroupData.fromJson(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final isSelected = _selectedGroupIds.contains(group.id);

              return Container(
                color: isSelected ? Colors.deepPurple.withOpacity(0.2) : null,
                child: ListTile(
                  leading: CircleAvatar(child: Text(group.name.substring(0, 1).toUpperCase())),
                  title: Text(group.name),
                  subtitle: Text(group.category),
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(group.id);
                    } else {
                       Navigator.push(context, MaterialPageRoute(
                        builder: (context) => ListPage(groupId: group.id, groupName: group.name),
                      ));
                    }
                  },
                  onLongPress: () => _toggleSelection(group.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewGroupForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}