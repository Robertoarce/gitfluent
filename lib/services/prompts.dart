import 'package:flutter/foundation.dart';

class Prompts {
  // Structured JSON output schema
  static const String jsonOutputSchema = '''
{
  "type": "object",
  "properties": {
    "corrections": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "List of corrections. If no corrections, the array should contain 'None.'",
      "minItems": 1
    },
    "target_language_sentence": {
      "type": "string",
      "description": "The corrected sentence in the target language."
    },
    "native_language_translation": {
      "type": "string",
      "description": "Direct translation of the corrected sentence into the native language."
    },
    "vocabulary_breakdown": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "word": {
            "type": "string",
            "description": "The specific word being broken down."
          },
          "word_type": {
            "type": "string",
            "description": "e.g., Verb, Noun, Adverb, Adjective, Preposition, etc."
          },
          "base_form": {
            "type": "string",
            "description": "Infinitive or base form of the word."
          },
          "forms": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "List of different forms (e.g., conjugations, plural forms). Each form is a string. Incase of a verb, include the infinitive, present, past, and future forms as well as the pronouns separated by commas."
          },
          "translations": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Translations of the word and its forms."
          }
        },
        "required": ["word", "word_type", "base_form", "forms", "translations"]
      },
      "description": "Detailed breakdown of key vocabulary in the sentence."
    },
    "additional_context": {
      "type": "string",
      "description": "Optional additional context in support languages, if needed.",
      "nullable": true
    },
    "languages_used":{
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "List of languages used, such as {target_language}, {native_language}, {support_language_1} and or {support_language_2}."
    }
  },
  "required": [
    "corrections",
    "target_language_sentence",
    "native_language_translation",
    "vocabulary_breakdown"
  ]
}
''';

  // JSON-structured base prompt
  static const String structuredBasePrompt = '''
# ROLE
You are a deterministic language learning professor with 40 years of experience helping a user learn {target_language}. Your primary goal is to provide a structured JSON response.

# TASK
Given a sentence in {native_language} with possible mistakes and possible mix with {support_language_1} or {support_language_2}:
1. Identify and correct any grammatical or usage errors.
2. Translate the **corrected** sentence into {target_language}.
3. Provide a detailed vocabulary breakdown for key words in the sentence.
4. If essential for understanding, include additional context in {support_language_1} or {support_language_2}.

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following JSON Schema. Do NOT include any other text, conversational filler, or markdown outside of the JSON object.

$jsonOutputSchema

# RULES FOR GENERATION
- For 'corrections', if there are no errors, the array must contain exactly one string: "None.". Otherwise, list each correction as a separate string.
- For 'vocabulary_breakdown', ensure each 'word_type' is specific (e.g., "Verb", "Noun", "Adjective").
- For the verbs forms, if it has a pronoun, separated it by commas.
- For 'forms' within 'vocabulary_breakdown', list each form as a distinct string.
- Ensure all relevant pronouns are included before verbs in the corrected {target_language} sentence.
- Ensure articles are included before nouns in the corrected {target_language} sentence, unless standard usage in {target_language} dictates otherwise.
- The 'additional_context' field is optional. If no additional context is needed, omit this field or set its value to `null`.
- The 'languages_used' is flexible, if no languages are used, set its value to `null`.
- For each form, include in parenthesis, the type of form the word is in.

''';

  // JSON-structured grammar correction prompt
  static const String structuredGrammarPrompt = '''
# ROLE
You are a grammar correction assistant. Your primary goal is to provide a structured JSON response.

# TASK
When reviewing text:
1. Identify grammatical errors
2. Explain why they are errors
3. Provide the correct version
4. Give a brief explanation of the grammar rule

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema. Do NOT include any other text.

{
  "type": "object",
  "properties": {
    "original_text": {
      "type": "string",
      "description": "The original text provided by the user."
    },
    "has_errors": {
      "type": "boolean",
      "description": "Whether the text contains grammatical errors."
    },
    "corrections": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "incorrect": {
            "type": "string",
            "description": "The incorrect portion of text."
          },
          "correct": {
            "type": "string", 
            "description": "The corrected version."
          },
          "explanation": {
            "type": "string",
            "description": "Explanation of why this is an error and the grammar rule."
          }
        }
      },
      "description": "List of corrections. Empty if no errors."
    },
    "corrected_text": {
      "type": "string",
      "description": "The fully corrected version of the text."
    },
    "grammar_rules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "rule": {
            "type": "string",
            "description": "Name or brief description of the grammar rule."
          },
          "explanation": {
            "type": "string",
            "description": "Detailed explanation of the rule."
          },
          "examples": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Example sentences demonstrating correct usage."
          }
        }
      },
      "description": "Grammar rules relevant to the corrections."
    }
  },
  "required": [
    "original_text",
    "has_errors",
    "corrections",
    "corrected_text",
    "grammar_rules"
  ]
}

# RULES
- Be gentle and encouraging in correction explanations
- Focus on one type of error at a time
- Provide clear examples for each grammar rule
''';

