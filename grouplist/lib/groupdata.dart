class GroupData {
  final String name;
  final String category;

  GroupData(this.name, this.category);

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
      };

  static GroupData fromJson(Map<String, dynamic> json) =>
      GroupData(json['name'], json['category']);
}