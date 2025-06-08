import 'package:json_annotation/json_annotation.dart';
import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/foundation.dart';
import 'package:llm_chat_app/services/logging_service.dart';
import 'user_vocabulary.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String email;
  @JsonKey(name: 'password_hash')
  final String? passwordHash; // Nullable for OAuth users
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  @JsonKey(name: 'is_premium')
  final bool isPremium;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_login_at')
  final DateTime? lastLoginAt;
  @JsonKey(name: 'profile_image_url')
  final String? profileImageUrl;
  @JsonKey(name: 'auth_provider')
  final String authProvider; // 'email', 'google', 'apple', etc.
  @JsonKey(name: 'provider_id')
  final String? providerId; // External provider ID
  final UserPreferences preferences;
  final UserStatistics statistics;

  User({
    required this.id,
    required this.email,
    this.passwordHash,
    required this.firstName,
    required this.lastName,
    this.isPremium = false,
    required this.createdAt,
    this.lastLoginAt,
    this.profileImageUrl,
    this.authProvider = 'email',
    this.providerId,
    required this.preferences,
    required this.statistics,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Legacy methods for backward compatibility
  Map<String, dynamic> toMap() => toJson();
  factory User.fromMap(Map<String, dynamic> map) => User.fromJson(map);

  // Supabase-specific methods
  Map<String, dynamic> toSupabase() {
    final LoggingService logger = LoggingService();
    logger.log(
        LogCategory.database, '=========== USER TOSUPABASE START ===========');
    final json = Map<String, dynamic>.from(toJson());

    logger.log(LogCategory.database,
        'User.toSupabase: Converting created_at: $createdAt');
    json['created_at'] = createdAt.toIso8601String();

    if (lastLoginAt != null) {
      logger.log(LogCategory.database,
          'User.toSupabase: Converting last_login_at: $lastLoginAt');
      json['last_login_at'] = lastLoginAt!.toIso8601String();
    }

    // Ensure preferences and statistics are JSON strings
    if (json['preferences'] is! String) {
      logger.log(LogCategory.database,
          'User.toSupabase: Converting preferences to JSON string');
      json['preferences'] = jsonEncode(json['preferences']);
    }
    if (json['statistics'] is! String) {
      logger.log(LogCategory.database,
          'User.toSupabase: Converting statistics to JSON string');
      json['statistics'] = jsonEncode(json['statistics']);
    }

    logger.log(LogCategory.database,
        'User.toSupabase: Data fields: ${json.keys.join(', ')}');
    logger.log(LogCategory.database,
        'User.toSupabase: ID: ${json['id']}, email: ${json['email']}');
    logger.log(LogCategory.database,
        'User.toSupabase: is_premium: ${json['is_premium']}');
    logger.log(
        LogCategory.database, '=========== USER TOSUPABASE END ===========');
    return json;
  }

  factory User.fromSupabase(Map<String, dynamic> data) {
    final LoggingService logger = LoggingService();
    final processedData = Map<String, dynamic>.from(data);

    logger.log(LogCategory.database,
        '[User.fromSupabase] Raw data: ${processedData.toString()}');
    logger.log(LogCategory.database,
        '[User.fromSupabase] created_at type: ${processedData['created_at']?.runtimeType.toString() ?? 'null'}');
    logger.log(LogCategory.database,
        '[User.fromSupabase] last_login_at type: ${processedData['last_login_at']?.runtimeType.toString() ?? 'null'}');
    logger.log(LogCategory.database,
        '[User.fromSupabase] is_premium value: ${processedData['is_premium']?.toString() ?? 'null'}');

    // Handle is_premium field
    if (processedData.containsKey('is_premium')) {
      if (processedData['is_premium'] is String) {
        processedData['is_premium'] =
            (processedData['is_premium'] as String).toLowerCase() == 'true';
      }
      // If it's already a bool, do nothing
    } else {
      processedData['is_premium'] = false;
    }
    logger.log(LogCategory.database,
        '[User.fromSupabase] Processed is_premium: ${processedData['is_premium']}');

    // Convert preferences and statistics from JSON string if necessary
    if (processedData['preferences'] is String) {
      logger.log(LogCategory.database,
          '[User.fromSupabase] Converting preferences to JSON string');
      processedData['preferences'] =
          jsonDecode(processedData['preferences'] as String);
    }
    if (processedData['statistics'] is String) {
      logger.log(LogCategory.database,
          '[User.fromSupabase] Converting statistics to JSON string');
      processedData['statistics'] =
          jsonDecode(processedData['statistics'] as String);
    }

    logger.log(LogCategory.database,
        '[User.fromSupabase] Final data for fromJson: ${processedData.toString()}');

    return User.fromJson(processedData);
  }

  // Firebase-specific methods
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    // Firebase handles DateTime automatically, but we can convert for consistency
    json['preferences'] = preferences.toMap();
    json['statistics'] = statistics.toMap();
    return json;
  }

  factory User.fromFirestore(Map<String, dynamic> data) {
    // Handle Firebase Timestamp objects
    if (data['created_at'] != null &&
        data['created_at'].runtimeType.toString().contains('Timestamp')) {
      data['created_at'] = (data['created_at'] as dynamic).toDate();
    }
    if (data['last_login_at'] != null &&
        data['last_login_at'].runtimeType.toString().contains('Timestamp')) {
      data['last_login_at'] = (data['last_login_at'] as dynamic).toDate();
    }

    // Parse nested objects
    if (data['preferences'] is Map) {
      data['preferences'] = UserPreferences.fromMap(data['preferences']);
    } else {
      data['preferences'] = UserPreferences();
    }

    if (data['statistics'] is Map) {
      data['statistics'] = UserStatistics.fromMap(data['statistics']);
    } else {
      data['statistics'] = UserStatistics();
    }

    return User.fromJson(data);
  }

  User copyWith({
    String? id,
    String? email,
    String? passwordHash,
    String? firstName,
    String? lastName,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? profileImageUrl,
    String? authProvider,
    String? providerId,
    UserPreferences? preferences,
    UserStatistics? statistics,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      authProvider: authProvider ?? this.authProvider,
      providerId: providerId ?? this.providerId,
      preferences: preferences ?? this.preferences,
      statistics: statistics ?? this.statistics,
    );
  }

  String get fullName => '$firstName $lastName';
  String get displayName => fullName.trim().isEmpty ? email : fullName;
  bool get isOAuthUser => authProvider != 'email';
}

