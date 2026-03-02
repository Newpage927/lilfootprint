import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => AiChatScreenState();
}

class AiChatScreenState extends State<AiChatScreen> {
  static const String _myApiKey = "";

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _chatMessages = [];
  List<String> _suggestQuestions = [];
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    Gemini.init(apiKey: _myApiKey);
    _chatMessages.add(ChatMessage(content: "您好！我是 AI 育兒助手，有什麼我可以幫您的嗎!", user: 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 育兒助手")),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length + (_responding ? 1 : 0) + (_suggestQuestions.isNotEmpty && !_responding ? 1 : 0),
              // ignore: body_might_complete_normally_nullable
              itemBuilder: (context, index) {
                if (index < _chatMessages.length) {
                  final message = _chatMessages[index];
                  return _messageBubble(message.content, user: message.user);
                }

                if (_responding && index == _chatMessages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(left: 16, top: 10, bottom: 10),
                    child: Text("AI助手正在思考中...", style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                if (_suggestQuestions.isNotEmpty && !_responding && index == _chatMessages.length) return _suggestionBubble();
              },
            ),
          ),
          // User Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 166, 165, 165),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "輸入任何育兒相關問題...",
                      fillColor: const Color.fromARGB(255, 245, 245, 245),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: IconButton(
                    icon: _responding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _responding ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "您可能想問：",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _suggestQuestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                labelStyle: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppTheme.primaryColor),
                shape: const StadiumBorder(),
                elevation: 1,
                onPressed: () => _sendMessage(userInput: suggestion),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String message, {required int user}) {
    bool AI = (user == 0) ? true : false;
    final textColor = AI ? Colors.black : Colors.white;
    return Align(
      alignment: AI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AI ? Colors.white : AppTheme.primaryColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(AI ? 0 : 16),
            bottomRight: Radius.circular(AI ? 16 : 0),
          ),
          border: AI ? Border.all(color: const Color.fromARGB(255, 240, 228, 228)) : null,
        ),
        child: MarkdownBody(
          data: message,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
            strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            listBullet: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }

  void _scrollBottom() {
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

  void _formatOutput(String originalResponse) {
    if (originalResponse == "發生錯誤，請稍後再試或是聯繫客服人員") {
       setState(() {
        _chatMessages.add(ChatMessage(content: originalResponse, user: 0));
      });
      return;
    }

    if (!originalResponse.contains("(((SUGGESTIONS)))")) {
      setState(() {
        _chatMessages.add(ChatMessage(content: originalResponse.trim(), user: 0));
        _suggestQuestions = [];
      });
      return;
    }
    final response = originalResponse.split("(((SUGGESTIONS)))");
    String answer = response[0].trim();
    List<String> suggestions = response[1]
        .trim()
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.replaceAll(RegExp(r'^\d+[\.\、]\s*'), ''))
        .toList();

    setState(() {
      _chatMessages.add(ChatMessage(content: answer, user: 0));
      _suggestQuestions = suggestions.take(4).toList();
    });
  }

  Future<void> _sendMessage({String? userInput}) async {
    final userText = userInput ?? _textController.text.trim();
    if (userText.isEmpty) return;

    const String precautions = '''
The following are some precautions:
1. Please answer the question with Traditional Chinese (繁體中文).
2. Only answer questions related to parenting.
3. If the questions isn't parenting-related answer: "無法回答此類型的問題，我只能回答育兒相關資訊。"
4. Obtain the informations from reliable source like professional medical websites.
5. Keep the tone warm and supportive.
6. After your answer, provide exactly 4 short follow-up questions that the user might want to ask next.
7. Provide the follow-up questions that are related to the current question.
8. Separate the main answer and the suggestions with the string "(((SUGGESTIONS)))".
9. Put each suggestion on a new line.

Format Example:
[Your Main Content Here]
(((SUGGESTIONS)))
寶寶發燒怎麼辦？
副食品什麼時候開始吃？
如何訓練寶寶睡過夜？
寶寶便秘怎麼處理？

User Question: 
''';

    setState(() {
      _chatMessages.add(ChatMessage(content: userText, user: 1));
      _responding = true;
      _suggestQuestions.clear();
      if (userInput == null) {
        _textController.clear();
      }
    });
    _scrollBottom();

    try {
      final prompt = await Gemini.instance.prompt(
        parts: [Part.text("$precautions$userText")],
        model: "gemini-2.5-flash",
      );
      
      final geminiOutput = prompt?.output ?? "發生錯誤，請稍後再試或連繫客服人員";
      _formatOutput(geminiOutput);

    } catch (e) {
      debugPrint("Gemini Error: $e");
      setState(() {
        _chatMessages.add(ChatMessage(content: "發生錯誤，請稍後再試或連繫客服人員", user: 0));
      });
    } finally {
      setState(() {
        _responding = false;
      });
      _scrollBottom();
    }
    _scrollBottom();
  }
}

class ChatMessage {
  final String content;
  final int user; // 0: Gemini, 1: Parents
  ChatMessage({required this.content, required this.user});
}
