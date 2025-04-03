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

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<String> _groups = [];
  Set<int> _selectedGroups = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String? groupsJson = prefs.getString('groups');
    if (groupsJson != null) {
      setState(() {
        _groups = List<String>.from(jsonDecode(groupsJson));
      });
    }
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String groupsJson = jsonEncode(_groups);
    await prefs.setString('groups', groupsJson);
  }

  void _addGroup(String name) {
    setState(() {
      _groups.add(name);
    });
    _saveGroups();
  }

  void _removeSelectedGroups() {
    setState(() {
      _groups = _groups.asMap().entries.where((entry) => !_selectedGroups.contains(entry.key)).map((entry) => entry.value).toList();
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

  void _showAddGroupDialog() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Criar novo grupo'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Nome do grupo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _addGroup(_controller.text);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: Column(
        children: [
          if (_selectionMode)
            AppBar(
              title: const Text('Opções'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _removeSelectedGroups,
                ),
              ],
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: _selectionMode ? Checkbox(
                    value: _selectedGroups.contains(index),
                    onChanged: (_) => _toggleSelection(index),
                  ) : const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(_groups[index]),
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(index);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GroupDetailsScreen(groupName: _groups[index])),
                      );
                    }
                  },
                  onLongPress: () => _toggleSelection(index),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGroupDialog,
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
