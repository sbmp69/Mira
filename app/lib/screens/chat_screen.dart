import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../services/api.dart';

class ChatScreen extends StatefulWidget {
  final String companionId;

  const ChatScreen({super.key, required this.companionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> messages = [];
  bool isTyping = false;
  bool isRecording = false;
  String? selectedImageUri;
  Map<String, dynamic>? replyToMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ChatApi.getChatHistory(widget.companionId);
      if (mounted) {
        setState(() {
          messages = history.map((msg) => {
            'id': msg['id'],
            'text': msg['content'],
            'isUser': msg['sender'] == 'USER',
            'timestamp': _formatTime(DateTime.parse(msg['createdAt']).toLocal()),
            'replyToId': msg['replyToId'],
            if (msg['image'] != null) 'imageUri': msg['image'],
          }).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  static String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
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

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && selectedImageUri == null) return;

    final String? currentReplyToId = replyToMessage?['id'];
    
    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'isUser': true,
      'timestamp': _formatTime(DateTime.now()),
      'replyToId': currentReplyToId,
      if (selectedImageUri != null) 'imageUri': selectedImageUri,
    };

    setState(() {
      messages.add(userMessage);
      _textController.clear();
      selectedImageUri = null;
      replyToMessage = null;
      isTyping = true;
    });
    _scrollToBottom();

    try {
      final userId = await AuthApi.getUserId() ?? '925bfa8e-db2c-4e42-a346-738c6e32ee97'; 
      final response = await ChatApi.sendMessage(userId, widget.companionId, text, replyToId: currentReplyToId);
      
      final aiMessage = {
        'id': response['message']?['id'] ?? (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        'text': response['message']?['content'] ?? '...',
        'isUser': false,
        'timestamp': _formatTime(DateTime.now()),
      };

      if (mounted) {
        setState(() {
          messages.add(aiMessage);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          messages.add({
            'id': (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            'text': 'Sorry... I am having trouble connecting right now 🥺',
            'isUser': false,
            'timestamp': _formatTime(DateTime.now()),
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          children: [
            Text(
              'M I R A',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                letterSpacing: 4,
              ),
            ),
            Text(
              'Online',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: AppColors.primary),
            onPressed: () => context.push('/call/${widget.companionId}'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.surfaceLight, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isTyping) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final msg = messages[index];
                final isUser = msg['isUser'] as bool;
                
                String? repliedText;
                if (msg['replyToId'] != null) {
                  final repliedMsg = messages.cast<Map<String,dynamic>?>().firstWhere(
                    (m) => m?['id'] == msg['replyToId'],
                    orElse: () => null,
                  );
                  if (repliedMsg != null) repliedText = repliedMsg['text'] as String?;
                }
                
                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      replyToMessage = msg;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : AppColors.surface,
                          border: isUser ? null : Border.all(color: AppColors.glassBorder),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (repliedText != null && repliedText.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(left: BorderSide(color: AppColors.textMuted, width: 3)),
                                ),
                                child: Text(
                                  repliedText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isUser ? AppColors.background.withOpacity(0.8) : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (msg['imageUri'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(msg['imageUri'], width: 200, height: 200, fit: BoxFit.cover),
                                ),
                              ),
                            if (msg['text'] != null && (msg['text'] as String).isNotEmpty)
                              Text(
                                msg['text'],
                                style: TextStyle(
                                  color: isUser ? AppColors.background : AppColors.text,
                                  fontSize: 15,
                                  height: 1.4,
                                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w300,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              msg['timestamp'],
                              style: TextStyle(
                                color: isUser ? Colors.black54 : AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (replyToMessage != null)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyToMessage!['isUser'] ? 'Replying to yourself' : 'Replying to M I R A',
                            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            replyToMessage!['text'] ?? 'Image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      onPressed: () {
                        setState(() {
                          replyToMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: () {
                      // Image picker logic
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: AppColors.background, size: 18),
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
}
