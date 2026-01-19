part of 'main.dart';

enum _Stage { initializing, expired, completed }

class LiveDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceAntiSpoofingDetector spoofingDetector;
  final FaceDetectionService detection;

  const LiveDetectionScreen({
    required this.camera,
    required this.detection,
    required this.recognition,
    required this.spoofingDetector,
    super.key,
  });

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  static const _durationInSeconds = 30;

  _Stage _stage = _Stage.initializing;
  late final ValueNotifier<int> _timerNotifier =
      ValueNotifier(_durationInSeconds);
  Timer? _timer;
  Uint8List? _capturedImage;
  String _resultText = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timerNotifier.value = _durationInSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerNotifier.value > 0) {
        _timerNotifier.value--;
      } else {
        setState(() => _stage = _Stage.expired);
        timer.cancel();
      }
    });
  }

  void _restartDetection() {
    setState(() {
      _stage = _Stage.initializing;
      _capturedImage = null;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartDetection,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.initializing:
        return _buildDetectionWidget();
      case _Stage.expired:
        return _buildExpiredScreen();
      case _Stage.completed:
        return _buildCompletedScreen();
    }
  }

  Widget _buildCompletedScreen() {
    return Center(
      child: Stack(
        children: [
          if (_capturedImage != null)
            Image.memory(_capturedImage!, fit: BoxFit.cover),
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(),
                Parent(
                  style: ParentStyle()
                    ..background.color(Colors.black.withOpacity(0.6))
                    ..borderRadius(all: 10)
                    ..padding(all: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Detection Completed',
                        style: TextStyle(fontSize: 24, color: Colors.green),
                      ),
                      Text(
                        _resultText,
                        style: TextStyle(fontSize: 8, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Txt(
            'Time Expired',
            style: TxtStyle()
              ..fontSize(24)
              ..textColor(Colors.red),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _restartDetection,
            child: const Text('Restart Detection'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionWidget() {
    return _LiveDetectionWidget(
      camera: widget.camera,
      detection: widget.detection,
      recognition: widget.recognition,
      timerNotifier: _timerNotifier,
      onDone: (img) async {
        if (img != null) {
          final liveDetection = await Future.wait([
            widget.recognition.recognize(img),
            widget.spoofingDetector.detect(img),
          ]);

          for (var result in liveDetection) {
            if (result is Map<String, dynamic>) {
              _resultText += '$result\n';

              print('--=> Recognition Result: $result');
              continue;
            }
          }
          print('--=> ================================');
          _resultText += '========================================\n';
        }

        setState(() {
          _timer?.cancel();
          _capturedImage = img;
          _stage = _Stage.completed;
        });
      },
    );
  }
}

class _LiveDetectionWidget extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceDetectionService detection;
  final ValueNotifier<int> timerNotifier;
  final Function(Uint8List? img)? onDone;

  const _LiveDetectionWidget({
    required this.camera,
    required this.detection,
    required this.recognition,
    required this.timerNotifier,
    this.onDone,
  });

  @override
  State<_LiveDetectionWidget> createState() => _LiveDetectionWidgetState();
}

class _LiveDetectionWidgetState extends State<_LiveDetectionWidget> {
  late final FaceDetectionService _detector = widget.detection;
  late final CameraController _controller;
  late final Future<void> _initializeControllerFuture;
  final _blinkDetector = AdvancedBlinkDetector();
  final _facesNotifier = ValueNotifier<Face?>(null);
  StreamSubscription<(List<Face>, CameraImage)>? _detectionStream;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();

    _initializeCamera();
    _setupDetectionStreams();
  }

  void _initializeCamera() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream(_detector.process);
    });
  }

  void _setupDetectionStreams() {
    _detectionStream = _detector.stream.listen((event) {
      _handleFaceDetection(event.$1, event.$2);
    });
  }

  Future<void> _handleFaceDetection(List<Face> faces, CameraImage image) async {
    final face = getSingleFace(faces);
    _facesNotifier.value = face;

    if (face == null) return;

    final faceCentered = isFaceCentered(face, _imageSize);
    final isFaceStraight = isFaceLookingStraight(face);

    if (!faceCentered || !isFaceStraight) return;

    final blinkResult = _blinkDetector.processFrame(face);

    if (blinkResult.type == BlinkType.bothEyes && !_isDone) {
      _isDone = true;

      final capturedImage = ImageUtil.convertCameraImageToByteWithRotation(
        image,
        _detector.rotation,
      );
      widget.onDone?.call(capturedImage);
    }
  }

  Future<void> _completDetection() async {
    // widget.onDone?.call(capturedImage);
  }

  Future<Uint8List?> _addWatermarkToImage(Uint8List image) async {
    try {
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/face_$timestamp.jpg';
      final file = File(filePath);

      await file.writeAsBytes(image);

      final watermarkText = DateTime.now().toIso8601String();
      return await addTextWatermark(file, watermarkText);
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      return image;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _facesNotifier.dispose();
    _detectionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildOverlay(),
          _buildBackButton(context),
          _buildInstructionText(context),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Center(
            child: AspectRatio(
              aspectRatio: _imageSize.width / _imageSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller),
                  _buildFaceOverlay(),
                ],
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildFaceOverlay() {
    return ValueListenableBuilder<Face?>(
      valueListenable: _facesNotifier,
      builder: (context, face, child) {
        if (face == null) {
          return const SizedBox.shrink();
        }

        return CustomPaint(painter: FacePainter(face, _imageSize));
      },
    );
  }

  Widget _buildOverlay() {
    return ValueListenableBuilder(
        valueListenable: _facesNotifier,
        builder: (_, face, __) {
          final instructionData = _getInstructionData(face);

          return ValueListenableBuilder<int>(
            valueListenable: widget.timerNotifier,
            builder: (context, seconds, child) {
              return Positioned.fill(
                child: CustomPaint(
                  painter: RPSCustomPainter(
                    borderColor:
                        instructionData.hideEye ? Colors.grey : Colors.green,
                    backgroundColor: Colors.amber,
                    bottomText: '${seconds}s',
                  ),
                ),
              );
            },
          );
        });
  }

  Widget _buildBackButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: const BackButton(),
    );
  }

  Widget _buildInstructionText(BuildContext context) {
    return ValueListenableBuilder<Face?>(
      valueListenable: _facesNotifier,
      builder: (_, face, __) {
        final instructionData = _getInstructionData(face);

        return Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          left: 0,
          right: 0,
          child: Center(
            child: EyeBlinkWidget(
              text: instructionData.text,
              initiallyBlinking: true,
              hideEye: instructionData.hideEye,
              color: instructionData.hideEye ? Colors.white : Colors.green,
            ),
          ),
        );
      },
    );
  }

  _InstructionData _getInstructionData(Face? face) {
    final isFaceCentered0 = isFaceCentered(face, _imageSize);
    final isFaceStraight = isFaceLookingStraight(face);

    if (!isFaceStraight) {
      return const _InstructionData(
        text: 'Look straight to the camera',
        hideEye: true,
      );
    } else if (!isFaceCentered0) {
      return const _InstructionData(
        text: 'Center your face',
        hideEye: true,
      );
    } else {
      return const _InstructionData(
        text: 'Blink your eyes',
        hideEye: false,
      );
    }
  }

  Size get _imageSize => Size(
        _controller.value.previewSize?.height ?? 0,
        _controller.value.previewSize?.width ?? 0,
      );
}

class _InstructionData {
  final String text;
  final bool hideEye;

  const _InstructionData({
    required this.text,
    required this.hideEye,
  });
}
