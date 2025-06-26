// lib/newgroup.dart (VERSÃO CORRIGIDA E COMPLETA)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'groupdata.dart';
import 'auth_screen.dart';

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

  bool _isSharedList = false;

  // Variáveis de estado dos contatos
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final Set<String> _selectedContactIds = {};
  String? _errorMessage;
  bool _isLoadingContacts = false; // Renomeado para clareza

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterContacts);
    // A busca de contatos foi movida para o onChanged do Switch
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // LÓGICA DE CONTATOS RESTAURADA
  Future<void> _getContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      if (await FlutterContacts.requestPermission()) {
        _contacts = await FlutterContacts.getContacts(withProperties: true);
        _filterContacts(); // Filtra inicialmente (mostra todos)
      } else {
        _errorMessage = 'Permissão para acessar contatos foi negada.';
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar contatos: $e';
    } finally {
      setState(() => _isLoadingContacts = false);
    }
  }

  // LÓGICA DE FILTRO RESTAURADA
  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final displayName = contact.displayName.toLowerCase();
        return displayName.contains(query);
      }).toList();
    });
  }

  // Lógica para criar o grupo
  void _createGroup() {
    if (_nameController.text.isNotEmpty) {
      final group = GroupData(_nameController.text, _selectedCategory);
      // Aqui você pode adicionar os _selectedContactIds ao grupo se necessário
      widget.onCreate(group);
      Navigator.pop(context);
    }
  }

  // Lógica para o FloatingActionButton
  void _handleCreateGroupAction() {
    if (!_isSharedList) {
      _createGroup();
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      _createGroup();
    } else {
      _showLoginPrompt();
    }
  }

  // Popup para perguntar sobre o login
  Future<void> _showLoginPrompt() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Necessário'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Para criar uma lista compartilhada, você precisa fazer login.'),
                Text('Deseja fazer login?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Sim'),
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialog
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const AuthScreen(),
                ));
              },
            ),
          ],
        );
      },
    );
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
            // Seção de informações do Grupo (sempre visível)
            const CircleAvatar(radius: 30, child: Icon(Icons.image, size: 30)),
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
                  onSelected: (_) => setState(() => _selectedCategory = category),
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Switch para lista privada/compartilhada
            SwitchListTile(
              title: const Text('Lista Compartilhada'),
              subtitle: const Text('Adicionar membros da sua lista de contatos.'),
              value: _isSharedList,
              onChanged: (bool value) {
                setState(() {
                  _isSharedList = value;
                  // CORREÇÃO: Carrega contatos APENAS se o switch for ativado
                  // e se os contatos ainda não foram carregados.
                  if (_isSharedList && _contacts.isEmpty) {
                    _getContacts();
                  }
                });
              },
            ),

            // CORREÇÃO: Seção de contatos SÓ APARECE se a lista for compartilhada
            if (_isSharedList)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text('Membros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red))
                  else if (_isLoadingContacts)
                    const Center(child: CircularProgressIndicator())
                  else
                    // Limita a altura da lista para evitar overflow
                    SizedBox(
                      height: 300, // Defina uma altura ou use Expanded em um Column
                      child: ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(contact.displayName),
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
                          );
                        },
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateGroupAction,
        child: const Icon(Icons.check),
      ),
    );
  }
}