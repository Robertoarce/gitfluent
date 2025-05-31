// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at'] as String),
      profileImageUrl: json['profile_image_url'] as String?,
      authProvider: json['auth_provider'] as String? ?? 'email',
      providerId: json['provider_id'] as String?,
      preferences: UserPreferences.fromJson(json['preferences'] as String),
      statistics: UserStatistics.fromJson(json['statistics'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'password_hash': instance.passwordHash,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'is_premium': instance.isPremium,
      'created_at': instance.createdAt.toIso8601String(),
      'last_login_at': instance.lastLoginAt?.toIso8601String(),
      'profile_image_url': instance.profileImageUrl,
      'auth_provider': instance.authProvider,
      'provider_id': instance.providerId,
      'preferences': instance.preferences,
      'statistics': instance.statistics,
    };

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    UserPreferences(
      targetLanguage: json['target_language'] as String? ?? 'it',
      nativeLanguage: json['native_language'] as String? ?? 'en',
      supportLanguage1: json['support_language_1'] as String? ?? 'es',
      supportLanguage2: json['support_language_2'] as String? ?? 'fr',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      theme: json['theme'] as String? ?? 'system',
    );

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) =>
    <String, dynamic>{
      'target_language': instance.targetLanguage,
      'native_language': instance.nativeLanguage,
      'support_language_1': instance.supportLanguage1,
      'support_language_2': instance.supportLanguage2,
      'notifications_enabled': instance.notificationsEnabled,
      'sound_enabled': instance.soundEnabled,
      'theme': instance.theme,
    };

UserStatistics _$UserStatisticsFromJson(Map<String, dynamic> json) =>
    UserStatistics(
      totalWordsLearned: (json['total_words_learned'] as num?)?.toInt() ?? 0,
      totalMessagesProcessed:
          (json['total_messages_processed'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      lastStudyDate: json['last_study_date'] == null
          ? null
          : DateTime.parse(json['last_study_date'] as String),
      languageProgress:
          (json['language_progress'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
      totalStudyTimeMinutes:
          (json['total_study_time_minutes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UserStatisticsToJson(UserStatistics instance) =>
    <String, dynamic>{
      'total_words_learned': instance.totalWordsLearned,
      'total_messages_processed': instance.totalMessagesProcessed,
      'streak_days': instance.streakDays,
      'last_study_date': instance.lastStudyDate?.toIso8601String(),
      'language_progress': instance.languageProgress,
      'total_study_time_minutes': instance.totalStudyTimeMinutes,
    };
