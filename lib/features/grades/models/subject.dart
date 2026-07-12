class Subject {
  const Subject({required this.id, required this.name});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(id: json['id'] as int, name: json['name'] as String? ?? '');
  }

  final int id;
  final String name;
}
