// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'about.dart';

void main() {
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
      home: const HomeScreen(),
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

class GroupData {
  final String name;
  final String category;

  GroupData(this.name, this.category);

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
      };

  static GroupData fromJson(Map<String, dynamic> json) =>
      GroupData(json['name'], json['category']);
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupData> _groups = [];
  Set<int> _selectedGroups = {};
  bool _selectionMode = false;
  String? _selectedCategory;

  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String? groupsJson = prefs.getString('groups');
    if (groupsJson != null) {
      final List decoded = jsonDecode(groupsJson);
      setState(() {
        _groups = decoded.map((e) => GroupData.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String groupsJson = jsonEncode(_groups.map((e) => e.toJson()).toList());
    await prefs.setString('groups', groupsJson);
  }

  void _addGroup(GroupData group) {
    setState(() {
      _groups.add(group);
    });
    _saveGroups();
  }

  void _removeSelectedGroups() {
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
    _saveGroups();
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
    final filteredGroups = _selectedCategory == null
        ? _groups
        : _groups.where((g) => g.category == _selectedCategory).toList();

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
      body: ListView.builder(
        itemCount: filteredGroups.length,
        itemBuilder: (context, index) {
          final group = filteredGroups[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group)),
            title: Text(group.name),
            trailing: _selectionMode
                ? Checkbox(
                    value: _selectedGroups.contains(index),
                    onChanged: (_) => _toggleSelection(index),
                  )
                : null,
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(index);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDetailsScreen(groupName: group.name),
                  ),
                );
              }
            },
            onLongPress: () => _toggleSelection(index),
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

class NewGroupForm extends StatefulWidget {
  final void Function(GroupData group) onCreate;

  const NewGroupForm({super.key, required this.onCreate});

  @override
  State<NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends State<NewGroupForm> {
  final TextEditingController _nameController = TextEditingController();
  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];
  String _selectedCategory = 'Compras';

  final List<String> _contacts = ['Zack John', 'Maria Silva', 'Lucas Costa'];
  final Set<String> _selectedContacts = {'Zack John'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(Icons.image, size: 30),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do grupo...'),
            ),
            const SizedBox(height: 16),
            const Text('Categoria'),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  selectedColor: Colors.black,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Membros:'),
            ..._contacts.map((contact) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact),
                  trailing: Checkbox(
                    value: _selectedContacts.contains(contact),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedContacts.add(contact);
                        } else {
                          _selectedContacts.remove(contact);
                        }
                      });
                    },
                  ),
                )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_nameController.text.isNotEmpty) {
            final group = GroupData(_nameController.text, _selectedCategory);
            widget.onCreate(group);
            Navigator.pop(context);
          }
        },
        child: const Icon(Icons.check),
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