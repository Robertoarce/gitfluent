import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/conversation_service.dart';

class SelectableTextWidget extends StatefulWidget {
  final String text;
  final List<SelectableWord> selectableWords;
  final Function(String word, SelectableWord wordData) onWordSelected;

  const SelectableTextWidget({
    Key? key,
    required this.text,
    required this.selectableWords,
    required this.onWordSelected,
  }) : super(key: key);

  @override
  State<SelectableTextWidget> createState() => _SelectableTextWidgetState();
}

class _SelectableTextWidgetState extends State<SelectableTextWidget> {
  String? _selectedWord;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _handleTap(details.globalPosition);
      },
      child: RichText(
        text: _buildTextSpan(),
      ),
    );
  }

  TextSpan _buildTextSpan() {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // Sort selectable words by start index
    final sortedWords = List<SelectableWord>.from(widget.selectableWords)
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    for (final word in sortedWords) {
      // Add text before the word
      if (word.startIndex > currentIndex) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex, word.startIndex),
          style: const TextStyle(color: Colors.black),
        ));
      }

      // Add the selectable word
      final isSelected = _selectedWord == word.word;
      final isInVocabulary = word.isInVocabulary;
      final isInLearningPool = word.isInLearningPool;

      spans.add(TextSpan(
        text: word.word,
        style: TextStyle(
          color: isSelected
              ? Colors.blue
              : (isInVocabulary || isInLearningPool)
                  ? Colors.green
                  : Colors.black,
          backgroundColor: isSelected ? Colors.blue.withOpacity(0.2) : null,
          decoration: isInVocabulary ? TextDecoration.underline : null,
          decorationColor: isInVocabulary ? Colors.green : null,
          fontWeight: isInLearningPool ? FontWeight.bold : FontWeight.normal,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _selectWord(word),
      ));

      currentIndex = word.endIndex;
    }

    // Add remaining text
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(currentIndex),
        style: const TextStyle(color: Colors.black),
      ));
    }

    return TextSpan(children: spans);
  }

  void _handleTap(Offset globalPosition) {
    // Convert global position to local position
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Find the character at the tap position
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = textPainter.getPositionForOffset(localPosition);
    final characterIndex = offset.offset;

    // Find which word was tapped
    for (final word in widget.selectableWords) {
      if (characterIndex >= word.startIndex && characterIndex < word.endIndex) {
        _selectWord(word);
        return;
      }
    }

    // If no word was tapped, clear selection
    setState(() {
      _selectedWord = null;
    });
  }

  void _selectWord(SelectableWord word) {
    setState(() {
      _selectedWord = word.word;
    });

    widget.onWordSelected(word.word, word);
  }
}
