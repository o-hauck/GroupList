// lib/groupdata.dart

class GroupData {
  String id; // ID do documento no Firestore
  final String name;
  final String category;
  final List<String> membersUids; // Lista de UIDs dos membros
  final String createdByUid; // UID de quem criou o grupo

  GroupData({
    this.id = '',
    required this.name,
    required this.category,
    required this.membersUids,
    required this.createdByUid,
  });

  // Converte um objeto GroupData para um Map (JSON) para salvar no Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'membersUids': membersUids,
      'createdByUid': createdByUid,
    };
  }

  // Cria um objeto GroupData a partir de um Map (JSON) vindo do Firestore
  factory GroupData.fromJson(String id, Map<String, dynamic> json) {
    return GroupData(
      id: id,
      name: json['name'] as String,
      category: json['category'] as String,
      // Garante que a lista seja do tipo correto
      membersUids: List<String>.from(json['membersUids'] as List),
      createdByUid: json['createdByUid'] as String,
    );
  }
}