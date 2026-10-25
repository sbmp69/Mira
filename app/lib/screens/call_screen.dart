import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../services/api.dart';
import '../services/audio_service.dart';

class CallScreen extends StatefulWidget {
  final String companionId;

  const CallScreen({super.key, required this.companionId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _callTimer;
  int _callSeconds = 0;
  bool _isConnected = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isMuted = false;
  String _statusText = 'Connecting...';
  String _lastMiraText = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initiateCall();
  }

  @override
  void dispose() {
    _animController.dispose();
    _callTimer?.cancel();
    AudioService.stopAudio();
    AudioService.cancelRecording();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initiateCall() async {
    // Wait briefly for connection feel
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() {
      _isConnected = true;
      _statusText = 'Connected';
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callSeconds++);
    });

    // Mira speaks first upon answering
    await _miraGreeting();
  }

  Future<void> _miraGreeting() async {
    if (!mounted) return;
    setState(() {
      _isThinking = true;
      _statusText = 'Mira is connecting...';
    });

    try {
      final userId = AuthApi.getUserId() ?? 'user';
      final res = await ChatApi.sendMessage(
        userId,
        widget.companionId,
        'Hi Mira! I just called you, say hello to me!',
        wantAudio: true,
      );

      final replyText = res['message']?['content'] ?? 'Hello! So good to hear from you.';
      final audioData = res['audioData'];

      if (mounted) {
        setState(() {
          _isThinking = false;
          _isSpeaking = true;
          _lastMiraText = replyText;
          _statusText = 'Mira is speaking...';
        });

        if (audioData != null) {
          await AudioService.playAudio(audioData);
        } else {
          await Future.delayed(const Duration(seconds: 3));
        }

        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _statusText = 'Tap mic to talk';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _statusText = 'Tap mic to talk';
        });
      }
    }
  }

  Future<void> _startTalking() async {
    if (_isThinking || _isSpeaking) {
      await AudioService.stopAudio();
    }

    final ok = await AudioService.startRecording();
    if (ok && mounted) {
      setState(() {
        _isListening = true;
        _statusText = 'Listening to you...';
      });
    }
  }

  Future<void> _stopTalkingAndSend() async {
    if (!_isListening) return;
    setState(() {
      _isListening = false;
      _isThinking = true;
      _statusText = 'Thinking...';
    });

    final audioBase64 = await AudioService.stopRecording();
    if (audioBase64 == null) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _statusText = 'Tap mic to talk';
        });
      }
      return;
    }

    try {
      final userId = AuthApi.getUserId() ?? 'user';
      final res = await ChatApi.sendMessage(
        userId,
        widget.companionId,
        'Voice call message',
        audioBase64: audioBase64,
        wantAudio: true,
      );

      final replyText = res['message']?['content'] ?? '';
      final audioData = res['audioData'];

      if (mounted) {
        setState(() {
          _isThinking = false;
          _isSpeaking = true;
          _lastMiraText = replyText;
          _statusText = 'Mira is speaking...';
        });

        if (audioData != null) {
          await AudioService.playAudio(audioData);
        } else {
          await Future.delayed(const Duration(seconds: 3));
        }

        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _statusText = 'Tap mic to talk';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _statusText = 'Could not hear clearly, tap to try again';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 30),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      _isConnected ? _formatDuration(_callSeconds) : 'Connecting',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance back button
                ],
              ),
            ),

            const Spacer(),

            // Avatar & Pulse
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final pulse = (_isSpeaking || _isListening) ? _animController.value * 20 : 0.0;
                return Container(
                  width: 170 + pulse,
                  height: 170 + pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isSpeaking)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 35 + pulse,
                          spreadRadius: 8 + pulse / 2,
                        )
                      else if (_isListening)
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 35 + pulse,
                          spreadRadius: 8 + pulse / 2,
                        ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSpeaking
                        ? AppColors.primary
                        : (_isListening ? Colors.green : AppColors.surfaceLight),
                    width: 3,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 80,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.person, size: 80, color: AppColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Companion Name
            const Text(
              'M I R A',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w400,
                letterSpacing: 6,
              ),
            ),

            const SizedBox(height: 12),

            // Status message
            Text(
              _statusText,
              style: TextStyle(
                color: _isListening
                    ? Colors.greenAccent
                    : (_isSpeaking ? AppColors.primary : AppColors.textMuted),
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),

            // Subtitle caption if Mira is speaking
            if (_lastMiraText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  '"$_lastMiraText"',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const Spacer(),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  IconButton(
                    iconSize: 32,
                    icon: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic_none,
                      color: _isMuted ? Colors.red : AppColors.text,
                    ),
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),

                  // Push-to-Talk / Hold to Speak Button
                  GestureDetector(
                    onTapDown: (_) => _startTalking(),
                    onTapUp: (_) => _stopTalkingAndSend(),
                    onTapCancel: () => AudioService.cancelRecording(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.green : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.green : AppColors.primary).withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: AppColors.background,
                        size: 36,
                      ),
                    ),
                  ),

                  // End Call Button
                  GestureDetector(
                    onTap: () {
                      AudioService.stopAudio();
                      AudioService.cancelRecording();
                      context.pop();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
