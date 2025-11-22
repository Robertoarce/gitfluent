// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PodcastScript _$PodcastScriptFromJson(Map<String, dynamic> json) =>
    PodcastScript(
      title: json['title'] as String,
      topic: json['topic'] as String,
      dialogue: (json['dialogue'] as List<dynamic>)
          .map((e) => DialogueItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PodcastScriptToJson(PodcastScript instance) =>
    <String, dynamic>{
      'title': instance.title,
      'topic': instance.topic,
      'dialogue': instance.dialogue,
    };

DialogueItem _$DialogueItemFromJson(Map<String, dynamic> json) => DialogueItem(
      speaker: json['speaker'] as String,
      text: json['text'] as String,
      languageCode: json['language_code'] as String,
    );

Map<String, dynamic> _$DialogueItemToJson(DialogueItem instance) =>
    <String, dynamic>{
      'speaker': instance.speaker,
      'text': instance.text,
      'language_code': instance.languageCode,
    };
