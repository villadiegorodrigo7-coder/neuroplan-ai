import 'package:uuid/uuid.dart';

class Task {
  final String id;
  String title;
  String description;
  bool isCompleted;
  DateTime createdAt;
  DateTime? dueDate;
  int priority; // 1=alta, 2=media, 3=baja

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    DateTime? createdAt,
    this.dueDate,
    this.priority = 2,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'],
        title: map['title'],
        description: map['description'] ?? '',
        isCompleted: map['isCompleted'] == 1,
        createdAt: DateTime.parse(map['createdAt']),
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
        priority: map['priority'] ?? 2,
      );
}
