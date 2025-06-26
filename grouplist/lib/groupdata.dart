// lib/groupdata.dart

class GroupData {
  String? id;
  final String name;
  final String category;

  GroupData(this.name, this.category, {this.id});

  // Usado para enviar dados ao Firebase (NÃO inclui o ID)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
    };
  }

  // Usado para salvar dados no SQLite (INCLUI o ID)
  Map<String, dynamic> toJsonForDb() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }

  // Cria um objeto GroupData a partir de um Map (seja do Firebase ou SQLite)
  factory GroupData.fromJson(Map<String, dynamic> json) {
    return GroupData(
      json['name'],
      json['category'],
      id: json['id'],
    );
  }
}