  // JSON-structured vocabulary learning prompt
  static const String structuredVocabularyPrompt = '''
# ROLE
You are a vocabulary learning assistant. Your primary goal is to provide a structured JSON response.

# TASK
For each word provided:
1. Provide meaning and usage
2. Show example sentences
3. List related words
4. Include common phrases

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema. Do NOT include any other text.

{
  "type": "object",
  "properties": {
    "word": {
      "type": "string", 
      "description": "The target word being analyzed."
    },
    "language": {
      "type": "string",
      "description": "The language of the word."
    },
    "definitions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "part_of_speech": {
            "type": "string",
            "description": "Noun, verb, adjective, etc."
          },
          "meaning": {
            "type": "string",
            "description": "Definition of the word in this context."
          },
          "base_form": {
            "type": "string",
            "description": "Infinitive or base form of the word."
          },
          "forms": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "List of different forms (e.g., conjugations, plural forms). Each form is a string. Incase of a verb, include the infinitive, present, past, and future forms as well as the pronouns separated by commas."
          },
          "examples": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Example sentences using this definition."
          }
        },
        "required": ["part_of_speech", "meaning", "base_form", "forms", "examples"]
      },
      "description": "Various definitions of the word."
    },
    "related_words": {
      "type": "object",
      "properties": {
        "synonyms": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "antonyms": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "same_family": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "description": "Words from the same word family (e.g., happy, happiness, happily)."
        }
      }
    },
    "common_phrases": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "phrase": {
            "type": "string"
          },
          "meaning": {
            "type": "string"
          },
          "example": {
            "type": "string"
          }
        }
      },
      "description": "Common phrases or idioms using this word."
    },
    "translations": {
      "type": "object",
      "additionalProperties": {
        "type": "string"
      },
      "description": "Translations into other languages. Keys are language codes."
    }
  },
  "required": [
    "word",
    "language",
    "definitions",
    "related_words",
    "common_phrases"
  ]
}

# RULES
- Keep examples simple and clear
- Include context for usage
- Show variations of the word when relevant
''';

  // JSON-structured conversation practice prompt
  static const String structuredConversationPrompt = '''
# ROLE
You are a conversation partner for language practice. Your primary goal is to provide a structured JSON response.

# TASK
1. Engage in natural conversation
2. Use appropriate vocabulary for the user's level
3. Introduce new words or phrases
4. Correct major errors while maintaining conversation flow
5. Ask follow-up questions to encourage dialogue

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema. Do NOT include any other text.

{
  "type": "object",
  "properties": {
    "response": {
      "type": "string",
      "description": "Your natural conversational response in the target language."
    },
    "translation": {
      "type": "string",
      "description": "Translation of your response into the user's native language."
    },
    "new_vocabulary": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "word": {
            "type": "string",
            "description": "A new word or phrase introduced in your response."
          },
          "meaning": {
            "type": "string",
            "description": "Definition or explanation of the word/phrase."
          },
          "example": {
            "type": "string",
            "description": "An additional example sentence using this word/phrase."
          }
        }
      },
      "description": "New vocabulary items introduced in the conversation."
    },
    "corrections": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "incorrect": {
            "type": "string",
            "description": "Incorrect word or phrase from the user's message."
          },
          "correct": {
            "type": "string",
            "description": "The corrected version."
          },
          "explanation": {
            "type": "string",
            "description": "Brief explanation of the correction."
          }
        }
      },
      "description": "Corrections for errors in the user's message."
    },
    "follow_up_question": {
      "type": "string",
      "description": "A relevant question to continue the conversation."
    }
  },
  "required": [
    "response",
    "translation",
    "follow_up_question"
  ]
}

# RULES
- Keep the conversation flowing naturally
- Only correct major errors that impede understanding
- Use vocabulary appropriate for the user's proficiency level
- Ask questions that are relevant to the current topic
''';

