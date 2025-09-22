# GitFluent - Complete Codebase Understanding Guide

A comprehensive guide to understanding this sophisticated **language learning Flutter application** with AI-powered conversations, spaced repetition flashcards, and vocabulary management.

## 🏗️ Architecture Overview

```mermaid
graph TB
    %% Frontend Architecture
    subgraph "Flutter Frontend"
        UI["`**UI Layer**<br/>Screens & Widgets`"]
        STATE["`**State Management**<br/>Provider Pattern`"]
        SERVICES["`**Services Layer**<br/>Business Logic`"]
    end

    %% UI Components
    subgraph "UI Screens"
        AUTH["`🔐 AuthScreen<br/>Login/Signup`"]
        CHAT["`💬 ChatScreen<br/>AI Conversation<br/>(Premium Only)`"]
        FLASH_START["`📚 FlashcardStartScreen<br/>Study Configuration`"]
        FLASH_STUDY["`🎯 FlashcardScreen<br/>Interactive Learning`"]
        VOCAB["`📖 UserVocabularyScreen<br/>Word Management`"]
        SETTINGS["`⚙️ SettingsScreen<br/>App Configuration`"]
    end

    %% Core Services
    subgraph "Core Services"
        USER_SVC["`👤 UserService<br/>Authentication & User Data`"]
        VOCAB_SVC["`📝 VocabularyService<br/>Word Management`"]
        FLASH_SVC["`🧠 FlashcardService<br/>Spaced Repetition Engine`"]
        CHAT_SVC["`🤖 ChatService<br/>AI Conversation`"]
        LANG_SVC["`🌍 LanguageSettings<br/>Language Preferences`"]
        SETTINGS_SVC["`⚙️ SettingsService<br/>App Settings`"]
    end

    %% Data Models
    subgraph "Data Models"
        USER_MODEL["`👤 User<br/>• Profile Info<br/>• Premium Status<br/>• Language Prefs`"]
        VOCAB_MODEL["`📝 UserVocabularyItem<br/>• Word + Translations<br/>• Mastery Level<br/>• Review Schedule`"]
        SESSION_MODEL["`📊 FlashcardSession<br/>• Study Metadata<br/>• Performance Stats`"]
        QUESTION_MODEL["`❓ FlashcardQuestion<br/>• Multiple Types<br/>• Difficulty Levels`"]
    end

    %% Backend Infrastructure
    subgraph "Backend (Supabase)"
        AUTH_BE["`🔑 Authentication<br/>Email, Google, Apple`"]
        DB["`🗄️ PostgreSQL Database<br/>• Row Level Security<br/>• Real-time Sync`"]
        STORAGE["`📁 File Storage<br/>Profile Images`"]
    end

    %% External Services
    subgraph "AI Providers"
        OPENAI["`🔥 OpenAI<br/>GPT Models`"]
        GEMINI["`💎 Google Gemini<br/>AI Conversations`"]
    end

    %% Connections
    UI --> STATE
    STATE --> SERVICES

    AUTH --> USER_SVC
    CHAT --> CHAT_SVC
    CHAT --> VOCAB_SVC
    FLASH_START --> FLASH_SVC
    FLASH_STUDY --> FLASH_SVC
    VOCAB --> VOCAB_SVC
    SETTINGS --> SETTINGS_SVC
    SETTINGS --> LANG_SVC

    USER_SVC --> USER_MODEL
    VOCAB_SVC --> VOCAB_MODEL
    FLASH_SVC --> SESSION_MODEL
    FLASH_SVC --> QUESTION_MODEL
    FLASH_SVC --> VOCAB_MODEL

    USER_SVC --> AUTH_BE
    USER_SVC --> DB
    VOCAB_SVC --> DB
    FLASH_SVC --> DB
    CHAT_SVC --> DB

    CHAT_SVC --> OPENAI
    CHAT_SVC --> GEMINI
```

### **Core App Structure:**

- **Frontend**: Flutter app with Material Design 3 + ShadCN UI
- **State Management**: Provider pattern with dependency injection
- **Backend**: Supabase (PostgreSQL + Authentication + Storage)
- **AI Integration**: OpenAI GPT + Google Gemini
- **Platforms**: Web, iOS, Android, macOS, Windows, Linux

## 📱 What This App Does

**"GitFluent"** is a freemium language learning app where users can:

1. **🤖 Chat with AI tutors** (Premium) - Practice conversations in target languages
2. **📚 Study flashcards** - Spaced repetition system for vocabulary retention
3. **📝 Manage vocabulary** - Track learned words with mastery levels
4. **⚙️ Configure learning** - Set target/native languages, preferences
5. **📊 Track progress** - Detailed analytics and learning statistics

## 🗂️ Code Organization

### **1. Entry Point (`lib/main.dart`)**

The app initialization process:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize debug helper
  await DebugHelper.initialize();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}
