import 'package:uuid/uuid.dart';

class WorkoutClass {
  final String id;
  final String name;
  final int totalDurationMinutes;
  final List<WorkoutBlock> blocks;
  final DateTime createdAt;

  WorkoutClass({
    String? id,
    required this.name,
    required this.totalDurationMinutes,
    required this.blocks,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalDurationMinutes': totalDurationMinutes,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkoutClass.fromJson(Map<String, dynamic> json) {
    return WorkoutClass(
      id: json['id'],
      name: json['name'],
      totalDurationMinutes: json['totalDurationMinutes'],
      blocks: (json['blocks'] as List)
          .map((b) => WorkoutBlock.fromJson(b))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

enum BlockType { warmUp, strength, metcon, finisher, custom }

class WorkoutBlock {
  final String id;
  final String name;
  final int durationMinutes;
  final BlockType blockType;
  final List<String> exercises;

  // Configuración avanzada
  final int rounds;
  final int workMinutes;
  final int workSeconds;
  final int restMinutes;
  final int restSeconds;

  WorkoutBlock({
    String? id,
    required this.name,
    required this.durationMinutes,
    required this.blockType,
    List<String>? exercises,
    this.rounds = 4,
    this.workMinutes = 3,
    this.workSeconds = 0,
    this.restMinutes = 1,
    this.restSeconds = 0,
  })  : id = id ?? const Uuid().v4(),
        exercises = exercises ?? [];
}

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'type': type.toString(),
        'exercises': exercises,
        'notes': notes,
      };

  factory WorkoutBlock.fromJson(Map<String, dynamic> json) {
    return WorkoutBlock(
      id: json['id'],
      name: json['name'],
      durationMinutes: json['durationMinutes'],
      type: BlockType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      exercises: List<String>.from(json['exercises']),
      notes: json['notes'],
    );
  }
}