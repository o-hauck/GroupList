import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'about.dart';
import 'list.dart';
import 'newgroup.dart';
import 'groupdata.dart';

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
  List<GroupData> _groups = [];
  final Set<int> _selectedGroups = {};
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
          final actualIndex = _groups.indexOf(group);
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group)),
            title: Text(group.name),
            trailing: _selectionMode
                ? Checkbox(
                    value: _selectedGroups.contains(actualIndex),
                    onChanged: (_) => _toggleSelection(actualIndex),
                  )
                : null,
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(actualIndex);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListPage(groupName: group.name),
                  ),
                );
              }
            },
            onLongPress: () => _toggleSelection(actualIndex),
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