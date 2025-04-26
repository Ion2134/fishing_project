// fish_ai_chat_sheet.dart

import 'dart:convert'; // For jsonEncode/Decode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP package

// Simple class to represent a chat message
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading; // Optional: To show loading state for AI message

  ChatMessage({required this.text, required this.isUser, this.isLoading = false});
}

class FishAiChatSheet extends StatefulWidget {
  final String speciesName;

  const FishAiChatSheet({super.key, required this.speciesName});

  @override
  State<FishAiChatSheet> createState() => _FishAiChatSheetState();
}

class _FishAiChatSheetState extends State<FishAiChatSheet> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAiResponding = false;
  bool _initialFactsLoaded = false;
  String? _errorMessage;

  // --- API Configuration ---
  // IMPORTANT: Replace with your actual API endpoint
  final String _apiUrl = "https://ab05-35-237-104-229.ngrok-free.app/api/generate";
  final Map<String, String> _headers = {
    "Content-Type": "application/json",
    "ngrok-skip-browser-warning": "1",
  };
  final String _modelName = "gemma3:4b";
  // --- End API Configuration ---


  @override
  void initState() {
    super.initState();
    _fetchInitialFacts();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchInitialFacts() async {
    if (_initialFactsLoaded) return;

    setState(() {
      _messages.add(ChatMessage(text: "Loading facts...", isUser: false, isLoading: true));
      _scrollToBottom();
    });

    final initialPrompt = "Give me some interesting facts about the fish species: ${widget.speciesName}. Keep it concise.";
    await _callFishAI(initialPrompt, isInitialCall: true);

    setState(() {
      _initialFactsLoaded = true;
      _messages.removeWhere((m) => m.isLoading);
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isAiResponding) return; // Prevent sending empty or while responding

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _scrollToBottom();
    });

    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(text: "...", isUser: false, isLoading: true));
      _scrollToBottom();
    });

    await _callFishAI(text);

    setState(() {
      _messages.removeWhere((m) => m.isLoading);
    });
  }

  Future<void> _callFishAI(String prompt, {bool isInitialCall = false}) async {
    if (_isAiResponding && !isInitialCall) return;

    setState(() {
      _isAiResponding = true;
      _errorMessage = null;
    });

    try {
      final body = jsonEncode({
        "model": _modelName,
        "prompt": prompt,
        "stream": false,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: _headers,
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        // --- ADJUST RESPONSE PARSING AS NEEDED ---
        String? aiText = decodedResponse['generation']?['content'];
        // --- --- --- --- --- --- --- --- --- --- ---

        if (aiText != null && aiText.isNotEmpty) {
          setState(() {
            _messages.add(ChatMessage(text: aiText.trim(), isUser: false));
          });
        } else {
          print("AI response parsed, but text content is missing or empty.");
          print("Full Response Body: ${response.body}");
          setState(() { _errorMessage = "AI gave an empty response."; });
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        setState(() { _errorMessage = "Error ${response.statusCode}: Could not reach FishAI."; });
      }
    } catch (e) {
      print("Network/Request Error: $e");
      if (mounted) { setState(() { _errorMessage = "Network error. Could not connect to FishAI."; }); }
    } finally {
      if (mounted) {
        setState(() {
          _isAiResponding = false;
          _messages.removeWhere((m) => m.isLoading);
        });
        _scrollToBottom();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      // Adjust padding to move content up when keyboard appears
      padding: EdgeInsets.only(
        // Keep bottom padding for keyboard
        bottom: MediaQuery.of(context).viewInsets.bottom,
        // Remove side padding here, apply within Column if needed
        // left: 16,
        // right: 16,
        // Remove top padding here, handle below
        // top: 20,
      ),
      child: Column( // Main column for the sheet content
        // crossAxisAlignment: CrossAxisAlignment.stretch, // Keep this if buttons/input should be full width
        children: [
          // --- ADD DRAG HANDLE ---
          Center( // Center the handle horizontally
            child: Container(
              width: 40, // Width of the handle
              height: 5,  // Height of the handle
              margin: const EdgeInsets.only(top: 10.0, bottom: 10.0), // Spacing around handle
              decoration: BoxDecoration(
                color: Colors.grey[400], // Handle color
                borderRadius: BorderRadius.circular(10), // Rounded corners
              ),
            ),
          ),
          // --- END DRAG HANDLE ---

          // --- Chat History (Apply horizontal padding here) ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add side padding for chat list
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      margin: EdgeInsets.symmetric(vertical: 4).copyWith(
                        left: message.isUser ? 40 : 0,
                        right: message.isUser ? 0 : 40,
                      ),
                      decoration: BoxDecoration(
                          color: message.isLoading ? Colors.grey.shade300
                              : message.isUser ? Colors.blue[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(15).copyWith(
                            bottomRight: message.isUser ? Radius.circular(0) : Radius.circular(15),
                            bottomLeft: message.isUser ? Radius.circular(15) : Radius.circular(0),
                          )
                      ),
                      child: message.isLoading
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(message.text),
                    ),
                  );
                },
              ),
            ),
          ),

          // --- Error Display (Apply horizontal padding here) ---
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Add side padding
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // --- Input Area (Apply horizontal padding here) ---
          Padding(
            // Add bottom padding to space it from the very edge of the sheet
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: "Ask a follow-up question...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.text, // Ensure correct keyboard
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isAiResponding,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isAiResponding ? null : _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ], // End main Column children
      ), // End main Column
    ); // End Padding
  }
}