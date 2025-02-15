// lib/widgets/ai_assistant_widget.dart

import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AIAssistantWidget extends StatefulWidget {
  final String? machineId;

  const AIAssistantWidget({
    Key? key,
    this.machineId,
  }) : super(key: key);

  @override
  State<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget> {
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = false;
  bool _isExpanded = false;  // Zustandsvariable für Zusammenklappen
  final AIService _aiService = AIService();

  Future<void> _sendMessage() async {
    if (_inputController.text.trim().isEmpty) return;

    final userMessage = _inputController.text.trim();
    setState(() {
      _chatHistory.add({
        'type': 'user',
        'message': userMessage,
      });
      _isLoading = true;
    });
    _inputController.clear();

    try {
      // NEUE Anfrage: Ruft deinen Endpoint /api/ai/augmented_chat auf
      // (via AIService.getAugmentedChatResponse)
      final response = await _aiService.getAugmentedChatResponse(userMessage);

      if (response['success'] == true) {
        // response könnte z.B. so aussehen:
        // { "success": true, "generated_text": "...", "retrieved_data": [...] }
        final generatedText = response['generated_text'] ?? 'Keine Antwort erhalten';
        final retrievedData = response['retrieved_data'];

        setState(() {
          _chatHistory.add({
            'type': 'assistant',
            'message': generatedText,
            'localData': retrievedData,  // falls du das anzeigen möchtest
          });
        });
      } else {
        setState(() {
          _chatHistory.add({
            'type': 'assistant',
            'message': 'Entschuldigung, ich konnte keine passende Antwort finden.',
            'isError': true,
          });
        });
      }
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'type': 'assistant',
          'message': 'Ein Fehler ist aufgetreten: $e',
          'isError': true,
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // NEU: Methode zum Löschen des Chat-Verlaufs
  void _clearChatHistory() {
    setState(() {
      _chatHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Header mit Toggle-Button
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy),
                  const SizedBox(width: 8),
                  const Text(
                    'KI-Assistent',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),

          // Erweiterbarer Bereich
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? 400 : 0,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Chat-Verlauf
                  Container(
                    height: 340,
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final message = _chatHistory[_chatHistory.length - 1 - index];
                        final isUser = message['type'] == 'user';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blue[100]
                                    : message['isError'] == true
                                    ? Colors.red[50]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message['message']),
                                  if (!isUser && message['localData'] != null) ...[
                                    const Divider(),
                                    const Text(
                                      'Lokale Daten:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      message['localData'].toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Eingabebereich
                  if (_isExpanded)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              decoration: InputDecoration(
                                hintText: 'Fragen Sie den KI-Assistenten...',
                                border: const OutlineInputBorder(),
                                suffixIcon: _isLoading
                                    ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : null,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _isLoading ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),

                  // NEUER BUTTON für Chat löschen
                  if (_isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _clearChatHistory,
                        icon: const Icon(Icons.delete),
                        label: const Text('Chat löschen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
