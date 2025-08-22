import 'package:json_annotation/json_annotation.dart';
import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/foundation.dart';

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
  @JsonKey(name: 'target_language')
  final String?
      targetLanguage; // Individual language fields for backwards compatibility
  @JsonKey(name: 'native_language')
  final String? nativeLanguage;
  @JsonKey(name: 'support_language_1')
  final String? supportLanguage1;
  @JsonKey(name: 'support_language_2')
  final String? supportLanguage2;
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
    this.targetLanguage,
    this.nativeLanguage,
    this.supportLanguage1,
    this.supportLanguage2,
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
    debugPrint('=========== USER TOSUPABASE START ===========');
    // Create a copy of the JSON data
    final json = Map<String, dynamic>.from(toJson());

    // Convert DateTime to ISO strings for Supabase
    debugPrint('User.toSupabase: Converting created_at: ${createdAt}');
    json['created_at'] = createdAt.toIso8601String();

    if (lastLoginAt != null) {
      debugPrint('User.toSupabase: Converting last_login_at: ${lastLoginAt}');
      json['last_login_at'] = lastLoginAt!.toIso8601String();
    }

    // Make sure preferences and statistics are JSON strings
    if (json['preferences'] is! String) {
      debugPrint('User.toSupabase: Converting preferences to JSON string');
      json['preferences'] = preferences.toJson();
    }

    if (json['statistics'] is! String) {
      debugPrint('User.toSupabase: Converting statistics to JSON string');
      json['statistics'] = statistics.toJson();
    }

    // Log the final data for debugging
    debugPrint('User.toSupabase: Data fields: ${json.keys.join(', ')}');
    debugPrint('User.toSupabase: ID: ${json['id']}, email: ${json['email']}');
    debugPrint('User.toSupabase: is_premium: ${json['is_premium']}');
    debugPrint('=========== USER TOSUPABASE END ===========');
    return json;
  }

  factory User.fromSupabase(Map<String, dynamic> data) {
    // Create a copy of the data to avoid modifying the original
    final Map<String, dynamic> processedData = Map<String, dynamic>.from(data);

    // Debug logs for tracing
    print('[User.fromSupabase] 🔍 LANGUAGE CORRUPTION TRACKER: Raw data: ' +
        processedData.toString());
    print(
        '[User.fromSupabase] 🔍 RAW target_language: "${processedData['target_language']}" (${processedData['target_language']?.runtimeType})');
    print(
        '[User.fromSupabase] 🔍 RAW native_language: "${processedData['native_language']}" (${processedData['native_language']?.runtimeType})');
    print('[User.fromSupabase] created_at type: ' +
        (processedData['created_at']?.runtimeType.toString() ?? 'null'));
    print('[User.fromSupabase] last_login_at type: ' +
        (processedData['last_login_at']?.runtimeType.toString() ?? 'null'));
    print('[User.fromSupabase] is_premium value: ' +
        (processedData['is_premium']?.toString() ?? 'null'));

    // Handle DateTime fields
    if (processedData['created_at'] != null) {
      if (processedData['created_at'] is String) {
        // Already a string, no conversion needed
      } else if (processedData['created_at'] is DateTime) {
        processedData['created_at'] =
            (processedData['created_at'] as DateTime).toIso8601String();
      } else {
        // Convert to string
        processedData['created_at'] = processedData['created_at'].toString();
      }
    }

    if (processedData['last_login_at'] != null) {
      if (processedData['last_login_at'] is String) {
        // Already a string, no conversion needed
      } else if (processedData['last_login_at'] is DateTime) {
        processedData['last_login_at'] =
            (processedData['last_login_at'] as DateTime).toIso8601String();
      } else {
        // Convert to string
        processedData['last_login_at'] =
            processedData['last_login_at'].toString();
      }
    }

    // Ensure premium status is properly set
    if (processedData.containsKey('is_premium')) {
      // Ensure proper boolean conversion - Supabase might return it as a string or number
      if (processedData['is_premium'] is String) {
        processedData['is_premium'] =
            processedData['is_premium'].toLowerCase() == 'true';
      } else if (processedData['is_premium'] is num) {
        processedData['is_premium'] = processedData['is_premium'] != 0;
      }
      print(
          '[User.fromSupabase] Processed is_premium: ${processedData['is_premium']}');
    } else {
      print(
          '[User.fromSupabase] is_premium field missing, defaulting to false');
      processedData['is_premium'] = false;
    }

    // Handle corrupted language fields - convert string "null" to actual null
    final languageFields = [
      'target_language',
      'native_language',
      'support_language_1',
      'support_language_2'
    ];

    print('[User.fromSupabase] 🔍 BEFORE null fixing:');
    for (final field in languageFields) {
      print(
          '[User.fromSupabase] 🔍   $field: "${processedData[field]}" (${processedData[field]?.runtimeType})');
    }

    for (final field in languageFields) {
      if (processedData[field] == 'null') {
        print(
            '[User.fromSupabase] Fixed corrupted language field $field: "null" → null');
        processedData[field] = null;
      }
    }

    print('[User.fromSupabase] 🔍 AFTER null fixing:');
    for (final field in languageFields) {
      print(
          '[User.fromSupabase] 🔍   $field: "${processedData[field]}" (${processedData[field]?.runtimeType})');
    }

    // Always pass preferences/statistics as JSON strings
    if (processedData['preferences'] is! String) {
      print('[User.fromSupabase] Converting preferences to JSON string');
      processedData['preferences'] =
          jsonEncode(processedData['preferences'] ?? {});
    }

    if (processedData['statistics'] is! String) {
      print('[User.fromSupabase] Converting statistics to JSON string');
      processedData['statistics'] =
          jsonEncode(processedData['statistics'] ?? {});
    }

    print('[User.fromSupabase] Final data for fromJson: ' +
        processedData.toString());
    print(
        '[User.fromSupabase] 🔍 TRACKING: Creating user with target_language: ${processedData['target_language']} at ${DateTime.now()}');
    final user = User.fromJson(processedData);
    print(
        '[User.fromSupabase] 🔍 TRACKING: Created user object - target: "${user.targetLanguage}", native: "${user.nativeLanguage}"');
    print('[User.fromSupabase] 🔍 FINAL USER OBJECT LANGUAGE VALUES:');
    print(
        '   🔍 user.targetLanguage: "${user.targetLanguage}" (${user.targetLanguage?.runtimeType})');
    print(
        '   🔍 user.nativeLanguage: "${user.nativeLanguage}" (${user.nativeLanguage?.runtimeType})');
    print(
        '   🔍 user.supportLanguage1: "${user.supportLanguage1}" (${user.supportLanguage1?.runtimeType})');
    print(
        '   🔍 user.supportLanguage2: "${user.supportLanguage2}" (${user.supportLanguage2?.runtimeType})');
    return user;
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
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
    UserPreferences? preferences,
    UserStatistics? statistics,
  }) {
    // 🔍 TRACK LANGUAGE CORRUPTION IN COPYWITH
    final newTargetLang = targetLanguage ?? this.targetLanguage;
    final newNativeLang = nativeLanguage ?? this.nativeLanguage;
    print(
        '🔍 COPYWITH TRACKING: target: "${this.targetLanguage}" → "${newTargetLang}", native: "${this.nativeLanguage}" → "${newNativeLang}"');

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
      targetLanguage: newTargetLang,
      nativeLanguage: newNativeLang,
      supportLanguage1: supportLanguage1 ?? this.supportLanguage1,
      supportLanguage2: supportLanguage2 ?? this.supportLanguage2,
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
  @JsonKey(name: 'notifications_enabled')
  final bool notificationsEnabled;
  @JsonKey(name: 'sound_enabled')
  final bool soundEnabled;
  final String theme; // 'light', 'dark', 'system'

  UserPreferences({
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
      final notificationsMatch =
          RegExp(r'"notifications_enabled":\s*(true|false)')
              .firstMatch(jsonString);
      final soundMatch =
          RegExp(r'"sound_enabled":\s*(true|false)').firstMatch(jsonString);
      final themeMatch = RegExp(r'"theme":\s*"([^"]*)"').firstMatch(jsonString);

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
  "notifications_enabled": ${map['notifications_enabled']},
  "sound_enabled": ${map['sound_enabled']},
  "theme": "${map['theme']}"
}''';
  }

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? theme,
  }) {
    return UserPreferences(
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
