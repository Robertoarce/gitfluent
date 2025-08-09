# Language Learning Chat App

A comprehensive Flutter application for language learning that combines AI-powered conversations with intelligent vocabulary management and spaced repetition flashcards. The app works across web, iOS, Android, and desktop platforms with a modern Material Design 3 interface.

## 🌟 Features

### Core Learning Features

- **AI-Powered Conversations**: Chat with an intelligent language tutor
- **Vocabulary Management**: Automatic vocabulary extraction and tracking
- **Flashcard Learning System**: Spaced repetition for long-term retention
- **Progress Tracking**: Detailed analytics and learning statistics
- **Multi-Language Support**: Learn Italian, Spanish, French, German, and more

### Flashcard Learning System ⭐ **NEW**

- **Smart Word Selection**: AI prioritizes words based on difficulty and review schedule
- **Multiple Question Types**: Traditional, multiple choice, fill-in-blank, and reverse flashcards
- **Adaptive Spaced Repetition**: Optimizes review timing based on your performance
- **Session Management**: Configurable study sessions with pause/resume support
- **Performance Analytics**: Detailed statistics and learning recommendations
- **Accessibility Features**: Screen reader support and responsive design

### Technical Features

- **Cross-Platform**: Web, iOS, Android, macOS, Windows, Linux
- **Real-time Sync**: Supabase backend with offline support
- **User Authentication**: Secure login with Google and Apple Sign-In
- **Modern UI**: Material Design 3 with dark/light theme support
- **Accessibility**: Full screen reader support and responsive layouts

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.24.7 or later
- Dart SDK 3.5.7 or later
- Supabase account for backend services
- OpenAI API key (or compatible LLM service)

### Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd llm_chat_app
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Configure environment variables**
   Create a `.env` file in the root directory:

```env
LLM_API_KEY=your_openai_api_key_here
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. **Run the app**

```bash
# For development
flutter run

# For specific platforms
flutter run -d chrome      # Web
flutter run -d ios         # iOS
flutter run -d android     # Android
```

## 📚 Documentation

### User Guides

- **[Flashcard User Guide](docs/flashcard_user_guide.md)**: Complete guide to using the flashcard learning system
- **[Vocabulary Management](docs/vocabulary_management.md)**: How to manage your vocabulary collection
- **[Language Settings](docs/language_settings.md)**: Configuring your learning preferences

### Technical Documentation

- **[Flashcard System Architecture](docs/flashcard_system.md)**: Comprehensive technical documentation
- **[Database Schema](supabase/README.md)**: Database structure and migrations
- **[API Reference](docs/api_reference.md)**: Service interfaces and methods

## 🏗️ Architecture

### Core Services

```
UserService ──────┐
                  ├── FlashcardService (Spaced Repetition Engine)
VocabularyService ┘         │
                           ├── Word Selection Algorithm
                           ├── Question Generation
                           ├── Performance Tracking
                           └── Session Management

ChatService ──── LLM Integration
               └── Vocabulary Extraction

DatabaseService ── Supabase Integration
                └── Row Level Security
```

### Key Components

- **FlashcardService**: Core learning engine with spaced repetition
- **VocabularyService**: Vocabulary management and statistics
- **UserService**: Authentication and user data management
- **ChatService**: AI conversation and vocabulary extraction
- **DatabaseService**: Secure data persistence with Supabase

## 🧪 Testing

The app includes comprehensive testing coverage:

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test suites
flutter test test/flashcard_service_test.dart
flutter test test/flashcard_flow_e2e_test.dart
flutter test test/flashcard_performance_test.dart
```

### Test Coverage

- **Unit Tests**: Individual component testing
- **Integration Tests**: Service interaction testing
- **E2E Tests**: Complete user journey testing
- **Performance Tests**: Scalability and memory efficiency testing

### Performance Benchmarks

- Word selection: <10ms for 10,000 vocabulary items
- Question generation: <1ms per question
- Session operations: <100ms end-to-end
- Memory usage: Stable with no observable leaks

