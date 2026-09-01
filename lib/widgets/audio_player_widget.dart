import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A reusable network audio player widget that plays audio from a URL.
/// Used to let both the farmer and engineer play voice notes inside chat bubbles.
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      setState(() => _hasError = false);
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NabaTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NabaTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause button
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NabaTheme.primary,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Progress slider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: NabaTheme.primary,
                    inactiveTrackColor: NabaTheme.primary.withOpacity(0.2),
                    thumbColor: NabaTheme.primary,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds
                        .toDouble()
                        .clamp(1, double.infinity),
                    value: _position.inMilliseconds.toDouble().clamp(
                        0,
                        _duration.inMilliseconds
                            .toDouble()
                            .clamp(1, double.infinity)),
                    onChanged: (v) {
                      _player.seek(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600)),
                      Text(_formatDuration(_duration),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error indicator
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.error_outline, color: Colors.red, size: 18),
            ),
        ],
      ),
    );
  }
}