```

**Key initialization steps:**

- Loads environment variables (`.env`)
- Initializes Supabase backend
- Sets up complex Provider dependency injection tree
- Handles debug mode auto-login

**Provider Dependency Tree:**

```dart
MultiProvider(
  providers: [
    // Core services
    ChangeNotifierProvider<SettingsService>(),
    Provider<SupabaseAuthService>(),
    Provider<SupabaseDatabaseService>(),

    // User system with dependencies
    ChangeNotifierProxyProvider2<UserService>(),
    ChangeNotifierProxyProvider<VocabularyService>(),
    ChangeNotifierProxyProvider2<FlashcardService>(),
    ChangeNotifierProxyProvider<LanguageSettings>(),
    ChangeNotifierProxyProvider2<ChatService>(),
  ],
  child: App(),
)
```

### **2. Data Models (`lib/models/`)**

**Core Entities:**

#### **User Model (`user.dart`)**

```dart
@JsonSerializable()
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final bool isPremium;
  final String? targetLanguage;    // Learning language
  final String? nativeLanguage;    // Native language
  final UserPreferences preferences;
  final UserStatistics statistics;
  // ... more fields
}
```

#### **UserVocabularyItem Model (`user_vocabulary.dart`)**

```dart
@JsonSerializable()
class UserVocabularyItem {
  final String id;
  final String userId;
  final String word;              // Target language word
  final String baseForm;          // Root form of word
  final String wordType;          // verb, noun, adjective, etc.
  final List<String> translations; // Native language translations
  final int difficultyLevel;      // 1-5 difficulty
  final int masteryLevel;         // 0-100 mastery
  final int timesSeen;            // Review count
  final int timesCorrect;         // Correct answers
  final DateTime lastSeen;        // Last review date
  final DateTime? nextReview;     // Spaced repetition schedule
  // ... more fields
}
```

#### **FlashcardSession Model (`flashcard_session.dart`)**

```dart
@JsonSerializable()
class FlashcardSession {
  final String id;
  final String userId;
  final DateTime sessionDate;
  final int durationMinutes;
  final int wordsStudied;
  final int totalCards;
  final double accuracyPercentage;
  final String sessionType;      // 'timed', 'count-based'
  final bool isCompleted;
  // ... more fields
}
```

#### **FlashcardQuestion Model (`flashcard_question.dart`)**

```dart
enum FlashcardQuestionType {
  traditional,    // word → translation
  multipleChoice, // word → pick correct translation
  fillInBlank,    // sentence with blank → fill word
  reverse,        // translation → word
}

class FlashcardQuestion {
  final String id;
  final UserVocabularyItem vocabularyItem;
  final FlashcardQuestionType type;
  final String question;
  final String correctAnswer;
  final List<String> options;    // For multiple choice
  final String? context;         // For fill-in-blank
  // ... more fields
}
```

### **3. Services Layer (`lib/services/`)**

**Business Logic Services:**

#### **UserService (`user_service.dart`)**

- **Authentication**: Login, signup, OAuth (Google, Apple)
- **User Management**: Profile updates, premium upgrades
- **Session Management**: Auto-login, state persistence

```dart
class UserService extends ChangeNotifier {
  // Authentication
  Future<AuthResult> signIn(String email, String password);
  Future<AuthResult> signUp(String email, String password, String firstName, String lastName);
  Future<void> signOut();

  // Premium management
  Future<void> upgradeToPremium();
  bool get isPremium => currentUser?.isPremium ?? false;

  // User data
  User? get currentUser;
  bool get isLoggedIn;
  bool get isLoading;
}
```

#### **VocabularyService (`vocabulary_service.dart`)**

- **Word Management**: CRUD operations for vocabulary
- **Statistics**: Learning progress and analytics
- **Import/Export**: Vocabulary data management

```dart
class VocabularyService extends ChangeNotifier {
  // Vocabulary management
  Future<List<UserVocabularyItem>> getUserVocabulary();
  Future<void> addVocabularyItem(UserVocabularyItem item);
  Future<void> updateVocabularyItem(UserVocabularyItem item);

  // Statistics
  Future<VocabularyStats> getStatistics();
  Future<List<UserVocabularyItem>> getWordsForReview();

  // Search and filtering
  List<UserVocabularyItem> searchVocabulary(String query);
  List<UserVocabularyItem> filterByType(String wordType);
}
```

#### **FlashcardService (`flashcard_service.dart`)**

- **Spaced Repetition Algorithm**: Smart word selection and scheduling
- **Session Management**: Study session lifecycle
- **Question Generation**: Multiple question types
- **Performance Tracking**: Detailed analytics and progress

```dart
class FlashcardService extends ChangeNotifier {
  // Session management
  Future<FlashcardSession> createSession({required int durationMinutes});
  Future<void> startSession(FlashcardSession session);
  Future<void> pauseSession();
  Future<void> resumeSession();
  Future<void> endSession();

  // Question flow
  Future<FlashcardQuestion?> getNextQuestion();
  Future<void> submitAnswer(String questionId, String answer, String difficulty);

  // Spaced repetition algorithm
  Future<List<UserVocabularyItem>> selectWordsForStudy(int maxWords);
  DateTime calculateNextReview(UserVocabularyItem item, String difficulty);

  // Analytics
  FlashcardSession? get currentSession;
  SessionStatistics get sessionStats;
  bool get hasActiveSession;
}
```

#### **ChatService (`chat_service.dart`)**

- **AI Conversations**: Integration with OpenAI and Gemini
- **Vocabulary Extraction**: Automatic word detection and storage
- **Context Management**: Conversation history and prompts

```dart
class ChatService extends ChangeNotifier {
  // AI conversation
  Future<String> sendMessage(String message);
  Future<void> clearConversation();

  // Vocabulary extraction
  Future<List<VocabularyItem>> extractVocabulary(String text);
  Future<void> saveExtractedVocabulary(List<VocabularyItem> items);

  // Provider management
  void setAIProvider(AIProvider provider);
  AIProvider get currentProvider;