## 🔧 Configuration

### Language Settings

Configure target and native languages in the settings screen:

- **Target Language**: The language you're learning
- **Native Language**: Your first language for translations
- **Learning Preferences**: Difficulty levels and focus areas

### Flashcard Settings

Customize your learning experience:

- **Session Duration**: 5-60 minutes
- **Question Types**: Enable/disable specific formats
- **Review Prioritization**: Focus on overdue vocabulary
- **Performance Tracking**: Detailed analytics and recommendations

## 🔒 Security

### Data Protection

- **Row Level Security (RLS)**: Users can only access their own data
- **Secure Authentication**: OAuth integration with Google/Apple
- **Data Encryption**: All sensitive data encrypted in transit and at rest
- **Privacy Controls**: User-controlled data sharing and retention

### Security Features

- Input sanitization and validation
- Secure API key management
- Protected database operations
- Audit logging for sensitive actions

## 🛠️ Development

### Project Structure

```
lib/
├── models/                 # Data models
│   ├── user.dart
│   ├── user_vocabulary.dart
│   ├── flashcard_session.dart
│   └── flashcard_question.dart
├── services/              # Business logic
│   ├── flashcard_service.dart
│   ├── vocabulary_service.dart
│   ├── user_service.dart
│   └── chat_service.dart
├── screens/               # UI screens
│   ├── flashcard_start_screen.dart
│   ├── flashcard_screen.dart
│   ├── flashcard_results_screen.dart
│   └── ...
├── widgets/               # Reusable UI components
│   ├── flashcard_widget.dart
│   ├── progress_widget.dart
│   └── feedback_widget.dart
└── utils/                 # Utilities and helpers
    ├── accessibility_helper.dart
    └── app_navigation.dart
```

### Key Dependencies

```yaml
dependencies:
  flutter: ^3.24.7
  provider: ^6.1.2 # State management
  supabase_flutter: ^2.6.0 # Backend services
  shared_preferences: ^2.3.2 # Local storage
  uuid: ^4.5.0 # Unique identifiers
  json_annotation: ^4.9.0 # JSON serialization

dev_dependencies:
  flutter_test: ^3.24.7
  mockito: ^5.4.4 # Mocking for tests
  build_runner: ^2.4.12 # Code generation
```

### Code Generation

Generate JSON serialization and mocks:

```bash
flutter packages pub run build_runner build
```

## 📊 Performance

### Optimization Features

- **Efficient Algorithms**: O(n log n) word selection with smart caching
- **Database Optimization**: Minimized queries with batch operations
- **Memory Management**: Proper disposal and efficient data structures
- **UI Performance**: Smooth animations with optimized rebuilds

### Scalability

- Handles 10,000+ vocabulary items efficiently
- Linear scaling with vocabulary size
- Consistent performance across devices
- Optimized for both mobile and desktop

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run the test suite
5. Submit a pull request

### Code Style

- Follow [Dart style guidelines](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable names
- Add documentation for public APIs
- Include tests for new features

## 📱 Supported Platforms

- **Web**: Chrome, Firefox, Safari, Edge
- **Mobile**: iOS 12+, Android API 21+
- **Desktop**: macOS 10.14+, Windows 10+, Linux

## 🔮 Roadmap

### Near Term (Next Release)

- [ ] Offline mode support
- [ ] Advanced analytics dashboard
- [ ] Custom question types
- [ ] Voice input support

### Medium Term

- [ ] Social learning features
- [ ] Gamification elements
- [ ] Advanced AI tutoring
- [ ] Custom study plans

### Long Term

- [ ] AR/VR integration
- [ ] Advanced speech recognition
- [ ] Community features
- [ ] Marketplace for content

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Supabase for backend infrastructure
- OpenAI for language model capabilities
- The open-source community for inspiration

## 📞 Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Create a GitHub issue for bugs
- **Questions**: Join our community discussions
- **Email**: support@languagelearningapp.com

---

**Happy Learning!** 🎓✨
