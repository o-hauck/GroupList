import 'package:flutter/material.dart';
import 'about.dart';
import 'list.dart';
import 'newgroup.dart';
import 'groupdata.dart';
import 'splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Grupos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'Sobre',
          ),
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
  List<GroupData> _groups = [];
  final Set<int> _selectedGroups = {};
  bool _selectionMode = false;
  String? _selectedCategory;

  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];

  @override
  void initState() {
    super.initState();
    
  }


  // Modifique _loadGroups() para usar Firestore
  Stream<List<GroupData>> _loadGroups() {
    return FirebaseFirestore.instance.collection('groups').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return GroupData.fromJson({'id': doc.id, ...data});
          }).toList(),
        );
  }

  // Modifique _addGroup() para usar Firestore
  Future<void> _addGroup(GroupData group) async {
    try {
      await FirebaseFirestore.instance.collection('groups').add(group.toJson());
      print('Grupo "${group.name}" adicionado ao Firestore.');
    } catch (e) {
      print('Erro ao adicionar grupo "${group.name}": $e');
      // Tratar o erro adequadamente 
    }
  }

  // Modifique _removeSelectedGroups() para usar Firestore
  Future<void> _removeSelectedGroups() async {
    if (_selectedGroups.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deseja apagar este grupo?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  _selectedGroups.forEach((index) {
                    batch.delete(
                        FirebaseFirestore.instance.collection('groups').doc(_groups[index].id));
                  });
                  await batch.commit();

                  setState(() {
                    _groups = _groups
                        .asMap()
                        .entries
                        .where((entry) => !_selectedGroups.contains(entry.key))
                        .map((entry) => entry.value)
                        .toList();
                    _selectedGroups.clear();
                    _selectionMode = false;
                  });

                  print('Grupos selecionados removidos do Firestore.');
                } catch (e) {
                  print('Erro ao remover grupos: $e');
                  // Trate o erro adequadamente
                }
              },
              child: const Text('Apagar conversa'),
            ),
          ],
        );
      },
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedGroups.contains(index)) {
        _selectedGroups.remove(index);
      } else {
        _selectedGroups.add(index);
      }
      _selectionMode = _selectedGroups.isNotEmpty;
    });
  }

  void _navigateToNewGroupForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewGroupForm(
          onCreate: (group) => _addGroup(group),
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.filter_alt_off),
            title: const Text('Todos'),
            onTap: () {
              setState(() => _selectedCategory = null);
              Navigator.pop(context);
            },
          ),
          ..._categories.map((category) => ListTile(
                leading: const Icon(Icons.label),
                title: Text(category),
                onTap: () {
                  setState(() => _selectedCategory = category);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final filteredGroups = _selectedCategory == null
    //     ? _groups
    //     : _groups.where((g) => g.category == _selectedCategory).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _removeSelectedGroups,
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterMenu,
            ),
        ],
      ),
      // Use StreamBuilder para exibir os grupos do Firestore
      body: StreamBuilder<List<GroupData>>(
        stream: _loadGroups(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar grupos: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum grupo encontrado.'));
          }
          final filteredGroups = _selectedCategory == null
              ? snapshot.data!
              : snapshot.data!.where((g) => g.category == _selectedCategory).toList();
          return ListView.builder(
            itemCount: filteredGroups.length,
            itemBuilder: (context, index) {
              final group = filteredGroups[index];
              return Container(
                color: _selectedGroups.contains(index) ? Colors.deepPurple.shade100 : null,
                child: Stack(
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          const CircleAvatar(child: Icon(Icons.group)),
                          if (_selectionMode && _selectedGroups.contains(index))
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.check,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Text(group.name),
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelection(index);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              // Modificação Importante: Passa o ID do grupo
                              builder: (context) => ListPage(groupId: group.id!),
                            ),
                          );
                        }
                      },
                      onLongPress: () => _toggleSelection(index),
                    ),
                  ],
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

class GroupDetailsScreen extends StatelessWidget {
  final String groupName;

  const GroupDetailsScreen({super.key, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
      ),
      body: const Center(
        child: Text('Aqui será exibida a lista do grupo.'),
      ),
    );
  }
}