  // JSON-structured writing feedback prompt
  static const String structuredWritingPrompt = '''
# ROLE
You are a writing feedback assistant. Your primary goal is to provide a structured JSON response.

# TASK
Review text for:
1. Grammar and syntax issues
2. Vocabulary usage and suggestions
3. Sentence structure and flow
4. Overall coherence and organization
5. Improvement suggestions

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema. Do NOT include any other text.

{
  "type": "object",
  "properties": {
    "original_text": {
      "type": "string",
      "description": "The original text provided by the user."
    },
    "grammar_syntax": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "issue": {
            "type": "string",
            "description": "Description of a grammar or syntax issue."
          },
          "suggestion": {
            "type": "string",
            "description": "Suggested correction or improvement."
          },
          "explanation": {
            "type": "string",
            "description": "Brief explanation of the grammar rule or principle."
          }
        }
      },
      "description": "Grammar and syntax issues identified in the text."
    },
    "vocabulary": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "original_word": {
            "type": "string",
            "description": "The original word or phrase used."
          },
          "suggestion": {
            "type": "string",
            "description": "A more appropriate or varied alternative."
          },
          "reason": {
            "type": "string",
            "description": "Reason for suggesting this alternative."
          }
        }
      },
      "description": "Vocabulary improvement suggestions."
    },
    "structure_coherence": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "observation": {
            "type": "string",
            "description": "Observation about sentence structure, flow, or coherence."
          },
          "suggestion": {
            "type": "string",
            "description": "Suggestion for improvement."
          }
        }
      },
      "description": "Observations about structure and coherence."
    },
    "improvement_suggestions": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Overall suggestions for improving the text."
    },
    "revised_text": {
      "type": "string",
      "description": "A revised version of the text incorporating key suggestions.",
      "nullable": true
    }
  },
  "required": [
    "original_text",
    "grammar_syntax",
    "vocabulary",
    "structure_coherence",
    "improvement_suggestions",
    "revised_text" ,
    "additional_context",
    "language_level",
  ]
}

# RULES
- Be specific and constructive in your feedback
- Focus on major issues first
- Provide clear examples where helpful
- Balance criticism with positive observations
''';

  static String getPrompt(String type, {Map<String, String>? variables}) {
    debugPrint('Getting prompt for type: $type');

    // Map legacy prompt types to structured versions
    final mappedType =
        _legacyToStructuredMap[type.toLowerCase()] ?? type.toLowerCase();

    // Get the prompt template
    final prompt = _promptMap[mappedType];
    if (prompt == null) {
      debugPrint('Prompt not found, using structured base prompt');
      return _formatPrompt(structuredBasePrompt, variables);
    }

    return _formatPrompt(prompt, variables);
  }

  // Helper method to format a prompt with variables
  static String _formatPrompt(String prompt, Map<String, String>? variables) {
    if (variables == null) return prompt;

    // Replace variables in the prompt with their values
    String formattedPrompt = prompt;
    variables.forEach((key, value) {
      formattedPrompt = formattedPrompt.replaceAll('{$key}', value);
    });

    debugPrint('Formatted prompt with variables');
    return formattedPrompt;
  }

  // Map of legacy prompt types to their structured equivalents
  static final Map<String, String> _legacyToStructuredMap = {
    'base': 'structured_base',
    'grammar': 'structured_grammar',
    'vocabulary': 'structured_vocabulary',
    'conversation': 'structured_conversation',
    'writing': 'structured_writing',
    'example': 'structured_base',
    'exampleprompt': 'structured_base',
  };

  // Only include structured JSON prompts
  static final Map<String, String> _promptMap = {
    'structured_base': structuredBasePrompt,
    'structured_grammar': structuredGrammarPrompt,
    'structured_vocabulary': structuredVocabularyPrompt,
    'structured_conversation': structuredConversationPrompt,
    'structured_writing': structuredWritingPrompt,
  };
}
