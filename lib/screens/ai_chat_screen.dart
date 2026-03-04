import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/theme.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => AiChatScreenState();
}

class ChatMessage {
  final String textContent;
  final bool user; // 0: Gemini, 1: Parents
  ChatMessage({required this.textContent, required this.user});
}

class AiChatScreenState extends State<AiChatScreen> {
  static const String _apiKey = "";

  final List<ChatMessage> _messages = [];
  List<String> _suggestQuestions = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _responding = false;
  bool _shownScrollButton = true;

  @override
  initState() {
    super.initState();
    Gemini.init(apiKey: _apiKey);
    _messages.add(
      ChatMessage(textContent: "您好！我是 AI 育兒助手，有什麼我可以幫您的嗎!", user: false),
    );
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 育兒助手")),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16.0),
                  itemCount:
                      _messages.length +
                      (_responding ? 1 : 0) +
                      (_suggestQuestions.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      final chatMessage = _messages[index];
                      return _formatMessage(
                        chatMessage.textContent,
                        chatMessage.user,
                      );
                    } else if (_responding) {
                      return _formatResponding();
                    }

                    if (_responding == false &&
                        _suggestQuestions.isNotEmpty &&
                        index == _messages.length) {
                      return _showSuggestQuestions();
                    }
                  },
                ),
                if (_shownScrollButton)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _scrollDownButton(),
                    ),
                  ),
              ],
            ),
          ),
          // User Input Bar
          Padding(
            padding: EdgeInsets.only(
              bottom: 32.0,
              top: 16.0,
              left: 16.0,
              right: 16.0,
            ),
            child: _userTextField(),
          ),
        ],
      ),
    );
  }

  Widget _formatMessage(String textContent, bool user) {
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        margin: EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: user ? AppTheme.primaryColor : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.only(
            topLeft: user ? Radius.circular(16.0) : Radius.circular(0.0),
            topRight: user ? Radius.circular(0.0) : Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
        ),
        child: MarkdownBody(
          data: textContent,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: user ? Colors.white : Colors.black,
              fontSize: 16,
              height: 1.4,
            ),
            strong: TextStyle(
              color: user ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
            listBullet: TextStyle(color: user ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _formatResponding() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        margin: EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
        ),
        child: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              '正在思考...',
              textStyle: TextStyle(
                color: Colors.black,
                fontSize: 16.0,
                //fontWeight: FontWeight.bold
              ),
              speed: Duration(milliseconds: 300),
            ),
          ],
          pause: Duration(milliseconds: 500),
          displayFullTextOnTap: false,
          repeatForever: true,
        ),
      ),
    );
  }

  Widget _userTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 5.0,
            spreadRadius: 5.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(color: Colors.black, fontSize: 16.0),
              controller: _textController,
              decoration: InputDecoration(
                hintText: _responding ? "AI育兒助手正在回覆中, 請稍後" : "輸入任何育兒相關問題: ",
                hintStyle: TextStyle(fontSize: 16.0),
                fillColor: Colors.grey.shade100,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.only(
                  bottom: 16.0,
                  top: 16.0,
                  left: 16.0,
                  right: 8.0,
                ),
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: IconButton(
              onPressed: _responding ? null : () => _sendMessage(null),
              icon: _responding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
          SizedBox(width: 8.0),
        ],
      ),
    );
  }

  void _sendMessage(String? suggestText) async {
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
    final userInput = suggestText ?? _textController.text.trim();
    if (userInput.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(textContent: userInput, user: true));
      _scrollToBottom();
      _responding = true;
      _suggestQuestions.clear();
      if (suggestText == null) {
        _textController.clear();
      }
    });

    try {
      final response = await Gemini.instance.prompt(
        parts: [Part.text("$precautions$userInput")],
        model: "gemini-2.5-flash",
      );

      final geminiOutput = response?.output ?? "發生錯誤，請稍後再試或連繫客服人員";
      final processedOutput = geminiOutput.split("(((SUGGESTIONS)))");
      String answer = processedOutput[0].trim();
      List<String> suggestions = processedOutput[1]
          .trim()
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.replaceAll(RegExp(r'^\d+[\.\、]\s*'), ''))
          .toList();

      if (suggestions.isNotEmpty) {
        _suggestQuestions.clear();
        _suggestQuestions = suggestions;
      }

      setState(() {
        _messages.add(ChatMessage(textContent: answer, user: false));
        _scrollToBottom();
        //_suggestQuestions = suggestions.take(4).toList();
      });
    } catch (error) {
      debugPrint("$error");
      _messages.add(ChatMessage(textContent: "發生錯誤，請稍後再試或連繫客服人員", user: false));
      _scrollToBottom();
    } finally {
      setState(() {
        _responding = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _scrollDownButton() {
    return Container(
      width: 36.0,
      height: 36.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5.0,
            spreadRadius: 5.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.all(0.0),
        onPressed: () => _scrollToBottom(),
        icon: Icon(Icons.arrow_downward_rounded, color: Colors.grey.shade600),
      ),
    );
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 50) {
        if (_shownScrollButton == false) {
          setState(() {
            _shownScrollButton = true;
          });
        }
      } else {
        setState(() {
          _shownScrollButton = false;
        });
      }
    }
  }

  // 還沒弄懂
  Widget _showSuggestQuestions() {
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
                onPressed: () => _sendMessage(suggestion),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 代辦: 參考資料來源連結
}
