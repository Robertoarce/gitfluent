import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/podcast_service.dart';
import '../services/user_service.dart';
import '../models/podcast.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final TextEditingController _topicController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isLoading = false;
  bool _isPlaying = false;
  PodcastScript? _currentScript;
  int _currentLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _playNextLine();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _generatePodcast() async {
    if (_topicController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentScript = null;
      _currentLineIndex = -1;
      _isPlaying = false;
    });

    try {
      final podcastService = context.read<PodcastService>();
      final userService = context.read<UserService>();
      
      final targetLang = userService.currentUser?.targetLanguage ?? 'it';
      final nativeLang = userService.currentUser?.nativeLanguage ?? 'en';

      final script = await podcastService.generatePodcast(
        topic: _topicController.text,
        targetLanguage: _getLanguageName(targetLang),
        nativeLanguage: _getLanguageName(nativeLang),
      );

      setState(() {
        _currentScript = script;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate podcast: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'it': return 'Italian';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'en': return 'English';
      default: return 'Italian';
    }
  }

  Future<void> _togglePlay() async {
    if (_currentScript == null) return;

    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      if (_currentLineIndex == -1) {
        _currentLineIndex = 0;
      }
      _playNextLine();
    }
  }

  Future<void> _playNextLine() async {
    if (!_isPlaying || _currentScript == null) return;

    if (_currentLineIndex >= _currentScript!.dialogue.length) {
      setState(() {
        _isPlaying = false;
        _currentLineIndex = -1;
      });
      return;
    }

    setState(() {}); // Update UI to highlight current line

    final line = _currentScript!.dialogue[_currentLineIndex];
    
    // Set language based on line language code
    // Simple mapping, needs to be robust
    String lang = 'en-US';
    if (line.languageCode == 'it') lang = 'it-IT';
    if (line.languageCode == 'es') lang = 'es-ES';
    if (line.languageCode == 'fr') lang = 'fr-FR';
    if (line.languageCode == 'de') lang = 'de-DE';
    
    await _flutterTts.setLanguage(lang);
    
    // Adjust pitch/voice based on speaker (simple heuristic)
    if (line.speaker == 'Teacher' || line.speaker == 'Host') {
      await _flutterTts.setPitch(1.0);
    } else {
      await _flutterTts.setPitch(1.2); // Slightly higher for student/guest
    }

    await _flutterTts.speak(line.text);
    
    // Increment index for next call (which happens in completion handler)
    _currentLineIndex++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('AI Podcast'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'Enter a topic (e.g., Ordering Coffee)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _generatePodcast,
                    ),
                  ),
                  onSubmitted: (_) => _generatePodcast(),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentScript == null
                    ? _buildEmptyState()
                    : _buildScriptView(),
          ),
        ],
      ),
      floatingActionButton: _currentScript != null
          ? FloatingActionButton(
              onPressed: _togglePlay,
              backgroundColor: const Color(0xFF6B47ED),
              child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.podcasts, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Generate a podcast to listen',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentScript!.dialogue.length + 1, // +1 for title
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                Text(
                  _currentScript!.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Topic: ${_currentScript!.topic}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final lineIndex = index - 1;
        final line = _currentScript!.dialogue[lineIndex];
        final isCurrent = _isPlaying && lineIndex == _currentLineIndex - 1; // -1 because index was incremented before speak

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent ? Border.all(color: Colors.blue[200]!) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.speaker,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: line.speaker == 'Teacher' || line.speaker == 'Host' 
                      ? Colors.blue[700] 
                      : Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line.text,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}
