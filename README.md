# LLM Chat App

A Flutter application that allows you to chat with an LLM (Language Learning Model). The app works on both web and iOS platforms, with a modern Material Design 3 interface.

## Features

- Clean and modern UI
- Real-time chat interface
- Support for markdown rendering in AI responses
- Web and iOS compatibility
- Dark/Light theme support
- Message history
- Loading indicators

## Setup

1. Make sure you have Flutter installed on your machine. If not, follow the [official Flutter installation guide](https://flutter.dev/docs/get-started/install).

2. Clone this repository:
```bash
git clone <repository-url>
cd llm_chat_app
```

3. Create a `.env` file in the root directory and add your OpenAI API key:
```
LLM_API_KEY=your_openai_api_key_here
```

4. Install dependencies:
```bash
flutter pub get
```

5. Update the API endpoint in `lib/services/chat_service.dart` to point to your LLM service.

## Running the App

### For iOS:
```bash
flutter run -d ios
```

### For Web:
```bash
flutter run -d chrome
```

## Configuration

To customize the LLM integration:

1. Open `lib/services/chat_service.dart`
2. Update the API endpoint URL in the `sendMessage` method
3. Modify the request payload structure if needed for your specific LLM API

## Dependencies

- flutter_markdown: For rendering markdown responses
- provider: For state management
- http: For API calls
- flutter_dotenv: For environment variable management
- shared_preferences: For local storage

## Contributing

Feel free to submit issues and enhancement requests! 



## upcoming ideas:

1) personalized persistent teaching (users creation):
- db of users, with:
    - user preferences
    - history of chat
    - vocabulary db
- chat llm:
    - it will be a teacher:
        - present new verbs, nouns, adjectives and adverbs.
    - situational character:
        - a personage, such as cashier, waiter, boss, colleague, investor



- improver target:
    - vocabulary review
    - grammar review
    - pronunciation
    - cultural (regional variation)

- quiz maker!
-  memory cards ! 
- image story maker !
- maze story! 
