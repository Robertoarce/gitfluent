import 'package:json_annotation/json_annotation.dart';

part 'podcast.g.dart';

@JsonSerializable()
class PodcastScript {
  final String title;
  final String topic;
  final List<DialogueItem> dialogue;

  PodcastScript({
    required this.title,
    required this.topic,
    required this.dialogue,
  });

  factory PodcastScript.fromJson(Map<String, dynamic> json) => _$PodcastScriptFromJson(json);
  Map<String, dynamic> toJson() => _$PodcastScriptToJson(this);
}

@JsonSerializable()
class DialogueItem {
  final String speaker; // "Host", "Guest", "Teacher", "Student"
  final String text;
  @JsonKey(name: 'language_code')
  final String languageCode; // "en", "it", etc.

  DialogueItem({
    required this.speaker,
    required this.text,
    required this.languageCode,
  });

  factory DialogueItem.fromJson(Map<String, dynamic> json) => _$DialogueItemFromJson(json);
  Map<String, dynamic> toJson() => _$DialogueItemToJson(this);
}
