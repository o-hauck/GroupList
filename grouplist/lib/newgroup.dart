import 'package:flutter/material.dart';
import 'groupdata.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class NewGroupForm extends StatefulWidget {
  final void Function(GroupData group) onCreate;

  const NewGroupForm({super.key, required this.onCreate});

  @override
  State<NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends State<NewGroupForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _categories = ['Compras', 'Convidados', 'Viagens'];
  String _selectedCategory = 'Compras';

  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final Set<String> _selectedContactIds = {};
  String? _errorMessage;
  bool _isLoading = false;
  int _loadedContacts = 0;
  final int _loadBatchSize = 30;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterContacts);
    _scrollController.addListener(_onScroll);
    _getContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getContacts() async {
    setState(() => _isLoading = true);
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final fetchedContacts = await FlutterContacts.getContacts(
          withProperties: false,
        );
        setState(() {
          _contacts = fetchedContacts;
          _filteredContacts = _contacts.take(_loadBatchSize).toList();
          _loadedContacts = _filteredContacts.length;
        });
      } else {
        setState(() {
          _contacts = [Contact(name: Name(first: 'Permissão', last: 'negada'))];
          _filteredContacts = _contacts;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro ao carregar os contatos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    final filtered = _contacts.where((contact) {
      final name = contact.displayName.isNotEmpty
          ? contact.displayName
          : ('${contact.name.first} ${contact.name.last}').trim();
      return name.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _filteredContacts = filtered.take(_loadBatchSize).toList();
      _loadedContacts = _filteredContacts.length;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreContacts();
    }
  }

  void _loadMoreContacts() {
    if (_loadedContacts >= _contacts.length) return;

    final nextBatch = _contacts.skip(_loadedContacts).take(_loadBatchSize).toList();
    final currentFiltered = _searchController.text.isEmpty
        ? [..._filteredContacts, ...nextBatch]
        : [..._filteredContacts, ...nextBatch.where((contact) {
            final name = contact.displayName.isNotEmpty
                ? contact.displayName
                : ('${contact.name.first} ${contact.name.last}').trim();
            return name.toLowerCase().contains(_searchController.text.toLowerCase());
          })];

    setState(() {
      _filteredContacts = currentFiltered;
      _loadedContacts = _filteredContacts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Grupo')),
      body: SingleChildScrollView(
        controller: _scrollController,
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
                  checkmarkColor: Colors.white,
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                  },
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white70 : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Pesquisar contatos:'),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome...'
              ),
            ),
            const SizedBox(height: 16),
            const Text('Membros:'),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ..._filteredContacts.map((contact) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName
                        : ('${contact.name.first} ${contact.name.last}').trim(),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Checkbox(
                    value: _selectedContactIds.contains(contact.id),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedContactIds.add(contact.id);
                        } else {
                          _selectedContactIds.remove(contact.id);
                        }
                      });
                    },
                  ),
                )),
            const SizedBox(height: 100),
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