@JsonSerializable()
class UserPreferences {
  @JsonKey(name: 'target_language')
  final String targetLanguage;
  @JsonKey(name: 'native_language')
  final String nativeLanguage;
  @JsonKey(name: 'support_language_1')
  final String? supportLanguage1;
  @JsonKey(name: 'support_language_2')
  final String? supportLanguage2;
  @JsonKey(name: 'notifications_enabled')
  final bool notificationsEnabled;
  @JsonKey(name: 'sound_enabled')
  final bool soundEnabled;
  final String theme; // 'light', 'dark', 'system'

  UserPreferences({
    this.targetLanguage = 'it',
    this.nativeLanguage = 'en',
    this.supportLanguage1 = 'es',
    this.supportLanguage2 = 'fr',
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.theme = 'system',
  });

  factory UserPreferences.fromJson(String jsonString) {
    try {
      if (jsonString.trim().isEmpty || jsonString == '{}') {
        return UserPreferences();
      }

      // Try to parse as JSON first
      final Map<String, dynamic> json = {};

      // Extract values using regex (fallback for simple JSON strings)
      final targetLang = RegExp(r'"target_language":\s*"([^"]*)"')
              .firstMatch(jsonString)
              ?.group(1) ??
          'it';
      final nativeLang = RegExp(r'"native_language":\s*"([^"]*)"')
              .firstMatch(jsonString)
              ?.group(1) ??
          'en';
      final supportLang1Match =
          RegExp(r'"support_language_1":\s*"([^"]*)"').firstMatch(jsonString);
      final supportLang2Match =
          RegExp(r'"support_language_2":\s*"([^"]*)"').firstMatch(jsonString);
      final notificationsMatch =
          RegExp(r'"notifications_enabled":\s*(true|false)')
              .firstMatch(jsonString);
      final soundMatch =
          RegExp(r'"sound_enabled":\s*(true|false)').firstMatch(jsonString);
      final themeMatch = RegExp(r'"theme":\s*"([^"]*)"').firstMatch(jsonString);

      json['target_language'] = targetLang;
      json['native_language'] = nativeLang;
      json['support_language_1'] = supportLang1Match?.group(1);
      json['support_language_2'] = supportLang2Match?.group(1);
      json['notifications_enabled'] = notificationsMatch?.group(1) == 'true';
      json['sound_enabled'] = soundMatch?.group(1) == 'true';
      json['theme'] = themeMatch?.group(1) ?? 'system';

      return _$UserPreferencesFromJson(json);
    } catch (e) {
      return UserPreferences();
    }
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) =>
      _$UserPreferencesFromJson(map);
  Map<String, dynamic> toMap() => _$UserPreferencesToJson(this);

  String toJson() {
    final map = toMap();
    return '''
{
  "target_language": "${map['target_language']}",
  "native_language": "${map['native_language']}",
  "support_language_1": ${map['support_language_1'] != null ? '"${map['support_language_1']}"' : 'null'},
  "support_language_2": ${map['support_language_2'] != null ? '"${map['support_language_2']}"' : 'null'},
  "notifications_enabled": ${map['notifications_enabled']},
  "sound_enabled": ${map['sound_enabled']},
  "theme": "${map['theme']}"
}''';
  }

