import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nodata_eye_web/toggle_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const NoDataEyeApp());
}

class NoDataEyeApp extends StatelessWidget {
  const NoDataEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'No-Data Eye (Auto Mode)',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const WebCameraScreen(),
    );
  }
}

class WebCameraScreen extends StatefulWidget {
  const WebCameraScreen({super.key});

  @override
  State<WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<WebCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _batterySaverEnabled = false;
  String _statusText = "Initializing camera...";

  Timer? _scanTimer;
  String _lastSpokenText = ""; // 마지막으로 처리된 텍스트

  // API Key from .env
  final String elevenLabsApiKey =
      dotenv.env['elevenLabsAPIKEY'] ?? '';

  static const String voiceId = 'ZoiZ8fuDWInAcwPXaVeq';

  final Uri cvUrl = Uri.parse('http://127.0.0.1:8000/detect');

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isNotEmpty) {
        CameraDescription selectedCamera = _cameras.first;

        for (var camera in _cameras) {
          if (camera.lensDirection == CameraLensDirection.back) {
            selectedCamera = camera;
            break;
          }
        }

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();

        if (!mounted) return;

        setState(() {
          _isInitialized = true;
          _statusText = "Starting auto scan...";
        });

        _startAutoScan();
      } else {
        setState(() {
          _statusText = "No available cameras.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Please allow camera permissions.";
      });
    }
  }

  void _startAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _captureAndAnalyze();
      },
    );
  }

  void _handleBatterySaverToggle(bool value) {
    setState(() {
      _batterySaverEnabled = value;
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing || !_isInitialized || _controller == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      XFile picture = await _controller!.takePicture();
      Uint8List imageBytes = await picture.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final cvResponse = await http.post(
        cvUrl,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({"image_base64": base64Image}),
      );

      String analysisText = "Cannot identify risk factors.";

      if (cvResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(cvResponse.bodyBytes));
        analysisText = jsonResponse['text'];
      }

      if (!mounted) return;

      setState(() {
        _statusText = analysisText;
      });

      // 감지된 내용이 있고, 방금 전과 다른 새로운 위험일 때
      if (analysisText != "Cannot identify risk factors." &&
          analysisText != _lastSpokenText) {
        
        // API 중복 호출을 막기 위해 텍스트를 즉시 갱신
        _lastSpokenText = analysisText;

        HapticFeedback.heavyImpact();
        print("🚨 [New Warning Detected] Fetching TTS: $analysisText");

        final ttsUrl = Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
        );

        final ttsResponse = await http.post(
          ttsUrl,
          headers: {
            'Accept': 'audio/mpeg',
            'xi-api-key': elevenLabsApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "text": analysisText,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {
              "stability": 0.5,
              "similarity_boost": 0.7,
            },
          }),
        );

        if (ttsResponse.statusCode == 200) {
          // 새로운 음성이 준비되면 재생 중이던 옛날 알림을 즉각 차단하고 새 알림을 켭니다.
          await _audioPlayer.stop();
          await _audioPlayer.play(
            BytesSource(ttsResponse.bodyBytes),
          );
        } else {
          print("ElevenLabs 오류: ${ttsResponse.statusCode}");
        }
      } else if (analysisText == "Cannot identify risk factors.") {
        _lastSpokenText = "Cannot identify risk factors.";
      }
    } catch (e) {
      print("🚨 분석 에러: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_isInitialized
            ? Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                  if (_batterySaverEnabled)
                    Positioned.fill(
                      child: Container(color: Colors.black),
                    ),
                  if (_batterySaverEnabled)
                    const Center(
                      child: Text(
                        'Battery Saver Mode',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 50,
                        bottom: 40,
                        left: 20,
                        right: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black87,
                            Colors.black,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (_isProcessing && !_batterySaverEnabled)
                    const Positioned(
                      top: 92,
                      right: 22,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: ToggleWidget(
                        label: 'Battery Save',
                        value: _batterySaverEnabled,
                        onChanged: _handleBatterySaverToggle,
                        activeColor: Colors.greenAccent,
                        activeTrackColor: const Color(0xFFB9F6CA),
                        inactiveTrackColor: const Color(0xFF3A3A3C),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}