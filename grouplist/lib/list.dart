// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart'; // Importe o helper do banco de dados

class ListPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ListPage({super.key, required this.groupId, required this.groupName});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final dbHelper = DatabaseHelper();
  List<ItemData> _localItems = [];

  @override
  void initState() {
    super.initState();
    _loadAndSyncItems();
  }

  // Carrega itens do cache local e sincroniza com o Firebase.
  Future<void> _loadAndSyncItems() async {
    final localData = await dbHelper.getItems(widget.groupId);
    if (mounted) {
      setState(() {
        _localItems = localData;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('items')
          .get();

      final firebaseItems = snapshot.docs.map((doc) {
        return ItemData.fromJson({'id': doc.id, ...doc.data()});
      }).toList();

      await dbHelper.clearItemsForGroup(widget.groupId);
      for (var item in firebaseItems) {
        await dbHelper.insertOrUpdateItem(item, widget.groupId);
      }

      final updatedLocalData = await dbHelper.getItems(widget.groupId);
      if (mounted) {
        setState(() {
          _localItems = updatedLocalData;
        });
      }
    } catch (e) {
      print('Falha ao sincronizar itens com o Firebase: $e');
    }
  }

  Future<void> _addItem(String name, int quantity) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('items')
          .add({'name': name, 'quantity': quantity, 'checked': false});
      
      final newItem = ItemData(id: docRef.id, name: name, quantity: quantity, checked: false);
      await dbHelper.insertOrUpdateItem(newItem, widget.groupId);

      // Atualiza a UI imediatamente de forma otimista
      setState(() {
        _localItems.add(newItem);
      });

    } catch (e) {
      print('Erro ao adicionar item "$name": $e');
    }
  }

  Future<void> _updateItemCheckedStatus(ItemData item, bool isChecked) async {
    setState(() {
      item.checked = isChecked;
    });

    try {
      // Atualiza primeiro o local para uma resposta de UI imediata
      await dbHelper.insertOrUpdateItem(item, widget.groupId);
      // Depois atualiza o Firebase
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('items')
          .doc(item.id)
          .update({'checked': isChecked});
    } catch (e) {
      print('Erro ao atualizar status do item: $e');
      // Reverte a mudança na UI em caso de erro
      setState(() {
        item.checked = !isChecked;
      });
    }
  }
  
  Future<void> _selectAllItems() async {
    final batch = FirebaseFirestore.instance.batch();
    List<ItemData> itemsToUpdate = [];

    for (var item in _localItems) {
      if (!item.checked) {
        itemsToUpdate.add(item);
        final docRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('items')
            .doc(item.id);
        batch.update(docRef, {'checked': true});
      }
    }
    
    if (itemsToUpdate.isEmpty) return;

    try {
      await batch.commit();
      for(var item in itemsToUpdate) {
        item.checked = true;
        await dbHelper.insertOrUpdateItem(item, widget.groupId);
      }
      setState(() {});
    } catch (e) {
      print('Erro ao marcar todos os itens: $e');
    }
  }

  Future<void> _removeSelectedItems() async {
    final itemsToRemove = _localItems.where((item) => item.checked).toList();
    if (itemsToRemove.isEmpty) return;
    
    final batch = FirebaseFirestore.instance.batch();
    for (var item in itemsToRemove) {
      final docRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('items')
          .doc(item.id);
      batch.delete(docRef);
    }
    
    try {
      await batch.commit();
      for (var item in itemsToRemove) {
        await dbHelper.deleteItem(item.id!);
      }
      setState(() {
        _localItems.removeWhere((item) => item.checked);
      });
    } catch (e) {
      print('Erro ao remover itens selecionados: $e');
    }
  }

  Future<void> _showEditItemDialog(int index) async {
    final item = _localItems[index];
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do item')),
            TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                final updatedItem = ItemData(id: item.id, name: name, quantity: quantity, checked: item.checked);
                try {
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('items')
                      .doc(item.id)
                      .update({'name': name, 'quantity': quantity});

                  await dbHelper.insertOrUpdateItem(updatedItem, widget.groupId);
                  
                  setState(() {
                    _localItems[index] = updatedItem;
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Erro ao editar item: $e');
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
            TextField(controller: nameController, maxLength: 50, decoration: const InputDecoration(labelText: 'Nome do item')),
            TextField(controller: quantityController, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Quantidade')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
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
              const PopupMenuItem(value: 'select_all', child: Text('Selecionar todos')),
              const PopupMenuItem(value: 'remove_selected', child: Text('Remover selecionados')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAndSyncItems,
        child: _localItems.isEmpty
            ? const Center(child: Text('Nenhum item adicionado ainda.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _localItems.length,
                itemBuilder: (context, index) {
                  final item = _localItems[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade50,
                      child: Text(item.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        decoration: item.checked ? TextDecoration.lineThrough : null,
                        color: item.checked ? Colors.black.withOpacity(0.5) : null,
                      ),
                    ),
                    trailing: Checkbox(
                      value: item.checked,
                      onChanged: (val) {
                        if (val != null) {
                          _updateItemCheckedStatus(item, val);
                        }
                      },
                    ),
                    onTap: () => _showEditItemDialog(index),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
class ItemData {
  String? id;
  final String name;
  final int quantity;
  bool checked;

  ItemData({required this.name, required this.quantity, this.checked = false, this.id});

  // Usado para o Firebase
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'checked': checked,
    };
  }

  // Usado para o SQLite
  Map<String, dynamic> toJsonForDb(String groupId) {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'quantity': quantity,
      'checked': checked ? 1 : 0, // SQLite usa 1 para true e 0 para false
    };
  }

  // Cria um objeto a partir de um Map
  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      id: json['id'],
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      checked: json['checked'] is bool ? json['checked'] : json['checked'] == 1,
    );
  }
}