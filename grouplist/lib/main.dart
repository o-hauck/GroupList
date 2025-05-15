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
  final Set<String> _selectedGroupIds = {};
  bool _selectionMode = false;
  String? _selectedCategory;

  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];

  Stream<List<GroupData>> _loadGroups() {
    return FirebaseFirestore.instance.collection('groups').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return GroupData.fromJson({'id': doc.id, ...data});
          }).toList(),
        );
  }

  Future<void> _addGroup(GroupData group) async {
    try {
      await FirebaseFirestore.instance.collection('groups').add(group.toJson());
      print('Grupo "${group.name}" adicionado ao Firestore.');
    } catch (e) {
      print('Erro ao adicionar grupo "${group.name}": $e');
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
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
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
                  try {
                    await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(group.id)
                        .update({
                      'name': name,
                      'category': selectedCategory,
                    });
                    Navigator.pop(context);
                    print('Grupo atualizado.');
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
                  }
                  await batch.commit();

                  setState(() {
                    _selectedGroupIds.clear();
                    _selectionMode = false;
                  });

                  print('Grupos selecionados removidos do Firestore.');
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

  @override
  Widget build(BuildContext context) {
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

          final groups = (_selectedCategory == null
              ? snapshot.data!
              : snapshot.data!.where((g) => g.category == _selectedCategory).toList())
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
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
