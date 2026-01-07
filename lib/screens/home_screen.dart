import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/meeting_provider.dart';
import '../utils/pulsing_mic_button.dart';
import 'video_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeetingProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text("", style: const TextStyle(color: Colors.white70)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Upload Area
            GestureDetector(
              onTap: provider.pickVideo,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      provider.videoFile != null ? Icons.check_circle : Icons.cloud_upload,
                      size: 40,
                      color: provider.videoFile != null ? Colors.green : Colors.blueAccent,
                    ),
                    const SizedBox(height: 10),
                    Text(provider.videoName ?? "Tap to Upload Meeting Video", style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. Query Inputs
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What are you looking for?",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // --- AUDIO RECORDING SECTION ---

            // Scenario A: Audio IS Recorded -> Show File & Delete Button
            if (provider.recordedAudioPath != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Audio Query Recorded",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            // Extract just the filename from the full path
                            provider.recordedAudioPath!.split('/').last,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => provider.resetRecording(),
                      tooltip: "Remove Recording",
                    ),
                  ],
                ),
              )
            // Scenario B: No Audio -> Show Mic Button (Your existing Pulsing Widget)
            else
              Column(
                children: [
                  Center(
                    child: PulsingMicButton(
                      isRecording: provider.isRecording,
                      onLongPress: provider.toggleRecording,
                      onLongPressUp: provider.toggleRecording,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text("Hold to Speak", style: TextStyle(color: Colors.grey)),
                ],
              ),

            //// ---------------------------------------------
            const SizedBox(height: 30),

            // 3. Action Button
            // 3. Action Button
            ElevatedButton(
              onPressed: (provider.isAnalyzing || provider.isUploading) ? null : () => provider.analyzeVideo(textQuery: _textController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                // Make button disabled look better
                disabledBackgroundColor: const Color(0xFF4285F4).withOpacity(0.6),
                disabledForegroundColor: Colors.white,
              ),
              child: provider.isAnalyzing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Small Spinner
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        // Dynamic Text
                        Text(provider.loadingMessage, style: const TextStyle(fontSize: 16, color: Colors.white)),
                      ],
                    )
                  : const Text("Spotlight Topic", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),

            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(provider.error!, style: const TextStyle(color: Colors.redAccent)),
              ),

            // 4. Result Card
            if (provider.result != null)
              Container(
                margin: const EdgeInsets.only(top: 30),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF9C27B0)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      "Found: ${provider.result!.summary}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text("Preview Segment"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPreviewScreen(
                              // videoFile: provider.videoFile!,
                              // webVideoBytes: provider.webVideoBytes!,
                              startMs: provider.result!.startMs,
                            ),
                          ),
                        );
                      },
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
