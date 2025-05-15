import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Adicione esta linha

class ListPage extends StatefulWidget {
  final String groupId; // Modifique para groupId
  final String groupName; // Adicione groupName

  const ListPage({Key? key, required this.groupId, required this.groupName}) : super(key: key); // Modifique o construtor

  @override
  State<ListPage> createState() => _ListPageState();
  
}

class _ListPageState extends State<ListPage> {
  List<ItemData> _items = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _loadItems(); // Chame _loadItems() aqui para iniciar o Stream quando o widget for construído
    // Se você não usar um gerenciador de estado
  }

  
  Stream<List<ItemData>> _loadItems() {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('items')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return ItemData.fromJson({'id': doc.id, ...data});
        }).toList());
  }


  Future<void> _addItem(String name, int quantity) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('items')
          .add({'name': name, 'quantity': quantity, 'checked': false});
      print('Item "$name" adicionado à lista.');
    } catch (e) {
      print('Erro ao adicionar item "$name": $e');
      // Tratar o erro
    }
  }

  // Modifique _selectAllItems() para usar Firestore
  Future<void> _selectAllItems() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      _items.forEach((item) {
        batch.update(
          FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('items')
              .doc(item.id), // Assumindo que ItemData tem um 'id'
          {'checked': true},
        );
      });
      await batch.commit();
      print('Todos os itens marcados.');
    } catch (e) {
      print('Erro ao marcar todos os itens: $e');
      // Trate o erro
    }
  }

  // Modifique _removeSelectedItems() para usar Firestore
  Future<void> _removeSelectedItems() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      _items.where((item) => item.checked).forEach((item) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('items')
              .doc(item.id), // Assumindo que ItemData tem um 'id'
        );
      });
      await batch.commit();
      print('Itens selecionados removidos.');
    } catch (e) {
      print('Erro ao remover itens selecionados: $e');
      // Trate o erro
    }
  }

  // Modifique _showEditItemDialog() para usar Firestore
  Future<void> _showEditItemDialog(int index) async {
    final item = _items[index];
    final nameController = TextEditingController(text: item.name);
    final quantityController =
        TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome do item'),
            ),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final quantity =
                  int.tryParse(quantityController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('items')
                      .doc(item.id) // Assumindo que ItemData tem um 'id'
                      .update({'name': name, 'quantity': quantity});
                  print('Item editado.');
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Erro ao editar item: $e');
                  // Trate o erro
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Nome do item'),
            ),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity =
                  int.tryParse(quantityController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                _addItem(name, quantity);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade200,
        title: Text(widget.groupName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select_all') {
                _selectAllItems();
              } else if (value == 'remove_selected') {
                _removeSelectedItems();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'select_all',
                child: Text('Selecionar todos'),
              ),
              const PopupMenuItem(
                value: 'remove_selected',
                child: Text('Remover selecionados'),
              ),
            ],
          ),
        ],
      ),
      // Use StreamBuilder para exibir os itens do Firestore
      body: StreamBuilder<List<ItemData>>(
        stream: _loadItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar itens: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum item adicionado ainda.'));
          }

          _items = snapshot.data!; // Atualiza a lista local com os dados do Firestore

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade50,
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    decoration:
                        item.checked ? TextDecoration.lineThrough : null,
                    color:
                        item.checked ? Colors.black.withOpacity(0.5) : null,
                  ),
                ),
                trailing: Checkbox(
                  value: item.checked,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        item.checked = val;
                      });
                      // _saveItems(); // Não precisamos mais disso, pois o Firestore atualiza automaticamente
                      FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.groupId)
                          .collection('items')
                          .doc(item.id)
                          .update({'checked': val});
                    }
                  },
                ),
                onTap: () => _showEditItemDialog(index),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ItemData {
  String? id; // Adicionado: Campo para o ID do documento
  final String name;
  final int quantity;
  bool checked;

  ItemData({required this.name, required this.quantity, this.checked = false, this.id}); // Modificado o construtor

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      id: json['id'], // Adicionado: Extrai o ID do JSON
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      checked: json['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'checked': checked,
    };
  }
}