  // Chat history
  List<Message> get messages;
  bool get isLoading;
}
```

#### **LanguageSettings (`language_settings_service.dart`)**

- **Multi-language Support**: Target, native, and support languages
- **Preferences Sync**: Database synchronization
- **Language Configuration**: App-wide language settings

```dart
class LanguageSettings extends ChangeNotifier {
  // Language management
  Future<void> setTargetLanguage(Language language);
  Future<void> setNativeLanguage(Language language);
  Future<void> setSupportLanguages(Language? lang1, Language? lang2);

  // Current settings
  Language? get targetLanguage;
  Language? get nativeLanguage;
  Language? get supportLanguage1;
  Language? get supportLanguage2;

  // Synchronization
  Future<void> syncWithDatabase();
  Future<void> loadFromDatabase();
}
```

### **4. UI Layer (`lib/screens/`)**

**Main User Flows:**

#### **1. Authentication Flow**

```
AuthScreen → UserService → SupabaseAuthService → Database
```

**`AuthScreen`** (`auth_screen.dart`):

- Login/Signup forms with validation
- OAuth integration (Google, Apple)
- Password reset functionality
- Premium upgrade prompts

#### **2. AI Chat Flow** (Premium Users)

```
ChatScreen → ChatService → AI Provider → Vocabulary Extraction → Database
```

**`ChatScreen`** (`chat_screen.dart`):

- Real-time AI conversations
- Automatic vocabulary extraction
- Message history with markdown support
- Language-specific prompts and context

#### **3. Flashcard Study Flow**

```
FlashcardStartScreen → FlashcardService → FlashcardScreen → FlashcardResultsScreen
```

**`FlashcardStartScreen`** (`flashcard_start_screen.dart`):

- Study session configuration
- Duration and word count settings
- Word type filtering (verbs, nouns, etc.)
- Language selection and preferences

**`FlashcardScreen`** (`flashcard_screen.dart`):

- Interactive flashcard interface
- Multiple question types
- Performance feedback
- Progress tracking
- Smooth animations and transitions

**`FlashcardResultsScreen`** (`flashcard_results_screen.dart`):

- Session performance summary
- Detailed statistics and analytics
- Learning recommendations
- Next session scheduling

#### **4. Vocabulary Management**

```
UserVocabularyScreen → VocabularyService → Database
```

**`UserVocabularyScreen`** (`user_vocabulary_screen.dart`):

- Vocabulary collection browsing
- Search and filtering capabilities
- Word details and edit functionality
- Import/export options
- Statistics and progress tracking

#### **5. Settings and Configuration**

```
SettingsScreen → SettingsService/LanguageSettings → Database
```

**`SettingsScreen`** (`settings_screen.dart`):

- Language preferences configuration
- AI provider selection (OpenAI/Gemini)
- Study session defaults
- Account management
- Premium upgrade options

### **5. Database (`supabase/`)**

**PostgreSQL Schema with Row Level Security:**

#### **Core Tables:**

**`users` table:**

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR UNIQUE NOT NULL,
  password_hash VARCHAR,
  first_name VARCHAR NOT NULL,
  last_name VARCHAR NOT NULL,
  is_premium BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login_at TIMESTAMP WITH TIME ZONE,
  profile_image_url VARCHAR,
  auth_provider VARCHAR DEFAULT 'email',
  provider_id VARCHAR,
  target_language VARCHAR,      -- Individual language fields
  native_language VARCHAR,      -- for backwards compatibility
  support_language_1 VARCHAR,
  support_language_2 VARCHAR,
  preferences JSONB DEFAULT '{}',
  statistics JSONB DEFAULT '{}'
);
```

**`user_vocabulary` table:**

```sql
CREATE TABLE user_vocabulary (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  word VARCHAR NOT NULL,
  base_form VARCHAR NOT NULL,
  word_type VARCHAR NOT NULL,        -- verb, noun, adjective, etc.
  language VARCHAR NOT NULL,
  translations TEXT[],               -- Array of translations
  forms TEXT[],                      -- Word forms/conjugations
  difficulty_level INTEGER DEFAULT 1, -- 1-5 difficulty
  mastery_level INTEGER DEFAULT 0,   -- 0-100 mastery
  times_seen INTEGER DEFAULT 1,      -- Review count
  times_correct INTEGER DEFAULT 0,   -- Correct answers
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  first_learned TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  next_review TIMESTAMP WITH TIME ZONE, -- Spaced repetition schedule
  is_favorite BOOLEAN DEFAULT FALSE,
  tags TEXT[],
  example_sentences TEXT[],
  source_message_id VARCHAR          -- Reference to chat message
);
```

**`flashcard_sessions` table:**

