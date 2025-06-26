// lib/newgroup.dart (VERSÃO FINAL E COMPLETA)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'groupdata.dart';
import 'auth_screen.dart'; // Usaremos para o prompt de login

class NewGroupForm extends StatefulWidget {
  // A função de callback agora é assíncrona para aguardar o salvamento no Firestore
  final Future<void> Function(GroupData group) onCreate;

  const NewGroupForm({super.key, required this.onCreate});

  @override
  State<NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends State<NewGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final _categories = ['Compras', 'Convidados', 'Viagens'];
  String _selectedCategory = 'Compras';
  bool _isSharedList = false;

  // Estado para a nova lógica de convite por email
  final List<String> _invitedMemberEmails = [];
  bool _isLookingUpUser = false;
  bool _isCreatingGroup = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Adiciona um membro à lista de convidados (UI)
  Future<void> _addMember() async {
    final enteredEmail = _emailController.text.trim().toLowerCase();
    if (enteredEmail.isEmpty || !enteredEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, insira um email válido.')));
      return;
    }
    if (_invitedMemberEmails.contains(enteredEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este email já foi adicionado.')));
      return;
    }
    // Não permite que o usuário se auto-convide
    if (enteredEmail == FirebaseAuth.instance.currentUser?.email) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já é o dono do grupo.')));
      return;
    }

    setState(() => _isLookingUpUser = true);

    try {
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: enteredEmail)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        setState(() {
          _invitedMemberEmails.add(enteredEmail);
          _emailController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Usuário não encontrado. Verifique o email.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao buscar usuário: $e')));
    } finally {
      setState(() => _isLookingUpUser = false);
    }
  }

  // Lógica principal para criar o grupo
  Future<void> _handleCreateGroupAction() async {
    // PRIMEIRO: Verifica se o usuário está logado. Qualquer criação de grupo exige login.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    // SEGUNDO: Valida o formulário
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isCreatingGroup = true);

    // TERCEIRO: Continua com a lógica para montar a lista de membros e criar o grupo
    List<String> memberUids = [currentUser.uid];

    if (_isSharedList) {
      for (String email in _invitedMemberEmails) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final uid = userQuery.docs.first.id;
          if (!memberUids.contains(uid)) {
            memberUids.add(uid);
          }
        }
      }
    }

    final newGroup = GroupData(
      name: _nameController.text,
      category: _selectedCategory,
      membersUids: memberUids,
      createdByUid: currentUser.uid,
    );

    await widget.onCreate(newGroup);

    if (mounted) {
      Navigator.pop(context);
    }
    // Não precisa mais do setState aqui
  }

  // Mostra o popup para o usuário fazer login se não estiver autenticado
  Future<void> _showLoginPrompt() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Necessário'),
          content: const Text(
              'Você precisa estar logado para criar grupos. Deseja fazer login/cadastro agora?'),
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Nome do grupo...'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira um nome.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Categoria'),
              Wrap(
                spacing: 8,
                children: _categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Grupo Compartilhado'),
                subtitle: const Text('Convidar outros membros por email.'),
                value: _isSharedList,
                onChanged: (bool value) =>
                    setState(() => _isSharedList = value),
              ),

              // Seção para adicionar membros
              if (_isSharedList)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Membros',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                  labelText: 'Email do membro'),
                              keyboardType: TextInputType.emailAddress,
                              onFieldSubmitted: (_) => _addMember(),
                            ),
                          ),
                          _isLookingUpUser
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ))
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Colors.deepPurple),
                                  onPressed: _addMember,
                                ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_invitedMemberEmails.isNotEmpty)
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _invitedMemberEmails
                              .map((email) => Chip(
                                    label: Text(email),
                                    onDeleted: () => setState(() =>
                                        _invitedMemberEmails.remove(email)),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isCreatingGroup
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _handleCreateGroupAction,
              child: const Icon(Icons.check),
            ),
    );
  }
}
