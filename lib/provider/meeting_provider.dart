import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/spotlight_result.dart';

// REPLACE WITH API KEY
const String _apiKey = 'AIzaSyDsoWOB16LNMULHiT6i8yl3LAR55atFsz0';

class MeetingProvider extends ChangeNotifier {
  File? videoFile;
  String? videoName;
  bool isUploading = false;
  bool isAnalyzing = false;
  bool isRecording = false;
  Uint8List? webVideoBytes;

  SpotlightResult? result;
  String? error;

  late final GenerativeModel _model;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedAudioPath;
  String loadingMessage = "";

  String? get recordedAudioPath => _recordedAudioPath;

  void resetRecording() {
    _recordedAudioPath = null;
    notifyListeners();
  }

  void _setStatus(String message) {
    loadingMessage = message;
    notifyListeners();
  }

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
      model: 'gemini-1.5-flash',
      //   model: 'gemini-3-flash-preview',
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true, // Necessary for Web to load bytes into memory
    );

    if (result != null) {
      videoName = result.files.first.name;

      if (kIsWeb) {
        webVideoBytes = result?.files.first.bytes ?? null;
        print('webVideoBytes');
        print("lengthInBytes ${webVideoBytes?.lengthInBytes}");
      } else {
        videoFile = File(result.files.first.path!);
      }
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

  Future<String?> _uploadLargeFile({File? file, Uint8List? webBytes}) async {
    isUploading = true;
    notifyListeners();

    try {
      // 1. Determine size and name based on platform
      final int fileSize = kIsWeb ? webBytes!.length : await file!.length();
      final String fileName = videoName ?? "meeting_video.mp4";
      final String mimeType = "video/mp4";

      final Uri handshakeUri = Uri.parse('https://generativelanguage.googleapis.com/upload/v1beta/files?key=$_apiKey');

      // STEP 1: INITIAL HANDSHAKE
      // We send metadata first to get a unique upload URL
      final handshakeResponse = await http.post(
        handshakeUri,
        headers: {
          'X-Goog-Upload-Protocol': 'resumable',
          'X-Goog-Upload-Command': 'start',
          'X-Goog-Upload-Header-Content-Length': fileSize.toString(),
          'X-Goog-Upload-Header-Content-Type': mimeType,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'file': {'display_name': fileName},
        }),
      );

      final String? uploadUrl = handshakeResponse.headers['x-goog-upload-url'];
      if (uploadUrl == null) {
        throw Exception("Handshake failed. Status: ${handshakeResponse.statusCode}");
      }

      // STEP 2: ACTUAL DATA UPLOAD
      // We send the raw bytes to the URL provided in Step 1
      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {'Content-Length': fileSize.toString(), 'X-Goog-Upload-Offset': '0', 'X-Goog-Upload-Command': 'upload, finalize'},
        // If Web, use webBytes. If Mobile, read the file as bytes.
        body: kIsWeb ? webBytes : await file!.readAsBytes(),
      );

      if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201) {
        final jsonResponse = jsonDecode(uploadResponse.body);
        final String fileUri = jsonResponse['file']['uri'];
        print("Upload successful! File URI: $fileUri");
        return fileUri;
      } else {
        throw Exception("Upload failed with status: ${uploadResponse.statusCode}");
      }
    } catch (e) {
      error = "Upload Error: $e";
      print(error);
      return null;
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Future<String?> _uploadLargeFile2(File file) async {
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
    if (videoFile == null && webVideoBytes == null) return;

    isAnalyzing = true;
    error = null;
    result = null;
    _setStatus("Preparing video..."); // Start message
    // notifyListeners();

    try {
      String? uploadUri;
      bool isAudioOnly = false;

      // 1. SMART SWITCH: Check File Size (Mobile Only)
      if (!kIsWeb && videoFile != null) {
        final int sizeBytes = await videoFile!.length();
        final double sizeMB = sizeBytes / (1024 * 1024);

        _setStatus("Compressing file (10x faster)..."); // Update message
        print("File is ${sizeMB.toStringAsFixed(1)}MB. Switching to Audio-Only Mode...");

        // A. Extract Audio
        final File? audioFile = await _extractAudioAndCompress(videoFile!);

        if (audioFile != null) {
          isAudioOnly = true;
          // B. Upload the small Audio file
          _setStatus("Uploading optimized file..."); // Update message
          uploadUri = await _uploadLargeFile(file: audioFile);
        } else {
          print("Audio extraction failed. Fallback to full video upload.");
          uploadUri = await _uploadLargeFile(file: videoFile);
        }
      }
      // Web or Small Files
      else {
        uploadUri = await _uploadLargeFile(file: videoFile, webBytes: webVideoBytes);
      }

      if (uploadUri == null) throw Exception("Upload failed.");

      // 2. POLL STATUS (Keep existing logic)
      _setStatus("Processing file on Google AI..."); // Update message
      await _waitForActiveState(uploadUri); // Extracted polling to helper for cleanliness

      _setStatus("AI is watching the meeting..."); // Update message
      // 3. PROMPT GENERATION
      final List<Part> parts = [];

      // Tell Gemini what it is looking at
      if (isAudioOnly) {
        // We upload it as audio/mp3, but Gemini treats it as a file part
        parts.add(FilePart(Uri.parse(uploadUri)));
        parts.add(TextPart("This is the extracted audio track of a meeting video."));
      } else {
        parts.add(FilePart(Uri.parse(uploadUri)));
      }

      if (textQuery != null) parts.add(TextPart("Search for: $textQuery"));

      parts.add(
        TextPart("""
        Find the exact timestamp where the topic is discussed.
        Even though this might be audio-only, treat timestamps as valid for the original video.
        Return ONLY JSON:
        { "start_ms": <int>, "end_ms": <int>, "summary": "<string>", "confidence": <float> }
        Buffer start_ms by -500ms.
      """),
      );

      final response = await _model.generateContent([Content.multi(parts)]);

      // 4. PARSE (Keep existing logic)
      if (response.text != null) {
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        result = SpotlightResult.fromJson(jsonDecode(cleanJson));
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isAnalyzing = false;
      loadingMessage = ""; // Clear message when done
      notifyListeners();
    }
  }

  // 🛠️ HELPER: Extract Audio from Video File
  // Also compress the audio file
  Future<File?> _extractAudioAndCompress(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // We use .mp3 with specific low-quality settings
      final String audioPath = "${tempDir.path}/temp_compressed_${DateTime.now().millisecondsSinceEpoch}.mp3";

      print("Starting Aggressive Compression...");

      // FFmpeg Command Explained:
      // -y          : Overwrite output if exists
      // -i "..."    : Input file
      // -vn         : No Video (Audio only)
      // -ac 1       : Audio Channels = 1 (Mono) -> Cuts size in half!
      // -ar 16000   : Audio Rate = 16kHz (Human voice range) -> Cuts size significantly
      // -b:a 32k    : Bitrate = 32kbps (Low quality but readable by AI)

      final command = "-y -i \"${videoFile.path}\" -vn -ac 1 -ar 16000 -b:a 32k \"$audioPath\"";

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final File file = File(audioPath);
        final int size = await file.length();
        print("Compression Success! Output size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB");
        return file;
      } else {
        final logs = await session.getAllLogsAsString();
        print("FFmpeg Failed. Logs:\n$logs");
        return null;
      }
    } catch (e) {
      print("Extraction Exception: $e");
      return null;
    }
  }

  // 🛠️ HELPER: Extract Audio from Video File
  Future<File?> _extractAudio(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Use .aac which is faster/safer than mp3 for generic extraction
      final String audioPath = "${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.aac";

      print("Attempting extraction...");
      print("Input: ${videoFile.path}");

      // 1. FIX: Wrap paths in quotes (\"path\") to handle spaces
      // 2. CHANGE: Use 'aac' codec (built-in to almost all ffmpeg versions)
      final command = "-y -i \"${videoFile.path}\" -vn -acodec copy \"$audioPath\"";

      // If 'copy' fails (incompatible codecs), fallback to re-encoding:
      // final command = "-y -i \"${videoFile.path}\" -vn -acodec aac \"$audioPath\"";

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print("Audio extraction successful!");
        return File(audioPath);
      } else {
        // 3. DEBUGGING: Print the ACTUAL error from FFmpeg
        final logs = await session.getAllLogsAsString();
        print("FFmpeg Failed. Logs:\n$logs");

        // Return null to trigger the fallback to full video upload
        return null;
      }
    } catch (e) {
      print("Extraction Exception: $e");
      return null;
    }
  }

  // Helper for Polling (Refactored from your previous code)
  Future<void> _waitForActiveState(String uri) async {
    final String fileId = uri.split('/').last;
    bool isReady = false;
    int retryCount = 0;
    while (!isReady && retryCount < 30) {
      // Increased retries for safety
      final resp = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/files/$fileId?key=$_apiKey'));
      if (resp.statusCode == 200) {
        final state = jsonDecode(resp.body)['state'];
        if (state == 'ACTIVE') return;
        if (state == 'FAILED') throw Exception("File processing failed.");
      }
      await Future.delayed(const Duration(seconds: 2));
      retryCount++;
    }
    throw Exception("Processing timed out.");
  }
}