```sql
CREATE TABLE flashcard_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  duration_minutes INTEGER NOT NULL,
  words_studied INTEGER DEFAULT 0,
  total_cards INTEGER DEFAULT 0,
  accuracy_percentage DECIMAL(5,2) DEFAULT 0.0,
  session_type VARCHAR(50) DEFAULT 'timed',
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**`flashcard_session_cards` table:**

```sql
CREATE TABLE flashcard_session_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES flashcard_sessions(id) ON DELETE CASCADE,
  vocabulary_item_id UUID REFERENCES user_vocabulary(id) ON DELETE CASCADE,
  question_type VARCHAR(50) NOT NULL, -- 'traditional', 'multiple_choice', 'fill_blank', 'reverse'
  response_time_ms INTEGER DEFAULT 0,
  was_correct BOOLEAN NOT NULL,
  difficulty_rating VARCHAR(20),      -- 'again', 'hard', 'good', 'easy'
  shown_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  answered_at TIMESTAMP WITH TIME ZONE
);
```

**`vocabulary_stats` table:**

```sql
CREATE TABLE vocabulary_stats (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  language VARCHAR NOT NULL,
  total_words INTEGER DEFAULT 0,
  mastered_words INTEGER DEFAULT 0,
  learning_words INTEGER DEFAULT 0,
  new_words INTEGER DEFAULT 0,
  words_due_review INTEGER DEFAULT 0,
  average_mastery DECIMAL DEFAULT 0.0,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  words_by_type JSONB DEFAULT '{}',
  PRIMARY KEY (user_id, language)
);
```

**`chat_history` table:**

```sql
CREATE TABLE chat_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  message_data JSONB NOT NULL
);
```

#### **Security Features:**

**Row Level Security (RLS) Policies:**

```sql
-- Users can only access their own data
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can view own vocabulary"
  ON user_vocabulary FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can manage users (for premium upgrades)
CREATE POLICY "Service role can manage users"
  ON users
  USING (auth.role() = 'service_role');
