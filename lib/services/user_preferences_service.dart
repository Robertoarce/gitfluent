import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import 'user_service.dart';
import 'logging_service.dart';
import '../config/supabase_config.dart';

class UserPreferencesService extends ChangeNotifier {
  static const String _userPrefsKey = 'user_preferences';
  static const String _guestPrefsKey = 'guest_preferences';

  late SharedPreferences _prefs;
  UserPreferences? _currentPreferences;
  UserService? _userService;
  bool _isInitialized = false;
  String? _currentUserId;
  final LoggingService _logger = LoggingService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Static callback for LanguageSettings synchronization
  static Function(Map<String, String>)? _languageSettingsCallback;

  UserPreferences? get currentPreferences => _currentPreferences;
  bool get isInitialized => _isInitialized;

  // Method to register LanguageSettings callback
  static void setLanguageSettingsCallback(
      Function(Map<String, String>) callback) {
    _languageSettingsCallback = callback;
  }

  // Initialize the service
  Future<void> init({UserService? userService}) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _userService = userService;

      // Listen to user changes if userService is provided
      if (_userService != null) {
        _userService!.addListener(_onUserChanged);
        _currentUserId = _userService!.currentUser?.id;
      }

      await _loadPreferences();
      _isInitialized = true;

      _logger.log(LogCategory.settingsService,
          'UserPreferencesService initialized successfully');
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error initializing UserPreferencesService: $e',
          isError: true);
      rethrow;
    }
  }

  // Handle user login/logout changes
  void _onUserChanged() {
    final newUserId = _userService?.currentUser?.id;
    if (newUserId != _currentUserId) {
      _logger.log(LogCategory.settingsService,
          'User changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;
      _loadPreferences().then((_) {
        notifyListeners();
      });
    }
  }

  // Load preferences based on current user state
  Future<void> _loadPreferences() async {
    try {
      UserPreferences? loadedPrefs;

      if (_currentUserId != null) {
        // Try to load from Supabase first for logged-in users
        loadedPrefs = await _loadFromSupabase(_currentUserId!);

        if (loadedPrefs != null) {
          _logger.log(LogCategory.settingsService,
              'Loaded user preferences from Supabase for user: $_currentUserId');
          _logger.log(LogCategory.settingsService,
              'Supabase preferences - Target Language: ${loadedPrefs.targetLanguage}');

          // Save to local storage as backup
          await _saveToLocalStorage(loadedPrefs, isUser: true);
        } else {
          // Fallback to local storage
          loadedPrefs = await _loadFromLocalStorage(isUser: true);
          _logger.log(LogCategory.settingsService,
              'Loaded user preferences from local storage (Supabase unavailable)');

          // If we have local preferences but Supabase was empty, sync to Supabase
          if (loadedPrefs != null) {
            await _saveToSupabase(loadedPrefs);
          }
        }
      } else {
        // Load guest preferences from local storage only
        loadedPrefs = await _loadFromLocalStorage(isUser: false);
        _logger.log(LogCategory.settingsService,
            'Loaded guest preferences from local storage');
      }

      // Use loaded preferences or create defaults
      _currentPreferences = loadedPrefs ?? UserPreferences();

      // Sync with language settings service
      await _syncWithLanguageSettings();
    } catch (e) {
      _logger.log(LogCategory.settingsService, 'Error loading preferences: $e',
          isError: true);
      _currentPreferences = UserPreferences(); // Fallback to defaults
    }
  }

  // Load preferences from Supabase
  Future<UserPreferences?> _loadFromSupabase(String userId) async {
    try {
      _logger.log(LogCategory.settingsService,
          'Loading preferences from Supabase for user: $userId');

      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('preferences')
          .eq('id', userId)
          .single();

      if (response != null && response['preferences'] != null) {
        final preferencesData = response['preferences'];

        if (preferencesData is Map<String, dynamic>) {
          return UserPreferences.fromMap(preferencesData);
        } else if (preferencesData is String) {
          return UserPreferences.fromJson(preferencesData);
        }
      }
      return null;
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error loading preferences from Supabase: $e',
          isError: true);
      return null;
    }
  }

  // Save preferences to Supabase
  Future<bool> _saveToSupabase(UserPreferences preferences) async {
    if (_currentUserId == null) return false;

    try {
      _logger.log(LogCategory.settingsService,
          'Saving preferences to Supabase for user: $_currentUserId');

      await _supabase.from(SupabaseConfig.usersTable).update({
        'preferences': preferences.toMap(),
      }).eq('id', _currentUserId!);

      _logger.log(LogCategory.settingsService,
          'Successfully saved preferences to Supabase');
      return true;
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error saving preferences to Supabase: $e',
          isError: true);
      return false;
    }
  }

  // Load preferences from local storage
  Future<UserPreferences?> _loadFromLocalStorage({required bool isUser}) async {
    try {
      String? prefsJson;

      if (isUser && _currentUserId != null) {
        final userPrefsKey = '${_userPrefsKey}_$_currentUserId';
        prefsJson = _prefs.getString(userPrefsKey);
      } else {
        prefsJson = _prefs.getString(_guestPrefsKey);
      }

      if (prefsJson != null && prefsJson.isNotEmpty) {
        return UserPreferences.fromJson(prefsJson);
      }
      return null;
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error loading preferences from local storage: $e',
          isError: true);
      return null;
    }
  }

  // Save preferences to local storage
  Future<void> _saveToLocalStorage(UserPreferences preferences,
      {required bool isUser}) async {
    try {
      final prefsJson = preferences.toJson();

      if (isUser && _currentUserId != null) {
        final userPrefsKey = '${_userPrefsKey}_$_currentUserId';
        await _prefs.setString(userPrefsKey, prefsJson);
        _logger.log(LogCategory.settingsService,
            'Saved user preferences to local storage for user: $_currentUserId');
      } else {
        await _prefs.setString(_guestPrefsKey, prefsJson);
        _logger.log(LogCategory.settingsService,
            'Saved guest preferences to local storage');
      }
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error saving preferences to local storage: $e',
          isError: true);
    }
  }

  // Save preferences to both Supabase and local storage
  Future<void> _savePreferences() async {
    if (_currentPreferences == null) return;

    try {
      // Always save to local storage first (immediate backup)
      await _saveToLocalStorage(_currentPreferences!,
          isUser: _currentUserId != null);

      // If user is logged in, try to save to Supabase
      if (_currentUserId != null) {
        final supabaseSuccess = await _saveToSupabase(_currentPreferences!);
        if (!supabaseSuccess) {
          _logger.log(LogCategory.settingsService,
              'Failed to save to Supabase, but local storage succeeded');
        }
      }
    } catch (e) {
      _logger.log(LogCategory.settingsService, 'Error saving preferences: $e',
          isError: true);
    }
  }

  // Sync with LanguageSettings service using callback mechanism
  Future<void> _syncWithLanguageSettings() async {
    try {
      if (_currentPreferences == null) return;

      // First, sync directly to SharedPreferences keys for backwards compatibility
      await _syncLanguageSettingsDirectly();

      // Then, use callback to notify LanguageSettings service
      if (_languageSettingsCallback != null) {
        final languageMap = {
          'target_language': _currentPreferences!.targetLanguage,
          'native_language': _currentPreferences!.nativeLanguage,
          'support_language_1': _currentPreferences!.supportLanguage1 ?? '',
          'support_language_2': _currentPreferences!.supportLanguage2 ?? '',
        };

        _languageSettingsCallback!(languageMap);
        _logger.log(LogCategory.settingsService,
            'Notified LanguageSettings via callback');
      } else {
        _logger.log(LogCategory.settingsService,
            'No LanguageSettings callback registered');
      }
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error syncing with language settings: $e',
          isError: true);
    }
  }

  // Alternative sync method using direct SharedPreferences
  Future<void> _syncLanguageSettingsDirectly() async {
    try {
      if (_currentPreferences == null) return;

      // Update SharedPreferences keys that LanguageSettings uses
      await _prefs.setString(
          'target_language', _currentPreferences!.targetLanguage);
      await _prefs.setString(
          'native_language', _currentPreferences!.nativeLanguage);

      if (_currentPreferences!.supportLanguage1 != null &&
          _currentPreferences!.supportLanguage1!.isNotEmpty) {
        await _prefs.setString(
            'support_language_1', _currentPreferences!.supportLanguage1!);
      } else {
        await _prefs.remove('support_language_1');
      }

      if (_currentPreferences!.supportLanguage2 != null &&
          _currentPreferences!.supportLanguage2!.isNotEmpty) {
        await _prefs.setString(
            'support_language_2', _currentPreferences!.supportLanguage2!);
      } else {
        await _prefs.remove('support_language_2');
      }

      _logger.log(LogCategory.settingsService,
          'Synced user preferences directly to SharedPreferences language keys');
      _logger.log(LogCategory.settingsService,
          'Target language synced: ${_currentPreferences!.targetLanguage}');
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error syncing language settings directly: $e',
          isError: true);
    }
  }

  // Update language preferences and sync to both Supabase and LanguageSettings
  Future<void> updateLanguagePreferences({
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
  }) async {
    if (_currentPreferences == null) return;

    _currentPreferences = _currentPreferences!.copyWith(
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      supportLanguage1: supportLanguage1,
      supportLanguage2: supportLanguage2,
    );

    await _savePreferences();
    await _syncWithLanguageSettings(); // Sync to LanguageSettings

    // Force immediate callback notification
    if (_languageSettingsCallback != null) {
      final languageMap = {
        'target_language': _currentPreferences!.targetLanguage,
        'native_language': _currentPreferences!.nativeLanguage,
        'support_language_1': _currentPreferences!.supportLanguage1 ?? '',
        'support_language_2': _currentPreferences!.supportLanguage2 ?? '',
      };

      _languageSettingsCallback!(languageMap);
      _logger.log(LogCategory.settingsService,
          'Force-notified LanguageSettings of preference update');
    }

    notifyListeners();

    _logger.log(LogCategory.settingsService,
        'Language preferences updated and synced to Supabase');
  }

  // Update UI preferences
  Future<void> updateUIPreferences({
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? theme,
  }) async {
    if (_currentPreferences == null) return;

    _currentPreferences = _currentPreferences!.copyWith(
      notificationsEnabled: notificationsEnabled,
      soundEnabled: soundEnabled,
      theme: theme,
    );

    await _savePreferences();
    notifyListeners();

    _logger.log(LogCategory.settingsService,
        'UI preferences updated and synced to Supabase');
  }

  // Get language preferences as a map for use with other services
  Map<String, String> getLanguagePreferencesMap() {
    if (_currentPreferences == null) {
      return {
        'target_language': 'it',
        'native_language': 'en',
        'support_language_1': 'es',
        'support_language_2': 'fr',
      };
    }

    return {
      'target_language': _currentPreferences!.targetLanguage,
      'native_language': _currentPreferences!.nativeLanguage,
      'support_language_1': _currentPreferences!.supportLanguage1 ?? 'es',
      'support_language_2': _currentPreferences!.supportLanguage2 ?? 'fr',
    };
  }

  // Clear all preferences (for logout or reset)
  Future<void> clearPreferences() async {
    try {
      // Clear local storage
      if (_currentUserId != null) {
        final userPrefsKey = '${_userPrefsKey}_$_currentUserId';
        await _prefs.remove(userPrefsKey);
      } else {
        await _prefs.remove(_guestPrefsKey);
      }

      // Reset to defaults
      _currentPreferences = UserPreferences();

      // If user is logged in, update Supabase with defaults
      if (_currentUserId != null) {
        await _saveToSupabase(_currentPreferences!);
      }

      await _syncWithLanguageSettings(); // Sync defaults back to LanguageSettings
      notifyListeners();

      _logger.log(LogCategory.settingsService,
          'Preferences cleared and synced to Supabase');
    } catch (e) {
      _logger.log(LogCategory.settingsService, 'Error clearing preferences: $e',
          isError: true);
    }
  }

  // Force reload from storage (tries Supabase first, then local)
  Future<void> reload() async {
    if (_isInitialized) {
      await _loadPreferences();
      notifyListeners();
      _logger.log(LogCategory.settingsService,
          'User preferences reloaded from Supabase/local storage');
    }
  }

  // Migrate guest preferences to user account (when user logs in)
  Future<void> migrateGuestToUser(String userId) async {
    try {
      final guestPrefsJson = _prefs.getString(_guestPrefsKey);
      if (guestPrefsJson != null && guestPrefsJson.isNotEmpty) {
        final guestPrefs = UserPreferences.fromJson(guestPrefsJson);

        // Save guest preferences to the new user account in both local and Supabase
        _currentUserId = userId;
        _currentPreferences = guestPrefs;

        await _savePreferences(); // This will save to both local and Supabase
        await _prefs.remove(_guestPrefsKey); // Remove guest preferences

        _logger.log(LogCategory.settingsService,
            'Migrated guest preferences to user account and Supabase');
      }
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error migrating guest preferences: $e',
          isError: true);
    }
  }

  // Sync local changes to Supabase (useful for offline scenarios)
  Future<bool> syncToSupabase() async {
    if (_currentPreferences == null || _currentUserId == null) return false;

    return await _saveToSupabase(_currentPreferences!);
  }

  // Check if there are unsaved changes that need to be synced to Supabase
  Future<bool> hasUnsyncedChanges() async {
    if (_currentPreferences == null || _currentUserId == null) return false;

    try {
      final supabasePrefs = await _loadFromSupabase(_currentUserId!);
      if (supabasePrefs == null)
        return true; // Local exists but Supabase doesn't

      // Compare current preferences with what's in Supabase
      return _currentPreferences!.toJson() != supabasePrefs.toJson();
    } catch (e) {
      return true; // Assume there are unsynced changes if we can't check
    }
  }

  // Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'currentUserId': _currentUserId,
      'hasPreferences': _currentPreferences != null,
      'preferences': _currentPreferences?.toMap(),
      'hasLanguageCallback': _languageSettingsCallback != null,
    };
  }

  @override
  void dispose() {
    _userService?.removeListener(_onUserChanged);
    super.dispose();
  }
}
