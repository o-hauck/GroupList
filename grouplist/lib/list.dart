import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ListPage extends StatefulWidget {
  final String groupName;

  const ListPage({super.key, required this.groupName});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  List<ItemData> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(widget.groupName);
    if (itemsJson != null) {
      final List decoded = jsonDecode(itemsJson);
      setState(() {
        _items = decoded.map((e) => ItemData.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(widget.groupName, itemsJson);
  }

  void _addItem(String name, int quantity) {
    setState(() {
      _items.add(ItemData(name: name, quantity: quantity));
    });
    _saveItems();
  }

  void _selectAllItems() {
    setState(() {
      for (final item in _items) {
        item.checked = true;
      }
    });
    _saveItems();
  }

  void _removeSelectedItems() {
    setState(() {
      _items.removeWhere((item) => item.checked);
    });
    _saveItems();
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
      body: _items.isEmpty
          ? const Center(child: Text('Nenhum item adicionado ainda.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return CheckboxListTile(
                  title: Text(item.name),
                  value: item.checked,
                  secondary: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Text(
                      item.quantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      item.checked = val!;
                    });
                    _saveItems();
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
  final String name;
  final int quantity;
  bool checked;

  ItemData({required this.name, required this.quantity, this.checked = false});

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
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