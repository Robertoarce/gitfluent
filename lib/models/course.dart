import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'course.g.dart';

@JsonSerializable()
class Course {
  final String id;
  final String title;
  final String description;
  @JsonKey(name: 'target_language')
  final String targetLanguage;
  @JsonKey(name: 'native_language')
  final String nativeLanguage;
  final String level; // Beginner, Intermediate, Advanced
  final List<Module> modules;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'is_generated')
  final bool isGenerated;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.level,
    this.modules = const [],
    required this.createdAt,
    this.isGenerated = false,
  });

  factory Course.create({
    required String title,
    required String description,
    required String targetLanguage,
    required String nativeLanguage,
    required String level,
    bool isGenerated = false,
  }) {
    return Course(
      id: const Uuid().v4(),
      title: title,
      description: description,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      level: level,
      createdAt: DateTime.now(),
      isGenerated: isGenerated,
    );
  }

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
  Map<String, dynamic> toJson() => _$CourseToJson(this);
}

@JsonSerializable()
class Module {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;

  Module({
    required this.id,
    required this.title,
    required this.description,
    this.lessons = const [],
  });

  factory Module.fromJson(Map<String, dynamic> json) => _$ModuleFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleToJson(this);
}

@JsonSerializable()
class Lesson {
  final String id;
  final String title;
  final String content; // Markdown content
  @JsonKey(name: 'vocabulary_ids')
  final List<String> vocabularyIds;
  @JsonKey(name: 'is_completed')
  final bool isCompleted;

  Lesson({
    required this.id,
    required this.title,
    required this.content,
    this.vocabularyIds = const [],
    this.isCompleted = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
  Map<String, dynamic> toJson() => _$LessonToJson(this);
  
  Lesson copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? vocabularyIds,
    bool? isCompleted,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      vocabularyIds: vocabularyIds ?? this.vocabularyIds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
