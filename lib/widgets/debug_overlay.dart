import 'package:flutter/material.dart';
import '../utils/debug_helper.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;

  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  final List<DebugMessage> _messages = [];
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Override the debug helper to also show messages on screen
    _setupDebugInterception();
  }

  void _setupDebugInterception() {
    // This is a simple demonstration - in a real implementation,
    // you might want to use a stream or callback system
  }

  void addMessage(String section, String message) {
    setState(() {
      _messages.insert(
          0,
          DebugMessage(
            section: section,
            message: message,
            timestamp: DateTime.now(),
          ));

      // Keep only last 20 messages
      if (_messages.length > 20) {
        _messages.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: 50,
            right: 8,
            left: 8,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Debug Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() => _messages.clear()),
                          icon: const Icon(Icons.clear,
                              color: Colors.white, size: 16),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          onPressed: () => setState(() => _isVisible = false),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _messages.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No debug messages yet.\nUse the Test Debug button to see output.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.withOpacity(0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getSectionColor(
                                                message.section),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            message.section.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTime(message.timestamp),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        // Debug toggle button
        Positioned(
          top: 50,
          right: 8,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _isVisible = !_isVisible),
            backgroundColor: _isVisible ? Colors.green : Colors.grey,
            child: Icon(
              _isVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'supabase':
        return Colors.blue;
      case 'chat_service':
        return Colors.purple;
      case 'user_service':
        return Colors.orange;
      case 'vocabulary_service':
        return Colors.teal;
      case 'auth_service':
        return Colors.red;
      case 'flashcard_service':
        return Colors.indigo;
      case 'language_settings':
        return Colors.cyan;
      case 'llm_output_formatter':
        return Colors.pink;
      case 'nlp_service':
        return Colors.brown;
      case 'accessibility':
        return Colors.lime;
      case 'config':
        return Colors.amber;
      case 'general':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class DebugMessage {
  final String section;
  final String message;
  final DateTime timestamp;

  DebugMessage({
    required this.section,
    required this.message,
    required this.timestamp,
  });
}

// Global debug overlay instance
final GlobalKey<_DebugOverlayState> debugOverlayKey =
    GlobalKey<_DebugOverlayState>();

// Helper function to add debug messages to overlay
void addDebugMessageToOverlay(String section, String message) {
  debugOverlayKey.currentState?.addMessage(section, message);
}
