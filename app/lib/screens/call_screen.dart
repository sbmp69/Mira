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

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  Timer? _callTimer;
  int _callSeconds = 0;
  bool _isConnected = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallActive = true;

  String _statusText = 'Connecting...';
  String _lastMiraText = '';

  // VAD & Live Amplitude variables
  StreamSubscription? _amplitudeSub;
  Timer? _silenceTimer;
  bool _speechDetected = false;
  DateTime? _speechStartTime;
  double _micAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initiateCall();
  }

  @override
  void dispose() {
    _isCallActive = false;
    _pulseController.dispose();
    _waveController.dispose();
    _callTimer?.cancel();
    _silenceTimer?.cancel();
    _amplitudeSub?.cancel();
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
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || !_isCallActive) return;

    setState(() {
      _isConnected = true;
      _statusText = 'Connected';
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isCallActive) {
        setState(() => _callSeconds++);
      }
    });

    // Mira greets first upon answering
    await _miraGreeting();
  }

  Future<void> _miraGreeting() async {
    if (!mounted || !_isCallActive) return;
    setState(() {
      _isThinking = true;
      _isListening = false;
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

      if (!mounted || !_isCallActive) return;

      final replyText = res['message']?['content'] ?? 'Hello! So good to hear from you.';
      final audioData = res['audioData'];

      setState(() {
        _isThinking = false;
        _isSpeaking = true;
        _lastMiraText = replyText;
        _statusText = 'Mira is speaking...';
      });

      if (audioData != null) {
        await AudioService.playAudioAndWait(audioData);
      } else {
        await Future.delayed(const Duration(seconds: 3));
      }

      // Automatically transition to live listening as soon as Mira finishes speaking!
      if (mounted && _isCallActive) {
        setState(() => _isSpeaking = false);
        if (!_isMuted) {
          _startLiveListening();
        } else {
          setState(() => _statusText = 'Microphone Muted');
        }
      }
    } catch (e) {
      debugPrint('Error during Mira greeting: $e');
      if (mounted && _isCallActive) {
        setState(() {
          _isThinking = false;
          _isSpeaking = false;
        });
        if (!_isMuted) {
          _startLiveListening();
        }
      }
    }
  }

  /// Automatically listens to user speech continuously (hands-free live call)
  Future<void> _startLiveListening() async {
    if (!_isCallActive || !mounted || _isMuted) return;

    final hasPerm = await AudioService.requestPermission();
    if (!hasPerm) {
      if (mounted) setState(() => _statusText = 'Microphone permission required');
      return;
    }

    final ok = await AudioService.startRecording();
    if (!ok || !_isCallActive || !mounted) return;

    setState(() {
      _isListening = true;
      _isSpeaking = false;
      _isThinking = false;
      _statusText = 'Listening to you...';
      _micAmplitude = 0.0;
    });

    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    _speechDetected = false;
    _speechStartTime = null;

    // Listen to real-time mic volume for dynamic waveform and Voice Activity Detection
    _amplitudeSub = AudioService.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((amp) {
      if (!_isCallActive || !_isListening || _isMuted) return;

      final currentDb = amp.current; // -160 to 0 dBFS

      if (mounted) {
        // Normalize dB from -60..0 dBFS to 0.0..1.0
        final normalized = ((currentDb + 55) / 55).clamp(0.0, 1.0);
        setState(() => _micAmplitude = normalized);
      }

      // Voice Activity Detection (VAD) threshold
      // Ambient noise is typically below -40 dB; speech is above -34 dB
      if (currentDb > -34.0) {
        _speechDetected = true;
        _speechStartTime ??= DateTime.now();

        // User is actively talking; cancel silence timer
        _silenceTimer?.cancel();
        _silenceTimer = null;
      } else if (_speechDetected) {
        // User was speaking, now paused/silent
        _silenceTimer ??= Timer(const Duration(milliseconds: 1600), () {
          // 1.6s of silence after speaking -> auto-send!
          _onUserFinishedSpeaking();
        });
      }

      // Max continuous speech safety timeout (20s)
      if (_speechStartTime != null && DateTime.now().difference(_speechStartTime!).inSeconds >= 20) {
        _onUserFinishedSpeaking();
      }
    });
  }

  /// Called automatically when user stops speaking
  Future<void> _onUserFinishedSpeaking() async {
    if (!_isListening || !_isCallActive || !mounted) return;

    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();

    setState(() {
      _isListening = false;
      _isThinking = true;
      _statusText = 'Mira is thinking...';
      _micAmplitude = 0.0;
    });

    final audioBase64 = await AudioService.stopRecording();
    if (!_isCallActive || !mounted) return;

    if (audioBase64 == null || !_speechDetected) {
      // Nothing audible recorded, seamlessly continue listening
      _startLiveListening();
      return;
    }

    try {
      final userId = AuthApi.getUserId() ?? 'user';
      final res = await ChatApi.sendMessage(
        userId,
        widget.companionId,
        'Live call message',
        audioBase64: audioBase64,
        wantAudio: true,
      );

      if (!_isCallActive || !mounted) return;

      final replyText = res['message']?['content'] ?? '';
      final audioData = res['audioData'];

      setState(() {
        _isThinking = false;
        _isSpeaking = true;
        _lastMiraText = replyText;
        _statusText = 'Mira is speaking...';
      });

      if (audioData != null) {
        await AudioService.playAudioAndWait(audioData);
      } else {
        await Future.delayed(const Duration(seconds: 3));
      }

      // Immediately loop back to live listening as soon as Mira finishes speaking!
      if (mounted && _isCallActive) {
        setState(() => _isSpeaking = false);
        if (!_isMuted) {
          _startLiveListening();
        } else {
          setState(() => _statusText = 'Microphone Muted');
        }
      }
    } catch (e) {
      debugPrint('Error sending live call message: $e');
      if (mounted && _isCallActive) {
        setState(() {
          _isThinking = false;
          _statusText = 'Reconnecting...';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!_isMuted) _startLiveListening();
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      _amplitudeSub?.cancel();
      _silenceTimer?.cancel();
      AudioService.cancelRecording();
      setState(() {
        _isListening = false;
        _statusText = 'Microphone Muted';
      });
    } else {
      if (!_isSpeaking && !_isThinking) {
        _startLiveListening();
      }
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _endCall() {
    _isCallActive = false;
    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    AudioService.stopAudio();
    AudioService.cancelRecording();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back & Live Call Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 30),
                    onPressed: _endCall,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isConnected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isConnected) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isConnected ? 'LIVE  ${_formatDuration(_callSeconds)}' : 'CONNECTING...',
                          style: TextStyle(
                            color: _isConnected ? AppColors.text : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance back button
                ],
              ),
            ),

            const Spacer(),

            // Center Avatar & Interactive Audio Soundwave Rings
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _waveController]),
              builder: (context, child) {
                // Mira speech pulse
                final miraPulse = _isSpeaking ? _pulseController.value * 28 : 0.0;
                // Live user voice amplitude reaction
                final userPulse = _isListening ? (_micAmplitude * 32.0) : 0.0;
                final totalPulse = miraPulse + userPulse;

                final glowColor = _isSpeaking
                    ? AppColors.primary
                    : (_isListening
                        ? (_micAmplitude > 0.1 ? Colors.greenAccent : AppColors.primary.withValues(alpha: 0.5))
                        : AppColors.primary);

                return Container(
                  width: 175 + totalPulse,
                  height: 175 + totalPulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isSpeaking || (_isListening && _micAmplitude > 0.15))
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.4),
                          blurRadius: 40 + totalPulse,
                          spreadRadius: 8 + totalPulse / 2,
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
                        : (_isListening
                            ? (_micAmplitude > 0.15 ? Colors.greenAccent : AppColors.surfaceLight)
                            : AppColors.surfaceLight),
                    width: 3,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 80,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.person, size: 85, color: AppColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Companion Name
            const Text(
              'M I R A',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 26,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
              ),
            ),

            const SizedBox(height: 14),

            // Dynamic Live Wave Bars & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSpeaking || _isListening) ...[
                  _buildSoundWaveBar(0.6),
                  const SizedBox(width: 4),
                  _buildSoundWaveBar(1.0),
                  const SizedBox(width: 4),
                  _buildSoundWaveBar(0.4),
                  const SizedBox(width: 8),
                ],
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _isListening
                        ? Colors.greenAccent
                        : (_isSpeaking ? AppColors.primary : AppColors.textMuted),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_isSpeaking || _isListening) ...[
                  const SizedBox(width: 8),
                  _buildSoundWaveBar(0.5),
                  const SizedBox(width: 4),
                  _buildSoundWaveBar(0.9),
                  const SizedBox(width: 4),
                  _buildSoundWaveBar(0.3),
                ],
              ],
            ),

            // Real-time Subtitle box when Mira speaks
            if (_lastMiraText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    '"$_lastMiraText"',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            const Spacer(),

            // Bottom Authentic Phone Call Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute Button
                  _buildCallControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    activeColor: Colors.redAccent,
                    onTap: _toggleMute,
                  ),

                  // End Call Button (Prominent Red Phone Button)
                  GestureDetector(
                    onTap: _endCall,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'End Call',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Speaker Button
                  _buildCallControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    isActive: _isSpeakerOn,
                    activeColor: AppColors.primary,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWaveBar(double heightFactor) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final animValue = (_isSpeaking || _isListening)
            ? (0.3 + 0.7 * ((_waveController.value + heightFactor) % 1.0))
            : 0.3;
        final barHeight = 6.0 + 14.0 * animValue * (_isListening ? (_micAmplitude + 0.3) : 1.0);
        return Container(
          width: 3,
          height: barHeight,
          decoration: BoxDecoration(
            color: _isListening ? Colors.greenAccent : AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.15) : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : AppColors.glassBorder,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : AppColors.text,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