  UserPreferences copyWith({
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? theme,
  }) {
    return UserPreferences(
      targetLanguage: targetLanguage ?? this.targetLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      supportLanguage1: supportLanguage1 ?? this.supportLanguage1,
      supportLanguage2: supportLanguage2 ?? this.supportLanguage2,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      theme: theme ?? this.theme,
    );
  }
}

@JsonSerializable()
class UserStatistics {
  @JsonKey(name: 'total_words_learned')
  final int totalWordsLearned;
  @JsonKey(name: 'total_messages_processed')
  final int totalMessagesProcessed;
  @JsonKey(name: 'streak_days')
  final int streakDays;
  @JsonKey(name: 'last_study_date')
  final DateTime? lastStudyDate;
  @JsonKey(name: 'language_progress')
  final Map<String, int> languageProgress; // language -> words learned
  @JsonKey(name: 'total_study_time_minutes')
  final int totalStudyTimeMinutes;

  UserStatistics({
    this.totalWordsLearned = 0,
    this.totalMessagesProcessed = 0,
    this.streakDays = 0,
    this.lastStudyDate,
    this.languageProgress = const {},
    this.totalStudyTimeMinutes = 0,
  });

  factory UserStatistics.fromMap(Map<String, dynamic> map) =>
      _$UserStatisticsFromJson(map);
  Map<String, dynamic> toMap() => _$UserStatisticsToJson(this);

  String toJson() {
    final map = toMap();
    final progressJson = (map['language_progress'] as Map<String, int>)
        .entries
        .map((e) => '"${e.key}": ${e.value}')
        .join(', ');

    return '''
{
  "total_words_learned": ${map['total_words_learned']},
  "total_messages_processed": ${map['total_messages_processed']},
  "streak_days": ${map['streak_days']},
  "last_study_date": ${map['last_study_date'] != null ? '"${(map['last_study_date'] as DateTime).toIso8601String()}"' : 'null'},
  "language_progress": {$progressJson},
  "total_study_time_minutes": ${map['total_study_time_minutes']}
}''';
  }

  factory UserStatistics.fromJson(String jsonString) {
    try {
      if (jsonString.trim().isEmpty || jsonString == '{}') {
        return UserStatistics();
      }

      // Extract values using regex
      final wordsMatch =
          RegExp(r'"total_words_learned":\s*(\d+)').firstMatch(jsonString);
      final messagesMatch =
          RegExp(r'"total_messages_processed":\s*(\d+)').firstMatch(jsonString);
      final streakMatch =
          RegExp(r'"streak_days":\s*(\d+)').firstMatch(jsonString);
      final studyDateMatch =
          RegExp(r'"last_study_date":\s*"([^"]*)"').firstMatch(jsonString);
      final studyTimeMatch =
          RegExp(r'"total_study_time_minutes":\s*(\d+)').firstMatch(jsonString);

      // Parse language progress
      final progressRegex = RegExp(r'"language_progress":\s*\{([^}]*)\}');
      final progressMatch = progressRegex.firstMatch(jsonString);
      Map<String, int> languageProgress = {};

      if (progressMatch != null && progressMatch.group(1) != null) {
        final progressContent = progressMatch.group(1)!;
        final entryRegex = RegExp(r'"([^"]+)":\s*(\d+)');
        for (final match in entryRegex.allMatches(progressContent)) {
          languageProgress[match.group(1)!] = int.parse(match.group(2)!);
        }
      }

      final json = {
        'total_words_learned': int.parse(wordsMatch?.group(1) ?? '0'),
        'total_messages_processed': int.parse(messagesMatch?.group(1) ?? '0'),
        'streak_days': int.parse(streakMatch?.group(1) ?? '0'),
        'last_study_date': studyDateMatch?.group(1) != null
            ? DateTime.parse(studyDateMatch!.group(1)!)
            : null,
        'language_progress': languageProgress,
        'total_study_time_minutes': int.parse(studyTimeMatch?.group(1) ?? '0'),
      };

      return _$UserStatisticsFromJson(json);
    } catch (e) {
      return UserStatistics();
    }
  }

  UserStatistics copyWith({
    int? totalWordsLearned,
    int? totalMessagesProcessed,
    int? streakDays,
    DateTime? lastStudyDate,
    Map<String, int>? languageProgress,
    int? totalStudyTimeMinutes,
  }) {
    return UserStatistics(
      totalWordsLearned: totalWordsLearned ?? this.totalWordsLearned,
      totalMessagesProcessed:
          totalMessagesProcessed ?? this.totalMessagesProcessed,
      streakDays: streakDays ?? this.streakDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      languageProgress: languageProgress ?? this.languageProgress,
      totalStudyTimeMinutes:
          totalStudyTimeMinutes ?? this.totalStudyTimeMinutes,
    );
  }
}
