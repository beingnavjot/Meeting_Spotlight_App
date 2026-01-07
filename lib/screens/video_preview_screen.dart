import 'dart:convert'; // Required for base64Encode (if using manual data URI)
import 'dart:io' if (dart.library.html) 'dart:html'; // Conditional import to prevent Web crash
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../provider/meeting_provider.dart';

class VideoPreviewScreen extends StatefulWidget {
  // Use 'dynamic' or specific conditional types to avoid "File not found" on Web
  // On Mobile, pass File. On Web, pass null.
  // final dynamic videoFile;
  // final Uint8List webVideoBytes;
  final int startMs;

  const VideoPreviewScreen({
    super.key,
    // required this.videoFile, // Pass 'File' on mobile, 'null' on web
    // required this.webVideoBytes,
    required this.startMs,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
  }

  Future<void> _initializePlayer() async {
    final provider = Provider.of<MeetingProvider>(context, listen: false);
    if (kIsWeb) {
      // WEB: Create a Data URI from the bytes
      // This tricks the browser into thinking the bytes are a network URL
      if (provider.webVideoBytes != null) {
        final String uri = 'data:video/mp4;base64,${base64Encode(provider.webVideoBytes as List<int>)}';
        _controller = VideoPlayerController.networkUrl(Uri.parse(uri));
      } else {
        return; // Handle error: no bytes provided for web
      }
    } else {
      // 📱 MOBILE: Use the standard File object
      // We cast to File here because 'dynamic' hides the type check
      _controller = VideoPlayerController.file(provider.videoFile!);
    }

    // Common Initialization Logic
    await _controller.initialize();

    if (mounted) {
      setState(() => _initialized = true);
      // THE JUMP: Seek to Gemini's calculated time
      await _controller.seekTo(Duration(milliseconds: widget.startMs));
      await _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Spotlight Preview"),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    // Floating Play/Pause
                    Center(
                      child: IconButton(
                        iconSize: 64,
                        color: Colors.white.withOpacity(0.5),
                        icon: Icon(_controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
