import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../services/api.dart';
import '../services/audio_service.dart';

/// Animated three-dot typing indicator like WhatsApp/Instagram
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    ));
    _animations = _controllers.map((c) =>
      Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      )).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _animations[i].value),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String companionId;

  const ChatScreen({super.key, required this.companionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  List<Map<String, dynamic>> messages = [];
  bool isTyping = false;
  bool isRecording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _currentlyPlayingId;
  String? selectedImageUri;
  String? selectedImageBase64;
  Map<String, dynamic>? replyToMessage;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _loadHistory();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    AudioService.stopAudio();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64 = base64Encode(bytes);
        setState(() {
          selectedImageUri = image.path;
          selectedImageBase64 = 'data:image/jpeg;base64,$base64';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
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
      debugPrint('Error loading history: $e');
    }
  }

  static String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  static String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildImage(String uri) {
    if (uri.startsWith('data:image')) {
      final base64String = uri.split(',').last;
      return Image.memory(base64Decode(base64String), width: 200, height: 200, fit: BoxFit.cover);
    } else if (uri.startsWith('http')) {
      return Image.network(uri, width: 200, height: 200, fit: BoxFit.cover);
    } else {
      return Image.file(File(uri), width: 200, height: 200, fit: BoxFit.cover);
    }
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

  Future<void> _startRecording() async {
    final ok = await AudioService.startRecording();
    if (ok && mounted) {
      setState(() {
        isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required to send voice notes')),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final audioBase64 = await AudioService.stopRecording();
    if (mounted) setState(() => isRecording = false);
    if (audioBase64 != null) {
      await _handleSendAudio(audioBase64);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await AudioService.cancelRecording();
    if (mounted) setState(() => isRecording = false);
  }

  Future<void> _handleSendAudio(String base64Audio) async {
    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': '🎙️ Voice note',
      'isUser': true,
      'isVoice': true,
      'timestamp': _formatTime(DateTime.now()),
    };

    setState(() {
      messages.add(userMessage);
      isTyping = true;
    });
    _scrollToBottom();

    try {
      final userId = AuthApi.getUserId() ?? 'user';
      final response = await ChatApi.sendMessage(
        userId,
        widget.companionId,
        'Voice note',
        audioBase64: base64Audio,
        wantAudio: true,
      );

      final aiMessage = {
        'id': response['message']?['id'] ?? (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        'text': response['message']?['content'] ?? '...',
        'isUser': false,
        'audioData': response['audioData'],
        'timestamp': _formatTime(DateTime.now()),
      };

      if (mounted) {
        setState(() {
          messages.add(aiMessage);
        });
        _scrollToBottom();
      }

      // Automatically play Mira's voice reply!
      if (response['audioData'] != null) {
        await _playVoice(aiMessage['id'], response['audioData'], aiMessage['text']);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          messages.add({
            'id': (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            'text': 'Sorry... I could not process your voice note right now 🥺',
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

  Future<void> _playVoice(String messageId, String? audioData, String text) async {
    if (_currentlyPlayingId == messageId) {
      await AudioService.stopAudio();
      if (mounted) setState(() => _currentlyPlayingId = null);
      return;
    }

    if (mounted) setState(() => _currentlyPlayingId = messageId);

    try {
      if (audioData != null && audioData.isNotEmpty) {
        await AudioService.playAudio(audioData);
      } else {
        // Request on-demand TTS voice
        final generatedAudio = await ChatApi.speakText(text);
        if (generatedAudio != null) {
          final idx = messages.indexWhere((m) => m['id'] == messageId);
          if (idx != -1) {
            messages[idx]['audioData'] = generatedAudio;
          }
          await AudioService.playAudio(generatedAudio);
        }
      }

      AudioService.player.onPlayerComplete.listen((_) {
        if (mounted && _currentlyPlayingId == messageId) {
          setState(() => _currentlyPlayingId = null);
        }
      });
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) setState(() => _currentlyPlayingId = null);
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && selectedImageBase64 == null) return;

    final currentReplyToId = replyToMessage?['id'];
    final imageToUpload = selectedImageBase64;
    final localImageUri = selectedImageUri;

    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'isUser': true,
      'timestamp': _formatTime(DateTime.now()),
      'replyToId': currentReplyToId,
      if (localImageUri != null) 'imageUri': localImageUri,
    };

    setState(() {
      messages.add(userMessage);
      _textController.clear();
      selectedImageUri = null;
      selectedImageBase64 = null;
      replyToMessage = null;
      isTyping = true;
    });
    _scrollToBottom();

    try {
      final userId = AuthApi.getUserId() ?? 'user';
      final response = await ChatApi.sendMessage(
        userId, 
        widget.companionId, 
        text, 
        replyToId: currentReplyToId,
        imageBase64: imageToUpload,
      );
      
      final aiMessage = {
        'id': response['message']?['id'] ?? (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        'text': response['message']?['content'] ?? '...',
        'isUser': false,
        'audioData': response['audioData'],
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
                  return const TypingIndicator();
                }

                final msg = messages[index];
                final isUser = msg['isUser'] as bool;
                final isVoice = msg['isVoice'] == true;
                
                String? repliedText;
                if (msg['replyToId'] != null) {
                  final repliedMsg = messages.cast<Map<String,dynamic>?>().firstWhere(
                    (m) => m?['id'] == msg['replyToId'],
                    orElse: () => null,
                  );
                  if (repliedMsg != null) repliedText = repliedMsg['text'] as String?;
                }
                
                return Dismissible(
                  key: Key(msg['id']),
                  direction: isUser ? DismissDirection.endToStart : DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                    setState(() {
                      replyToMessage = msg;
                    });
                    return false;
                  },
                  background: Container(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.reply, color: AppColors.primary),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : AppColors.surface,
                          border: Border.all(
                            color: isUser ? AppColors.primary : AppColors.glassBorder,
                          ),
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
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(left: BorderSide(color: AppColors.textMuted, width: 3)),
                                ),
                                child: Text(
                                  repliedText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isUser ? AppColors.background.withValues(alpha: 0.8) : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (msg['imageUri'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildImage(msg['imageUri']),
                                ),
                              ),
                            if (isVoice)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mic, color: Colors.black87, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Voice note',
                                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            else if (msg['text'] != null && (msg['text'] as String).isNotEmpty)
                              Text(
                                msg['text'],
                                style: TextStyle(
                                  color: isUser ? AppColors.background : AppColors.text,
                                  fontSize: 15,
                                  height: 1.4,
                                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w300,
                                ),
                              ),

                            // Audio Playback button on Mira's messages
                            if (!isUser && msg['text'] != null && (msg['text'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: InkWell(
                                  onTap: () => _playVoice(msg['id'], msg['audioData'], msg['text']),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.glassBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _currentlyPlayingId == msg['id']
                                              ? Icons.pause_circle_filled
                                              : Icons.volume_up_rounded,
                                          color: AppColors.primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentlyPlayingId == msg['id'] ? 'Playing...' : 'Listen',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedImageUri != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(selectedImageUri!), width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.white, size: 24),
                              onPressed: () => setState(() {
                                selectedImageUri = null;
                                selectedImageBase64 = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Recording ${_formatDuration(_recordSeconds)}',
                            style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _cancelRecording,
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _stopAndSendRecording,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send, color: AppColors.background, size: 18),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                          onPressed: _pickImage,
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
                        if (_textController.text.trim().isEmpty && selectedImageBase64 == null)
                          GestureDetector(
                            onTap: _startRecording,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                              ),
                              child: const Icon(Icons.mic, color: AppColors.primary, size: 20),
                            ),
                          )
                        else
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