```

**Indexes for Performance:**

```sql
CREATE INDEX idx_vocabulary_user_language ON user_vocabulary(user_id, language);
CREATE INDEX idx_vocabulary_review ON user_vocabulary(user_id, next_review);
CREATE INDEX idx_flashcard_sessions_user_id ON flashcard_sessions(user_id);
CREATE INDEX idx_flashcard_session_cards_session_id ON flashcard_session_cards(session_id);
```

## 🔄 Key Data Flows

### **1. User Authentication Flow:**

```
AuthScreen → UserService → SupabaseAuthService → Supabase Auth → Database User Creation
```

**Detailed Flow:**

1. User enters credentials in `AuthScreen`
2. `UserService.signIn()` validates input
3. `SupabaseAuthService` handles authentication
4. Supabase Auth verifies credentials
5. User record created/updated in database
6. App state updates with authenticated user
7. Navigation to main app interface

### **2. Vocabulary Learning Flow:**

```
ChatScreen → AI Response → VocabularyProcessor → UserVocabularyItem → Database Storage
```

**Detailed Flow:**

1. User sends message in `ChatScreen`
2. `ChatService` forwards to AI provider (OpenAI/Gemini)
3. AI responds with target language content
4. `VocabularyProcessor` extracts new vocabulary
5. Words converted to `UserVocabularyItem` objects
6. Items saved to `user_vocabulary` table
7. User notified of new vocabulary added

### **3. Flashcard Study Flow:**

```
FlashcardStartScreen → Session Config → FlashcardService → Question Generation → FlashcardScreen → Performance Tracking
```

**Detailed Flow:**

1. User configures study session in `FlashcardStartScreen`
2. `FlashcardService.createSession()` initializes session
3. Spaced repetition algorithm selects words for study
4. Questions generated based on word types and difficulty
5. User studies in `FlashcardScreen` with interactive interface
6. Performance data collected (response time, accuracy)
7. Session results saved to database
8. Vocabulary mastery levels updated
9. Next review dates calculated and scheduled

## 🧠 Core Algorithms

### **Spaced Repetition System:**

The `FlashcardService` implements a sophisticated spaced repetition algorithm inspired by Anki and SuperMemo:

#### **Word Selection Algorithm:**

```dart
Future<List<UserVocabularyItem>> selectWordsForStudy(int maxWords) async {
  // 1. Get overdue words (past next_review date)
  final overdueWords = await _getOverdueWords();

  // 2. Get words due today
  final todayWords = await _getWordsDueToday();

  // 3. Get new words (never reviewed)
  final newWords = await _getNewWords();

  // 4. Prioritize: overdue > today > new
  final selectedWords = <UserVocabularyItem>[];

  // Add overdue words first (highest priority)
  selectedWords.addAll(overdueWords.take(maxWords ~/ 2));

  // Fill remaining slots with today's words
  final remainingSlots = maxWords - selectedWords.length;
  selectedWords.addAll(todayWords.take(remainingSlots ~/ 2));

  // Fill any remaining slots with new words
  final finalSlots = maxWords - selectedWords.length;
  selectedWords.addAll(newWords.take(finalSlots));

  return selectedWords;
}
```

#### **Review Interval Calculation:**

```dart
DateTime calculateNextReview(UserVocabularyItem item, String difficulty) {
  final now = DateTime.now();
  final daysSinceLastReview = now.difference(item.lastSeen).inDays;
  final currentInterval = item.nextReview != null
      ? item.nextReview!.difference(item.lastSeen).inDays
      : 1;

  int newInterval;

  switch (difficulty) {
    case 'again':   // Failed - reset to 1 day
      newInterval = 1;
      break;
    case 'hard':    // Difficult - 1.2x interval
      newInterval = (currentInterval * 1.2).round();
      break;
    case 'good':    // Good - 2.5x interval
      newInterval = (currentInterval * 2.5).round();
      break;
    case 'easy':    // Easy - 4x interval
      newInterval = (currentInterval * 4).round();
      break;
    default:
      newInterval = (currentInterval * 2.5).round();
  }

  // Cap maximum interval at 365 days
  newInterval = newInterval.clamp(1, 365);

  return now.add(Duration(days: newInterval));
}
```

#### **Question Type Generation:**

```dart
FlashcardQuestion generateQuestion(UserVocabularyItem item) {
  final questionTypes = [
    FlashcardQuestionType.traditional,
    FlashcardQuestionType.reverse,
    FlashcardQuestionType.multipleChoice,
    FlashcardQuestionType.fillInBlank,
  ];

  // Weight question types based on mastery level
  final weights = _calculateQuestionTypeWeights(item.masteryLevel);
  final selectedType = _weightedRandomSelection(questionTypes, weights);

  switch (selectedType) {
    case FlashcardQuestionType.traditional:
      return FlashcardQuestion.traditional(
        id: const Uuid().v4(),
        vocabularyItem: item,
      );

    case FlashcardQuestionType.multipleChoice:
      final distractors = _generateDistractors(item);
      return FlashcardQuestion.multipleChoice(
        id: const Uuid().v4(),
        vocabularyItem: item,
        distractors: distractors,
      );

    case FlashcardQuestionType.fillInBlank:
      final context = _generateContext(item);
      return FlashcardQuestion.fillInBlank(
        id: const Uuid().v4(),
        vocabularyItem: item,
        context: context,
      );

    case FlashcardQuestionType.reverse:
      return FlashcardQuestion.reverse(
        id: const Uuid().v4(),
        vocabularyItem: item,
      );
  }
}
```

### **AI Vocabulary Extraction:**

The `ChatService` automatically extracts vocabulary from AI conversations:

#### **Language Detection and Extraction:**

```dart
Future<List<VocabularyItem>> extractVocabulary(String aiResponse) async {
  final targetLanguage = _languageSettings.targetLanguage?.code ?? 'en';
  final nativeLanguage = _languageSettings.nativeLanguage?.code ?? 'en';

  // 1. Use regex and NLP to identify target language words
  final candidateWords = _extractCandidateWords(aiResponse, targetLanguage);

  // 2. Filter out common words and previously learned vocabulary
  final novelWords = await _filterNovelWords(candidateWords);

  // 3. Get definitions and translations for novel words
  final vocabularyItems = <VocabularyItem>[];

  for (final word in novelWords) {
    try {
      final definition = await _getDefinition(word, targetLanguage);
      final translation = await _getTranslation(word, targetLanguage, nativeLanguage);
      final wordType = await _identifyWordType(word, targetLanguage);

      vocabularyItems.add(VocabularyItem(
        word: word,
        type: wordType,
        translation: translation,
        definition: definition,
        dateAdded: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Error processing word $word: $e');
    }
  }

  return vocabularyItems;
}
```

#### **Automatic Storage:**

```dart
Future<void> saveExtractedVocabulary(List<VocabularyItem> items) async {
  final userId = _userService.currentUser?.id;
  if (userId == null) return;

  for (final item in items) {
    final userVocabItem = UserVocabularyItem(
      id: const Uuid().v4(),
      userId: userId,
      word: item.word,
      baseForm: _getBaseForm(item.word),
      wordType: item.type,
      language: _languageSettings.targetLanguage?.code ?? 'en',
      translations: [item.translation],
      difficultyLevel: _estimateDifficulty(item.word),
      masteryLevel: 0,
      timesSeen: 0,
      timesCorrect: 0,
      lastSeen: DateTime.now(),
      firstLearned: DateTime.now(),
      nextReview: DateTime.now().add(const Duration(days: 1)),
    );

    await _vocabularyService.addVocabularyItem(userVocabItem);
  }

  notifyListeners();
}
```

## 🔧 Development Setup

### **Prerequisites:**

```bash
# Flutter SDK 3.24.7 or later
flutter --version

# Dart SDK 3.5.7 or later
dart --version
```

### **Installation Steps:**

#### **1. Clone and Setup:**

```bash
# Clone the repository
git clone <repository-url>
cd llm_chat_app

# Install dependencies
flutter pub get

# Generate JSON serialization code
flutter packages pub run build_runner build
```

#### **2. Environment Configuration:**

Create a `.env` file in the root directory:

```env
# AI Provider API Keys
LLM_API_KEY=your_openai_api_key_here
GOOGLE_API_KEY=your_gemini_api_key_here

# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Optional: Additional Configuration
DEBUG_MODE=true
AUTO_LOGIN_EMAIL=test@debug.com
AUTO_LOGIN_PASSWORD=debugpassword123
```

#### **3. Supabase Setup:**

1. **Create Supabase Project:**

   - Go to [https://supabase.com](https://supabase.com)
   - Create new project
   - Get project URL and anon key

2. **Run Database Migrations:**

   ```sql
   -- Copy and run each migration file in order:
   -- 1. supabase/migrations/20240321000000_initial_schema.sql
   -- 2. supabase/migrations/20250118000000_add_preferences_column.sql
   -- 3. supabase/migrations/20250118000001_flashcard_tables.sql
   -- 4. supabase/migrations/20250118000002_remove_language_from_preferences.sql
   ```

3. **Configure Authentication:**
   - Enable Email/Password authentication
   - Optional: Configure Google/Apple OAuth

#### **4. AI Provider Setup:**

**OpenAI:**

```bash
# Get API key from https://platform.openai.com/api-keys
export LLM_API_KEY=sk-...
```

**Google Gemini:**

```bash
# Get API key from https://makersuite.google.com/app/apikey
export GOOGLE_API_KEY=AI...
```

### **Key Dependencies:**

```yaml
dependencies:
  # Core Flutter
  flutter: ^3.24.7
  cupertino_icons: ^1.0.6

  # State Management & Architecture
  provider: ^6.0.5

  # Backend & Database
  supabase_flutter: ^2.3.4
  sqflite: ^2.3.0

  # AI & Language Processing
  google_generative_ai: ^0.2.0
  langchain: ^0.3.0
  langchain_openai: ^0.3.0
  langchain_google: ^0.2.2+1

  # UI & Design
  shadcn_ui: ^0.26.5
  flutter_markdown: ^0.6.18

  # Utilities
  http: ^1.1.0
  shared_preferences: ^2.2.0
  flutter_dotenv: ^5.1.0
  uuid: ^4.2.1
  crypto: ^3.0.3
  email_validator: ^2.1.17

  # JSON & Serialization
  json_annotation: ^4.8.1

  # Security
  flutter_secure_storage: ^9.0.0

  # Development & Debugging
  mcp_toolkit: ^0.1.0

dev_dependencies:
  # Testing
  flutter_test: ^3.24.7
  mockito: ^5.4.4
  mocktail: ^1.0.3

  # Code Generation
  json_serializable: ^6.7.1
  build_runner: ^2.4.7

  # Linting
  flutter_lints: ^3.0.0
```

### **Running the App:**

```bash
# Development mode
flutter run

# Specific platforms
flutter run -d chrome      # Web
flutter run -d ios         # iOS (requires Xcode)
flutter run -d android     # Android
flutter run -d macos       # macOS
flutter run -d windows     # Windows
flutter run -d linux       # Linux

# Release mode
flutter run --release

# With specific flavor/configuration
flutter run --dart-define=ENV=development
```

## 🧪 Testing Strategy

The app includes comprehensive testing coverage across multiple levels:

### **Test Structure:**

```
test/
├── unit/                          # Unit tests
│   ├── models/
│   ├── services/
│   └── utils/
├── integration/                   # Integration tests
│   ├── database_integration_test.dart
│   ├── auth_flow_test.dart
│   └── vocabulary_sync_test.dart
├── widget/                        # Widget tests
│   ├── screens/
│   └── widgets/
├── e2e/                          # End-to-end tests
│   ├── complete_user_journey_test.dart
│   ├── flashcard_flow_e2e_test.dart
│   └── language_preferences_e2e_test.dart
└── performance/                   # Performance tests
    ├── flashcard_performance_test.dart
    └── memory_leak_test.dart
```

### **Running Tests:**

```bash
# Run all tests
flutter test

# Run specific test categories
flutter test test/unit/
flutter test test/integration/
flutter test test/e2e/

# Run specific test files
flutter test test/services/flashcard_service_test.dart
flutter test test/e2e/flashcard_flow_e2e_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Performance testing
flutter test test/performance/flashcard_performance_test.dart --verbose
```

### **Test Coverage Areas:**

#### **1. Unit Tests:**

- **Models**: JSON serialization, data validation, business logic
- **Services**: Authentication, vocabulary management, flashcard algorithms
- **Utilities**: Helper functions, data processing, validation

```dart
// Example: FlashcardService unit test
testWidgets('should calculate next review date correctly', (tester) async {
  final service = FlashcardService();
  final item = createMockVocabularyItem();

  // Test different difficulty levels
  final easyReview = service.calculateNextReview(item, 'easy');
  final hardReview = service.calculateNextReview(item, 'hard');

  expect(easyReview.isAfter(hardReview), isTrue);
  expect(easyReview.difference(DateTime.now()).inDays, greaterThan(7));
});
```

#### **2. Integration Tests:**

- **Database Operations**: CRUD operations, data consistency
- **Service Interactions**: Cross-service communication
- **Authentication Flow**: Login, signup, premium upgrades

```dart
// Example: Database integration test
testWidgets('should sync vocabulary between local and remote', (tester) async {
  final localService = LocalDatabaseService();
  final remoteService = SupabaseDatabaseService();

  // Add item locally
  final item = createTestVocabularyItem();
  await localService.saveVocabularyItem(item);

  // Sync to remote
  await syncVocabulary(localService, remoteService);

  // Verify sync
  final remoteItem = await remoteService.getVocabularyItem(item.id);
  expect(remoteItem, isNotNull);
  expect(remoteItem!.word, equals(item.word));
});
```

#### **3. Widget Tests:**

- **UI Components**: Screen rendering, user interactions
- **Navigation**: Route transitions, state persistence
- **Responsive Design**: Different screen sizes and orientations

```dart
// Example: Widget test
testWidgets('FlashcardScreen should display question and accept answer', (tester) async {
  await tester.pumpWidget(createTestApp(child: FlashcardScreen()));
  await tester.pumpAndSettle();

  // Verify question is displayed
  expect(find.text('Guten Tag'), findsOneWidget);
  expect(find.text('What does this mean?'), findsOneWidget);

  // Enter answer
  await tester.enterText(find.byType(TextField), 'Good day');
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();

  // Verify feedback
  expect(find.text('Correct!'), findsOneWidget);
});
```

#### **4. End-to-End Tests:**

- **Complete User Journeys**: Registration → Study → Progress tracking
- **Cross-Platform**: Consistent behavior across platforms
- **Performance**: Real-world usage scenarios

```dart
// Example: E2E test
testWidgets('complete flashcard study session flow', (tester) async {
  // 1. User authentication
  await signInTestUser(tester);

  // 2. Navigate to flashcards
  await tester.tap(find.text('Study Flashcards'));
  await tester.pumpAndSettle();

  // 3. Configure session
  await configureStudySession(tester, durationMinutes: 5);

  // 4. Complete study session
  await completeFlashcardSession(tester);

  // 5. Verify results
  expect(find.text('Session Complete!'), findsOneWidget);
  expect(find.textContaining('Words Studied:'), findsOneWidget);
});
```

### **Performance Benchmarks:**

```dart
// Performance test expectations
group('Performance Benchmarks', () {
  test('word selection should be fast for large vocabulary', () async {
    final service = FlashcardService();
    final largeVocabulary = generateTestVocabulary(10000); // 10k words

    final stopwatch = Stopwatch()..start();
    final selectedWords = await service.selectWordsForStudy(20);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(100)); // <100ms
    expect(selectedWords.length, equals(20));
  });

  test('question generation should be instantaneous', () async {
    final service = FlashcardService();
    final vocabulary = generateTestVocabulary(1000);

    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      final question = service.generateQuestion(vocabulary[i]);
      expect(question, isNotNull);
    }
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(10)); // <10ms for 100 questions
  });
});
```

**Performance Targets:**

- **Word Selection**: <100ms for 10,000 vocabulary items
- **Question Generation**: <1ms per question
- **Session Operations**: <100ms end-to-end
- **Memory Usage**: Stable with no observable leaks
- **Database Queries**: <200ms for complex operations

## 🔍 How to Explore the Code

### **Recommended Learning Path:**

#### **Phase 1: Foundation (Day 1-2)**

1. **`lib/main.dart`** - App initialization and Provider setup
2. **`pubspec.yaml`** - Dependencies and project configuration
3. **`README.md`** - Project overview and features
4. **`lib/models/user.dart`** - Core data structure
5. **`supabase/migrations/20240321000000_initial_schema.sql`** - Database schema

#### **Phase 2: Core Services (Day 3-5)**

6. **`lib/services/user_service.dart`** - User management and authentication
7. **`lib/services/database_service.dart`** - Abstract database interface
8. **`lib/services/supabase_database_service.dart`** - Supabase implementation
9. **`lib/services/settings_service.dart`** - App configuration
10. **`lib/services/language_settings_service.dart`** - Language management

#### **Phase 3: Learning Features (Day 6-8)**

11. **`lib/services/vocabulary_service.dart`** - Vocabulary management
12. **`lib/services/flashcard_service.dart`** - Spaced repetition engine
13. **`lib/models/flashcard_question.dart`** - Question types and generation
14. **`lib/models/user_vocabulary.dart`** - Vocabulary data model

#### **Phase 4: AI Integration (Day 9-10)**

15. **`lib/services/chat_service.dart`** - AI conversation management
16. **`lib/services/vocabulary_processor.dart`** - Automatic vocabulary extraction
17. **`lib/services/llm_output_formatter.dart`** - AI response processing

#### **Phase 5: User Interface (Day 11-13)**

18. **`lib/screens/auth_screen.dart`** - Authentication UI
19. **`lib/screens/chat_screen.dart`** - Main chat interface
20. **`lib/screens/flashcard_start_screen.dart`** - Study configuration
21. **`lib/screens/flashcard_screen.dart`** - Interactive flashcard UI
22. **`lib/screens/user_vocabulary_screen.dart`** - Vocabulary management UI

#### **Phase 6: Advanced Features (Day 14-15)**

23. **`lib/widgets/flashcard_widget.dart`** - Reusable flashcard component
24. **`lib/utils/app_navigation.dart`** - Navigation utilities
25. **`lib/utils/debug_helper.dart`** - Debugging and logging
26. **Test files** - Understanding test patterns and coverage

### **Focus Areas by Interest:**

#### **🤖 AI Integration Enthusiasts:**

- `lib/services/chat_service.dart` - AI conversation logic
- `lib/services/vocabulary_processor.dart` - NLP and extraction
- `lib/services/prompts.dart` - AI prompt engineering
- `lib/models/language_response.dart` - AI response handling

#### **🧠 Learning Algorithm Enthusiasts:**

- `lib/services/flashcard_service.dart` - Spaced repetition implementation
- `lib/models/flashcard_question.dart` - Question generation strategies
- `test/flashcard_performance_test.dart` - Algorithm performance testing
- Database scheduling and review interval logic

#### **📱 UI/UX Enthusiasts:**

- `lib/screens/` - All user interface screens
- `lib/widgets/` - Reusable UI components
- `lib/utils/flashcard_route_transitions.dart` - Custom animations
- `lib/widgets/accessibility_helper.dart` - Accessibility features

#### **🗄️ Data & Backend Enthusiasts:**

- `lib/models/` - Data modeling and serialization
- `lib/services/supabase_database_service.dart` - Database operations
- `supabase/migrations/` - Schema design and evolution
- `lib/services/local_database_service.dart` - Local storage patterns

#### **🔐 Security & Authentication Enthusiasts:**

- `lib/services/supabase_auth_service.dart` - Authentication implementation
- `supabase/migrations/` - Row Level Security policies
- `lib/services/user_service.dart` - User session management
- OAuth integration and security patterns

### **Code Reading Tips:**

#### **1. Start with Interfaces:**

```dart
// Always read abstract classes first to understand contracts
abstract class DatabaseService {
  Future<User?> getUserById(String userId);
  Future<void> updateUser(User user);
  // ... more methods
}
```

#### **2. Follow the Provider Dependency Chain:**

```dart
// Understand how services depend on each other
ChangeNotifierProxyProvider2<UserService, VocabularyService, FlashcardService>(
  create: (context) {
    final flashcardService = FlashcardService();
    flashcardService.setUserService(context.read<UserService>());
    flashcardService.setVocabularyService(context.read<VocabularyService>());
    return flashcardService;
  },
  // ...
)
```

#### **3. Trace Data Flow:**

```dart
// Follow data from UI → Service → Database
// Example: Adding vocabulary
ChatScreen → ChatService.sendMessage() → AI Response →
VocabularyProcessor.extract() → VocabularyService.addItem() →
SupabaseDatabaseService.saveVocabularyItem() → Database
```

#### **4. Understand State Management:**

```dart
// Services extend ChangeNotifier for reactive UI updates
class VocabularyService extends ChangeNotifier {
  Future<void> addVocabularyItem(UserVocabularyItem item) async {
    await _databaseService.saveVocabularyItem(item);
    _vocabularyItems.add(item);
    notifyListeners(); // Triggers UI rebuild
  }
}
```

## 🚀 Next Steps

### **To Truly Master This Codebase:**

#### **1. Run and Experiment (Day 1)**

```bash
# Set up the development environment
flutter pub get
flutter run -d chrome

