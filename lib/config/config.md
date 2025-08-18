# Configuration Documentation

This file documents where each variable in `config.yaml` is defined in the codebase.

## Model Settings

Defined in `lib/services/chat_service.dart`:

- `model.name`: The name of the LLM model to use
- `model.temperature`: The temperature setting for the model
- `model.max_tokens`: Maximum number of tokens for model responses

## Prompt Variables

Defined in `lib/services/language_settings_service.dart`:

- `prompt_variables.target_language`: Variable for target language
- `prompt_variables.native_language`: Variable for native language
- `prompt_variables.support_language_1`: Variable for first support language
- `prompt_variables.support_language_2`: Variable for second support language

## Default Settings

Defined in `lib/services/language_settings_service.dart`:

- `default_settings.target_language`: Default target language code
- `default_settings.native_language`: Default native language code
- `default_settings.support_language_1`: Default first support language code
- `default_settings.support_language_2`: Default second support language code

## System Prompt Type

Defined in `lib/services/prompts.dart`:

- `system_prompt_type`: Specifies which prompt to use as the system prompt
  - Available values: "default", "vocabulary", "grammar", "conversation", "quiz", "writing", "pronunciation", "cultural"
