// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatHistoryMessage _$ChatHistoryMessageFromJson(Map<String, dynamic> json) =>
    ChatHistoryMessage(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageData: json['message_data'] as Map<String, dynamic>,
      translation: json['translation'] as String?,
      newVocabulary: _jsonbFromJson(json['new_vocabulary']),
      corrections: _jsonbFromJson(json['corrections']),
      followUpQuestion: json['follow_up_question'] as String?,
    );

Map<String, dynamic> _$ChatHistoryMessageToJson(ChatHistoryMessage instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'user_id': instance.userId,
      'timestamp': instance.timestamp.toIso8601String(),
      'message_data': _messageDataToJson(instance.messageData),
      'translation': instance.translation,
      'new_vocabulary': _jsonbToJson(instance.newVocabulary),
      'corrections': _jsonbToJson(instance.corrections),
      'follow_up_question': instance.followUpQuestion,
    };
