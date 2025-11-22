// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Course _$CourseFromJson(Map<String, dynamic> json) => Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      targetLanguage: json['target_language'] as String,
      nativeLanguage: json['native_language'] as String,
      level: json['level'] as String,
      modules: (json['modules'] as List<dynamic>?)
              ?.map((e) => Module.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      isGenerated: json['is_generated'] as bool? ?? false,
    );

Map<String, dynamic> _$CourseToJson(Course instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'target_language': instance.targetLanguage,
      'native_language': instance.nativeLanguage,
      'level': instance.level,
      'modules': instance.modules,
      'created_at': instance.createdAt.toIso8601String(),
      'is_generated': instance.isGenerated,
    };

Module _$ModuleFromJson(Map<String, dynamic> json) => Module(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((e) => Lesson.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ModuleToJson(Module instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'lessons': instance.lessons,
    };

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      vocabularyIds: (json['vocabulary_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isCompleted: json['is_completed'] as bool? ?? false,
    );

Map<String, dynamic> _$LessonToJson(Lesson instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'vocabulary_ids': instance.vocabularyIds,
      'is_completed': instance.isCompleted,
    };
