// lib/list.dart (VERSÃO FINAL E COMPLETA)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_options_screen.dart'; // Tela que vamos criar a seguir

// Modelo de dados para um item
class ItemData {
  String id;
  final String name;
  final int quantity;
  bool isChecked;

  ItemData({
    this.id = '',
    required this.name,
    required this.quantity,
    this.isChecked = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'isChecked': isChecked,
  };

  factory ItemData.fromJson(String id, Map<String, dynamic> json) => ItemData(
    id: id,
    name: json['name'] as String,
    quantity: json['quantity'] as int,
    isChecked: json['isChecked'] as bool,
  );
}


class ListPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ListPage({super.key, required this.groupId, required this.groupName});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  // Referência para a subcoleção de itens no Firestore
  late final CollectionReference<Map<String, dynamic>> _itemsCollection;

  @override
  void initState() {
    super.initState();
    _itemsCollection = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('items');
  }

  // Adiciona um novo item
  Future<void> _addItem(String name, int quantity) async {
    if (name.isEmpty) return;
    await _itemsCollection.add({
      'name': name,
      'quantity': quantity,
      'isChecked': false,
      'createdAt': FieldValue.serverTimestamp(), // Para ordenar depois
    });
  }

  // Atualiza o status (marcado/desmarcado) de um item
  Future<void> _updateItemCheckedStatus(String itemId, bool isChecked) async {
    await _itemsCollection.doc(itemId).update({'isChecked': isChecked});
  }
  
  // Remove os itens que foram marcados
  Future<void> _removeSelectedItems() async {
    final batch = FirebaseFirestore.instance.batch();
    
    // Pega todos os itens que estão marcados
    final snapshot = await _itemsCollection.where('isChecked', isEqualTo: true).get();

    if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum item selecionado para remover.'))
        );
        return;
    }

    // Adiciona a operação de delete no batch
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  // Exibe o dialog para adicionar um novo item
  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do item'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
              _addItem(name, quantity);
              Navigator.of(context).pop();
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
        title: Text(widget.groupName),
        actions: [
          // NOVO: Menu de opções
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'options') {
                 Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GroupOptionsScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                  ),
                ));
              } else if (value == 'remove_selected') {
                _removeSelectedItems();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'options',
                child: Text('Opções do Grupo'),
              ),
              const PopupMenuItem(
                value: 'remove_selected',
                child: Text('Remover Selecionados'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _itemsCollection.orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum item neste grupo.'));
          }

          final items = snapshot.data!.docs.map((doc) {
            return ItemData.fromJson(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: CircleAvatar(child: Text(item.quantity.toString())),
                title: Text(
                  item.name,
                  style: TextStyle(
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked ? Colors.grey : null,
                  ),
                ),
                trailing: Checkbox(
                  value: item.isChecked,
                  onChanged: (val) => _updateItemCheckedStatus(item.id, val ?? false),
                ),
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