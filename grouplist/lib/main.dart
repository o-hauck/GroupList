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
  // A função para adicionar o grupo agora é mais simples
  Future<void> _addGroup(GroupData group) async {
    try {
      await FirebaseFirestore.instance.collection('groups').add(group.toJson());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar grupo: $e')),
        );
      }
    }
  }

  // Função para obter o ícone baseado na categoria
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Compras':
        return Icons.shopping_cart_outlined;
      case 'Viagens':
        return Icons.flight_takeoff;
      case 'Convidados':
        return Icons.people_outline;
      default:
        return Icons.group;
    }
  }

  void _navigateToNewGroupForm() {
    // A própria tela de criação vai pedir o login se necessário
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewGroupForm(onCreate: _addGroup),
      ),
    );
  }

  // --- Widgets de UI para cada estado (Logado vs. Deslogado) ---

  // Botão dinâmico para a AppBar
  Widget _buildAuthActionButton(User? currentUser) {
    if (currentUser == null) {
      // BOTÃO DE LOGIN
      return TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        icon: const Icon(Icons.login),
        label: const Text('Entrar'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AuthScreen())),
      );
    } else {
      // BOTÃO DE LOGOUT
      return IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Sair',
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
        },
      );
    }
  }

  // Corpo da tela quando o usuário está LOGADO
  Widget _buildGroupsList(User currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('membersUids', arrayContains: currentUser.uid)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Ocorreu um erro.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Nenhum grupo encontrado.\nCrie um no botão "+".',
                textAlign: TextAlign.center),
          );
        }

        final groups = snapshot.data!.docs.map((doc) {
          return GroupData.fromJson(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(_getIconForCategory(group.category)),
              ),
              title: Text(group.name),
              subtitle: Text(group.category),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ListPage(groupId: group.id, groupName: group.name),
                    ));
              },
            );
          },
        );
      },
    );
  }

  // Corpo da tela quando o usuário está DESLOGADO
  Widget _buildLoggedOutBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline,
                size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            Text(
              'Bem-vindo ao GroupList!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Entre ou crie uma conta para criar e participar de listas compartilhadas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O StreamBuilder aqui resolve o problema do refresh!
    // Ele "escuta" o estado de login e reconstrói a tela automaticamente.
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final currentUser = snapshot.data;

          return Scaffold(
            appBar: AppBar(
              title: const Text('GroupList'),
              actions: [
                // Usa a função para construir o botão dinâmico
                _buildAuthActionButton(currentUser),
              ],
            ),
            body: currentUser == null
                ? _buildLoggedOutBody() // Mostra a UI de "deslogado"
                : _buildGroupsList(currentUser), // Mostra a UI de "logado"
            floatingActionButton: FloatingActionButton(
              onPressed: _navigateToNewGroupForm,
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}
