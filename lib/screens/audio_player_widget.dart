import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String source;
  final VoidCallback? onDelete;
  final bool isDelete;
  final String duration;
  final dynamic addVisitViewModel;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
    this.onDelete,
    required this.isDelete,
    required this.duration,
    this.addVisitViewModel,
  }) : super(key: key);

  @override
  AudioPlayerWidgetState createState() => AudioPlayerWidgetState();
}

class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  static const double _controlSize = 56;
  static const double _deleteBtnSize = 24;
  final _audioPlayer = AudioPlayer();
  String? _localFilePath;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.source.startsWith('http') ||
          widget.source.startsWith('https')) {
        final response = await http.get(
          Uri.parse(widget.source),
          headers: {'Cookie': 'sid=${widget.addVisitViewModel?.sid ?? ''}'},
        );

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          setState(() => _localFilePath = tempFile.path);
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      } else {
        final file = File(widget.source);
        if (await file.exists()) {
          setState(() => _localFilePath = widget.source);
        } else {
          throw Exception('Local audio file not found: ${widget.source}');
        }
      }

      await _audioPlayer.setFilePath(_localFilePath!);
      setState(() => _isLoading = false);
    } catch (e) {
      print("Error loading audio source: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading audio: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_localFilePath != null &&
        (widget.source.startsWith('http') ||
            widget.source.startsWith('https'))) {
      File(
        _localFilePath!,
      ).delete().catchError((e) => print('Error deleting temp audio file: $e'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audio Unavailable',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = false;
                        _localFilePath = null;
                      });
                      _init();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              )
            : Row(
                children: [
                  StreamBuilder<PlayerState>(
                    stream: _audioPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final processingState = playerState?.processingState;
                      final playing = playerState?.playing;
                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        );
                      } else if (playing != true) {
                        return IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).colorScheme.primary,
                            size: 30,
                          ),
                          onPressed: _audioPlayer.play,
                        );
                      } else if (processingState != ProcessingState.completed) {
                        return IconButton(
                          icon: const Icon(
                            Icons.pause,
                            color: Colors.red,
                            size: 26,
                          ),
                          onPressed: _audioPlayer.pause,
                        );
                      } else {
                        return IconButton(
                          icon: Icon(
                            Icons.restart_alt,
                            color: Theme.of(context).colorScheme.primary,
                            size: 26,
                          ),
                          onPressed: () {
                            _audioPlayer.seek(Duration.zero);
                            _audioPlayer.play();
                          },
                        );
                      }
                    },
                  ),
                  Flexible(
                    child: StreamBuilder<Duration?>(
                      stream: _audioPlayer.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration>(
                          stream: _audioPlayer.positionStream,
                          builder: (context, snapshot) {
                            var position = snapshot.data ?? Duration.zero;
                            if (position > duration) position = duration;
                            return SeekBar(
                              duration: duration,
                              position: position,
                              onChangeEnd: (newPosition) =>
                                  _audioPlayer.seek(newPosition),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.red, size: 30),
                    onPressed: () {
                      _audioPlayer.stop();
                      _audioPlayer.seek(Duration.zero);
                    },
                  ),
                  if (widget.isDelete && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.grey,
                        size: _deleteBtnSize,
                      ),
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
      ),
    );
  }
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration>? onChangeEnd;

  const SeekBar({
    Key? key,
    required this.duration,
    required this.position,
    this.onChangeEnd,
  }) : super(key: key);

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Slider(
          min: 0.0,
          max: widget.duration.inSeconds.toDouble() > 0
              ? widget.duration.inSeconds.toDouble()
              : 1.0,
          value: _dragValue ?? widget.position.inSeconds.toDouble(),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          onChanged: (value) => setState(() => _dragValue = value),
          onChangeEnd: (value) {
            if (widget.onChangeEnd != null)
              widget.onChangeEnd!(Duration(seconds: value.round()));
            setState(() => _dragValue = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(widget.duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
