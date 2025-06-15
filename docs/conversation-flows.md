# Conversation Service Flow Documentation

This directory contains detailed process flow diagrams for the ConversationService component of the language learning application.

## Available Diagrams

### 1. [ConversationService Lifecycle Flow](./conversation-service-lifecycle.md)

Complete service initialization and lifecycle management, including:

- Service construction and dependency injection
- Configuration loading and validation
- Gemini API setup and authentication
- Prompt configuration and system message setup
- Error handling and recovery mechanisms

**Mermaid File**: [conversation-service-lifecycle.mermaid](./conversation-service-lifecycle.mermaid)

### 2. [ConversationService Message Processing Flow](./conversation-message-flow.md)

Detailed message handling cycle, covering:

- User input validation and processing
- Chat history management
- Gemini API communication
- Response parsing and formatting
- Educational content extraction (translations, vocabulary, corrections)
- UI state management and updates

**Mermaid File**: [conversation-message-flow.mermaid](./conversation-message-flow.mermaid)

## Key Features Documented

### Educational Response Processing

- Structured JSON response parsing
- Vocabulary extraction and formatting
- Grammar correction identification
- Translation and follow-up question handling
- Fallback to raw text when parsing fails

### Error Handling

- API key validation
- Network error recovery
- Malformed response handling
- Graceful degradation strategies

### State Management

- Loading state synchronization
- Provider pattern integration
- Reactive UI updates
- Chat history persistence

## Technical Implementation

These flows document the `ConversationService` class found in `lib/services/conversation_service.dart`, which provides:

- Structured conversation experiences for language learning
- Integration with Google's Gemini AI API
- Rich educational content formatting
- Robust error handling and recovery

The service works in conjunction with:

- `SettingsService` for user preferences
- `PromptConfigService` for AI prompt management
- `LoggingService` for debugging and monitoring
- Provider pattern for state management

## Usage Context

The ConversationService is used primarily in the Conversation Practice screen, providing users with interactive language learning conversations that include:

- Real-time grammar corrections
- Vocabulary explanations
- Contextual translations
- Progressive difficulty adjustment
- Conversation continuation prompts
