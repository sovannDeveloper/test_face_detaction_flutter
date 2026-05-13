part of 'main.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0F);
const _kSurface = Color(0xFF1C1C1E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen = Color(0xFF30D158);
const _kRed = Color(0xFFFF453A);
const _kText2 = Color(0xFF8E8E93);

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
  static const _durationInSeconds = 300;

  _Stage _stage = _Stage.initializing;
  late final ValueNotifier<int> _timerNotifier = ValueNotifier(_durationInSeconds);
  Timer? _timer;
  Uint8List? _capturedImage;

  // Parsed detection results
  bool? _matched;
  double? _matchConfidence;
  bool? _isReal;
  double? _spoofConfidence;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timerNotifier.value = _durationInSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerNotifier.value > 0) {
        _timerNotifier.value--;
      } else {
        setState(() => _stage = _Stage.expired);
        t.cancel();
      }
    });
  }

  void _restartDetection() {
    setState(() {
      _stage = _Stage.initializing;
      _capturedImage = null;
      _matched = null;
      _matchConfidence = null;
      _isReal = null;
      _spoofConfidence = null;
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
      backgroundColor: Colors.black,
      appBar: _stage == _Stage.initializing
          ? null
          : AppBar(
              backgroundColor: _kBg,
              elevation: 0,
              leading: const BackButton(color: Colors.white),
              title: Text(
                _stage == _Stage.completed
                    ? 'Detection Complete'
                    : 'Time Expired',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _restartDetection,
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: switch (_stage) {
        _Stage.initializing => _buildDetectionWidget(),
        _Stage.expired => _buildExpiredScreen(),
        _Stage.completed => _buildCompletedScreen(),
      },
    );
  }

  // ── Completed screen ───────────────────────────────────────────────────────

  Widget _buildCompletedScreen() {
    return SafeArea(
      child: Column(
        children: [
          // Captured face preview
          if (_capturedImage != null)
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_matched ?? false) ? _kGreen : const Color(0xFF2C2C2E),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    _capturedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),

          // Result cards
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (_matched != null) ...[
                    _ResultTile(
                      icon: _matched!
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      iconColor: _matched! ? _kGreen : _kRed,
                      title: _matched! ? 'Face Matched' : 'No Match Found',
                      subtitle: _matchConfidence != null
                          ? 'Confidence: ${(_matchConfidence! * 100).toStringAsFixed(1)}%'
                          : '',
                      badgeText: _matched! ? 'MATCH' : 'NO MATCH',
                      badgeColor: _matched! ? _kGreen : _kRed,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_isReal != null) ...[
                    _ResultTile(
                      icon: _isReal!
                          ? Icons.verified_user_rounded
                          : Icons.warning_amber_rounded,
                      iconColor: _isReal! ? _kGreen : _kRed,
                      title: _isReal! ? 'Real Face' : 'Spoof Detected',
                      subtitle: _spoofConfidence != null
                          ? 'Score: ${(_spoofConfidence! * 100).toStringAsFixed(1)}%'
                          : '',
                      badgeText: _isReal! ? 'REAL' : 'SPOOF',
                      badgeColor: _isReal! ? _kGreen : _kRed,
                    ),
                    const SizedBox(height: 8),
                  ],

                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kText2,
                            side: const BorderSide(color: Color(0xFF2C2C2E)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _restartDetection,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Expired screen ────────────────────────────────────────────────────────

  Widget _buildExpiredScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded, size: 40, color: _kRed),
            ),
            const Text(
              'Time Expired',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The detection window has closed.\nPlease try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kText2, height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _restartDetection,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _kText2),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live detection widget ─────────────────────────────────────────────────

  Widget _buildDetectionWidget() {
    return _LiveDetectionWidget(
      camera: widget.camera,
      detection: widget.detection,
      recognition: widget.recognition,
      timerNotifier: _timerNotifier,
      onDone: (img) async {
        if (img != null) {
          try {
            final results = await Future.wait([
              widget.recognition.recognize(img),
              widget.spoofingDetector.detect(img),
            ]);
            final recognition = results[0];
            final spoof = results[1];

            _matched = recognition?['matched'] as bool?;
            _matchConfidence = recognition?['confidence'] as double?;
            _isReal = spoof?['isReal'] as bool?;
            _spoofConfidence = spoof?['confidence'] as double?;
          } catch (_) {}
        }

        _timer?.cancel();
        setState(() {
          _capturedImage = img;
          _stage = _Stage.completed;
        });
      },
    );
  }
}

// ── Result tile ────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;

  const _ResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _kText2),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live camera widget ─────────────────────────────────────────────────────

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
      ResolutionPreset.medium,
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
    final isFitted = isFaceFitted(face, _imageSize);

    if (!isFitted || !faceCentered || !isFaceStraight) return;

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
                  Transform.scale(scaleX: -1, child: _buildFaceOverlay()),
                ],
              ),
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: _kPrimary),
        );
      },
    );
  }

  Widget _buildFaceOverlay() {
    return ValueListenableBuilder<Face?>(
      valueListenable: _facesNotifier,
      builder: (_, face, __) {
        if (face == null) return const SizedBox.shrink();
        return CustomPaint(painter: FacePainter(face, _imageSize));
      },
    );
  }

  Widget _buildOverlay() {
    return ValueListenableBuilder(
      valueListenable: _facesNotifier,
      builder: (_, face, __) {
        final data = _getInstructionData(face);
        return ValueListenableBuilder<int>(
          valueListenable: widget.timerNotifier,
          builder: (_, seconds, __) {
            return Positioned.fill(
              child: CustomPaint(
                painter: RPSCustomPainter(
                  borderColor:
                      data.hideEye ? Colors.grey : Colors.green,
                  backgroundColor: Colors.amber,
                  bottomText: '${seconds}s',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: const BackButton(color: Colors.white),
    );
  }

  Widget _buildInstructionText(BuildContext context) {
    return ValueListenableBuilder<Face?>(
      valueListenable: _facesNotifier,
      builder: (_, face, __) {
        final data = _getInstructionData(face);
        return Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          left: 0,
          right: 0,
          child: Center(
            child: EyeBlinkWidget(
              text: data.text,
              initiallyBlinking: true,
              hideEye: data.hideEye,
              color: data.hideEye ? Colors.white : Colors.green,
            ),
          ),
        );
      },
    );
  }

  _InstructionData _getInstructionData(Face? face) {
    if (!isFaceFitted(face, _imageSize)) {
      return const _InstructionData(
        text: 'Move the camera closer',
        hideEye: true,
      );
    } else if (!isFaceLookingStraight(face)) {
      return const _InstructionData(
        text: 'Look straight at the camera',
        hideEye: true,
      );
    } else if (!isFaceCentered(face, _imageSize)) {
      return const _InstructionData(text: 'Center your face', hideEye: true);
    } else {
      return const _InstructionData(text: 'Blink your eyes', hideEye: false);
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
  const _InstructionData({required this.text, required this.hideEye});
}
