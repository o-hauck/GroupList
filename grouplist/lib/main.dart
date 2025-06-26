import 'package:flutter/material.dart';
import 'about.dart';
import 'list.dart';
import 'newgroup.dart';
import 'groupdata.dart';
import 'splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Importa o helper do banco de dados que criamos.
import 'database_helper.dart';

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

// NENHUMA ALTERAÇÃO NECESSÁRIA AQUI.
// Sua estrutura de navegação principal está preservada.
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
  final dbHelper = DatabaseHelper();
  List<GroupData> _localGroups = [];
  bool _isLoading = true;

  final Set<String> _selectedGroupIds = {};
  bool _selectionMode = false;
  String? _selectedCategory;
  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];

  @override
  void initState() {
    super.initState();
    _loadAndSyncGroups();
  }

  // Nova função para carregar e sincronizar os dados
  Future<void> _loadAndSyncGroups() async {
    if (_localGroups.isEmpty) {
      setState(() => _isLoading = true);
    }

    // 1. Tenta carregar os dados locais primeiro para uma UI rápida
    var localData = await dbHelper.getGroups();
    if (mounted) {
      setState(() {
        _localGroups = localData;
        _isLoading = false;
      });
    }

    // 2. Verifica a conexão com a internet
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print('Sem conexão com a internet. Exibindo dados locais.');
      return; // Para a execução se estiver offline
    }

    // 3. Se houver internet, busca no Firebase e atualiza o banco local
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('groups').get();
      final firebaseGroups = snapshot.docs.map((doc) {
        return GroupData.fromJson({'id': doc.id, ...doc.data()});
      }).toList();

      await dbHelper.clearAllGroups();
      for (var group in firebaseGroups) {
        await dbHelper.insertOrUpdateGroup(group);
      }

      // 4. Recarrega os dados do banco local e atualiza a tela
      final updatedLocalData = await dbHelper.getGroups();
      if (mounted) {
        setState(() {
          _localGroups = updatedLocalData;
        });
      }
    } catch (e) {
      print('Falha ao sincronizar com Firebase: $e. Exibindo dados locais.');
    }
  }

  // Funções de CRUD (criar, editar, apagar) atualizadas
  Future<void> _addGroup(GroupData group) async {
    try {
      // Adiciona no Firebase para obter um ID
      final docRef = await FirebaseFirestore.instance.collection('groups').add(group.toJson());
      final newGroup = GroupData(group.name, group.category, id: docRef.id);

      // Salva também no banco de dados local
      await dbHelper.insertOrUpdateGroup(newGroup);

      // Atualiza a lista na tela imediatamente
      setState(() {
        _localGroups.add(newGroup);
      });
    } catch (e) {
      print('Erro ao adicionar grupo: $e');
    }
  }

  Future<void> _editGroup(GroupData group) async {
    final nameController = TextEditingController(text: group.name);
    String selectedCategory = group.category;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome do grupo'),
              ),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
                },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final updatedGroup = GroupData(name, selectedCategory, id: group.id);
                  try {
                    await FirebaseFirestore.instance.collection('groups').doc(group.id).update(updatedGroup.toJson());
                    await dbHelper.insertOrUpdateGroup(updatedGroup);

                    setState(() {
                      final index = _localGroups.indexWhere((g) => g.id == group.id);
                      if (index != -1) _localGroups[index] = updatedGroup;
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print('Erro ao atualizar grupo: $e');
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeSelectedGroups() async {
    if (_selectedGroupIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deseja apagar este(s) grupo(s)?'),
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
                    await dbHelper.deleteGroup(groupId); // Remove do local também
                  }
                  await batch.commit();
                  setState(() {
                    _localGroups.removeWhere((g) => _selectedGroupIds.contains(g.id));
                    _selectedGroupIds.clear();
                    _selectionMode = false;
                  });
                } catch (e) {
                  print('Erro ao remover grupos: $e');
                }
              },
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );
  }

  // Funções de UI (sem grandes alterações na lógica)
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

  // Novo método build sem o StreamBuilder
  @override
  Widget build(BuildContext context) {
    final filteredGroups = (_selectedCategory == null
            ? _localGroups
            : _localGroups.where((g) => g.category == _selectedCategory).toList())
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade200,
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
      body: RefreshIndicator(
        onRefresh: _loadAndSyncGroups, // Permite "puxar para atualizar"
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredGroups.isEmpty
                ? const Center(child: Text('Nenhum grupo encontrado.'))
                : ListView.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final isSelected = _selectedGroupIds.contains(group.id);
                      return Container(
                        color: isSelected ? Colors.deepPurple.shade100 : null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(child: Icon(Icons.group)),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(group.name)),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editGroup(group);
                                  } else if (value == 'select') {
                                    _toggleSelection(group.id!);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(value: 'select', child: Text('Selecionar')),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(group.id!);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListPage(
                                    groupId: group.id!,
                                    groupName: group.name,
                                  ),
                                ),
                              );
                            }
                          },
                          onLongPress: () => _toggleSelection(group.id!),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewGroupForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Seu widget GroupDetailsScreen permanece inalterado.
class GroupDetailsScreen extends StatelessWidget {
  final String groupName;
  const GroupDetailsScreen({super.key, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: const Center(child: Text('Aqui será exibida a lista do grupo.')),
    );
  }
}
