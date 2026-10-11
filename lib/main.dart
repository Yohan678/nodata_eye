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
  String _lastDetectedText = "";

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
      const Duration(seconds: 3),
      (timer) {
        _captureAndAnalyze();
      },
    );
  }

  void _handleBatterySaverToggle(bool value) {
    setState(() {
      _batterySaverEnabled = value;
      // 상태 텍스트(_statusText)는 덮어쓰지 않고 유지하여, 자막이 계속 보이도록 합니다.
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
        final jsonResponse =
            jsonDecode(utf8.decode(cvResponse.bodyBytes));
        analysisText = jsonResponse['text'];
      }

      if (!mounted) return;

      setState(() {
        _statusText = analysisText;
      });

      if (analysisText != _lastDetectedText &&
          analysisText != "Cannot identify risk factors.") {
        _lastDetectedText = analysisText;

        HapticFeedback.heavyImpact();
        print("🚨 [New Warning Detected] Playing TTS: $analysisText");

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
          await _audioPlayer.play(
            BytesSource(ttsResponse.bodyBytes),
          );
        } else {
          print("ElevenLabs 오류: ${ttsResponse.statusCode}");
        }
      } else if (analysisText == "Cannot identify risk factors.") {
        _lastDetectedText = "Cannot identify risk factors.";
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
                  // 1. 카메라 화면 (항상 맨 밑바닥에 렌더링되게 유지)
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

                  // 2. 배터리 세이버용 검은색 덮개 (스위치를 켰을 때만 카메라 위를 덮음)
                  if (_batterySaverEnabled)
                    Positioned.fill(
                      child: Container(color: Colors.black),
                    ),

                  // 3. 배터리 세이버 모드 중앙 안내 텍스트
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

                  // 4. 하단 자막 텍스트 (모드 상관없이 항상 표시)
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

                  // 5. 로딩 인디케이터 (카메라 뷰 상태일때만 우측 상단 표시)
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

                  // 6. 토글 위젯 (항상 최상단에 띄움)
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