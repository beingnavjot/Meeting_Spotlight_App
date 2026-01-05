import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/spotlight_result.dart';

// ⚠️ REPLACE WITH YOUR ACTUAL API KEY
const String _apiKey = 'AIzaSyDsoWOB16LNMULHiT6i8yl3LAR55atFsz0';

class MeetingProvider extends ChangeNotifier {
  File? videoFile;
  String? videoName;
  bool isUploading = false;
  bool isAnalyzing = false;
  bool isRecording = false;

  SpotlightResult? result;
  String? error;

  late final GenerativeModel _model;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedAudioPath;

  MeetingProvider() {
    //   _model = GenerativeModel(
    //     // Using 'gemini-1.5-pro' as the current proxy for Gemini 3 features
    //     // In your 2026 context, you would use 'gemini-3-pro'
    //     model: 'gemini-1.5-pro',
    //     apiKey: _apiKey,
    //     generationConfig: GenerationConfig(responseMimeType: 'application/json', temperature: 0.2),
    //   );
    // }

    _model = GenerativeModel(
      //   model: 'gemini-3-pro',
      //   model: 'gemini-3-pro-preview',
      model: 'gemini-3-flash-preview',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.7,
        // temperature: 1.0,
        //   thinkingLevel: ThinkingLevel.high, // Requires gemini-3-pro-preview
      ),
    );
  }

  // --- 1. PICK VIDEO ---
  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      videoFile = File(result.files.single.path!);
      videoName = result.files.single.name;
      this.result = null; // Reset previous results
      error = null;
      notifyListeners();
    }
  }

  // --- 2. RECORD AUDIO QUERY ---
  Future<void> toggleRecording() async {
    if (isRecording) {
      final path = await _audioRecorder.stop();
      _recordedAudioPath = path;
      isRecording = false;
      notifyListeners();
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/query_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        isRecording = true;
        notifyListeners();
      }
    }
  }

  // --- 3. UPLOAD TO GEMINI FILE API (Raw HTTP for Large Files) ---
  Future<String?> _uploadLargeFile(File file) async {
    isUploading = true;
    notifyListeners();

    try {
      final int fileSize = await file.length();
      final Uri uri = Uri.parse('https://generativelanguage.googleapis.com/upload/v1beta/files?key=$_apiKey');

      // Start Resumable Upload
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': fileSize.toString(),
        'X-Goog-Upload-Header-Content-Type': 'video/mp4',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'file': {'display_name': videoName ?? 'meeting_video'},
      });

      final response = await request.send();
      print("Handshake Status: ${response.statusCode}"); // Add this!

      final uploadUrl = response.headers['x-goog-upload-url'];
      if (uploadUrl == null) {
        // Add this to see the error message from Google
        final errorBody = await response.stream.bytesToString();
        print("Google Error: $errorBody");
        throw Exception("Failed to initiate upload. Status: ${response.statusCode}");
      }

      // Upload Bytes
      final uploadReq = http.Request('POST', Uri.parse(uploadUrl));
      uploadReq.headers.addAll({'Content-Length': fileSize.toString(), 'X-Goog-Upload-Offset': '0', 'X-Goog-Upload-Command': 'upload, finalize'});
      uploadReq.bodyBytes = await file.readAsBytes();

      final uploadRes = await uploadReq.send();
      final body = await uploadRes.stream.bytesToString();
      final json = jsonDecode(body);

      return json['file']['uri']; // The "File URI" used for prompting
    } catch (e) {
      print("Upload Failed: $e");
      error = "Upload Failed: $e";
      return null;
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Future<void> analyzeVideo({String? textQuery}) async {
    if (videoFile == null) return;

    isAnalyzing = true;
    error = null;
    result = null; // Clear old results
    notifyListeners();

    try {
      // 1. UPLOAD: Send the file to Gemini File API
      final String? videoUri = await _uploadLargeFile(videoFile!);
      if (videoUri == null) throw Exception("Video upload failed.");

      // 2. POLL: Wait for the file to move from 'PROCESSING' to 'ACTIVE'
      final String fileId = videoUri.split('/').last;
      bool isReady = false;

      // Safety counter to avoid infinite loops
      int retryCount = 0;
      while (!isReady && retryCount < 20) {
        final statusResp = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/files/$fileId?key=$_apiKey'));

        if (statusResp.statusCode == 200) {
          final statusData = jsonDecode(statusResp.body);
          final String state = statusData['state'] ?? 'PROCESSING';

          if (state == 'ACTIVE') {
            isReady = true;
          } else if (state == 'FAILED') {
            throw Exception("Google failed to process this video.");
          } else {
            // Wait 3 seconds before checking again
            await Future.delayed(const Duration(seconds: 3));
            retryCount++;
          }
        }
      }

      if (!isReady) throw Exception("Video processing timed out. Try a shorter clip.");

      // 3. PROMPT: Send the multimodal request
      final List<Part> parts = [];

      // Add the Active Video
      parts.add(FilePart(Uri.parse(videoUri)));

      // Add User Query (Audio file or Text string)
      if (_recordedAudioPath != null) {
        final audioBytes = await File(_recordedAudioPath!).readAsBytes();
        parts.add(DataPart('audio/mp4', audioBytes));
        parts.add(TextPart("Listen to this audio query and find the answer in the video."));
      } else if (textQuery != null && textQuery.isNotEmpty) {
        parts.add(TextPart("Search the video for: $textQuery"));
      }

      // Add Instructions for JSON output
      parts.add(
        TextPart("""
      You are a Video Search Assistant. 
      Find the exact timestamp where the requested topic is discussed.
      Return ONLY a JSON object:
      {
        "start_ms": <int>,
        "end_ms": <int>,
        "summary": "<string>",
        "confidence": <float>
      }
      Important: Buffer the start_ms by -3000 (3 seconds) for context.
    """),
      );

      final response = await _model.generateContent([Content.multi(parts)]);

      // 4. PARSE: Clean the AI response and convert to Object
      if (response.text != null) {
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();

        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        result = SpotlightResult.fromJson(decoded);
      }
    } catch (e) {
      error = "Error: ${e.toString()}";
      print(error);
    } finally {
      isAnalyzing = false;
      _recordedAudioPath = null; // Reset audio for next search
      notifyListeners();
    }
  }
}