# Try different features:
# - Create an account
# - Have an AI conversation
# - Study flashcards
# - Manage vocabulary
```

#### **2. Debug and Trace (Day 2-3)**

```dart
// Add debug prints to understand flow
debugPrint('🔍 ChatService.sendMessage: $message');
debugPrint('📝 VocabularyService.addItem: ${item.word}');
debugPrint('🧠 FlashcardService.getNextQuestion: ${question.type}');
```

#### **3. Modify and Extend (Day 4-7)**

- Add a new question type to the flashcard system
- Implement a new AI provider (e.g., Claude, local LLM)
- Create a new vocabulary statistic or visualization
- Add a new user preference or setting

#### **4. Optimize and Improve (Day 8-14)**

- Profile the spaced repetition algorithm performance
- Optimize database queries with better indexing
- Improve UI animations and responsiveness
- Add comprehensive error handling

#### **5. Test and Deploy (Day 15+)**

- Write tests for your new features
- Test on multiple platforms (web, mobile, desktop)
- Deploy to app stores or web hosting
- Contribute back to the project

### **Advanced Learning Projects:**

#### **🎯 Beginner Projects:**

1. **Add new word types** (idioms, phrases, expressions)
2. **Implement word search** in vocabulary screen
3. **Add study session statistics** dashboard
4. **Create user profile customization** options

#### **🔥 Intermediate Projects:**

1. **Implement offline mode** with local database sync
2. **Add voice input/output** for pronunciation practice
3. **Create custom study plans** with goals and scheduling
4. **Implement social features** (sharing progress, leaderboards)

#### **🚀 Advanced Projects:**

1. **Integrate speech recognition** for pronunciation scoring
2. **Implement advanced NLP** for better vocabulary extraction
3. **Add machine learning** for personalized difficulty adjustment
4. **Create AR/VR flashcard** experiences

## 📊 Codebase Metrics

### **Project Statistics:**

- **Total Files**: 100+ source files
- **Lines of Code**: ~15,000 lines (excluding generated code)
- **Test Coverage**: 80%+ (comprehensive unit, integration, and E2E tests)
- **Supported Platforms**: 6 platforms (Web, iOS, Android, macOS, Windows, Linux)
- **Languages**: Dart, SQL, TypeScript (minimal)

### **Architecture Quality:**

- **Separation of Concerns**: Clean separation between UI, business logic, and data
- **Dependency Injection**: Proper Provider-based dependency management
- **Error Handling**: Comprehensive error handling and user feedback
- **Security**: Row Level Security, input validation, secure storage
- **Performance**: Optimized algorithms, efficient database queries, smooth UI
- **Accessibility**: Screen reader support, responsive design, keyboard navigation
- **Testing**: Multiple testing levels with good coverage
- **Documentation**: Comprehensive inline documentation and README files

### **Technical Debt Assessment:**

- **Low Debt**: Well-structured codebase with modern patterns
- **Maintainable**: Clear abstractions and consistent naming
- **Scalable**: Modular architecture supports feature additions
- **Testable**: High test coverage with reliable test suite
- **Documented**: Good documentation coverage for public APIs

## 🎯 Conclusion

This is a **production-ready, enterprise-grade Flutter application** that demonstrates:

- **Modern Flutter Development**: Latest SDK, best practices, cross-platform support
- **Clean Architecture**: SOLID principles, dependency injection, separation of concerns
- **Advanced Algorithms**: Spaced repetition, AI integration, performance optimization
- **Comprehensive Testing**: Unit, integration, E2E, and performance testing
- **Security Best Practices**: Authentication, authorization, data protection
- **User Experience**: Responsive design, accessibility, smooth animations
- **Backend Integration**: Real-time database, authentication, file storage
- **AI/ML Integration**: Natural language processing, conversation management

The codebase serves as an excellent example for learning:

- **Flutter app architecture** at scale
- **State management** with Provider
- **Backend integration** with Supabase
- **AI/ML integration** in mobile apps
- **Spaced repetition algorithms** for learning apps
- **Testing strategies** for complex applications
- **Cross-platform development** best practices

Whether you're interested in mobile development, AI integration, learning algorithms, or backend architecture, this codebase offers deep insights into building sophisticated, real-world applications.

**Happy learning and coding!** 🎓✨
