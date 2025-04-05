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

  void _clearList() {
    setState(() {
      _items.clear();
    });
    _saveItems();
  }

  void _removeSelected() {
    setState(() {
      _items.removeWhere((item) => item.checked);
    });
    _saveItems();
  }

  void _showOptionsMenu() async {
    final result = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
      items: [
        const PopupMenuItem(value: 'clear', child: Text('Limpar lista')),
        const PopupMenuItem(value: 'removeSelected', child: Text('Remover selecionados')),
      ],
    );

    if (result == 'clear') {
      _clearList();
    } else if (result == 'removeSelected') {
      _removeSelected();
    }
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsMenu,
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