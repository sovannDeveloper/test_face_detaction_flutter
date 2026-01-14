part of 'main.dart';

enum DetectionStep { recognize, blink, done }

class LiveDetectionEvent {
  final DetectionStep step;
  final int trackingId;

  LiveDetectionEvent({
    this.step = DetectionStep.recognize,
    this.trackingId = 0,
  });

  LiveDetectionEvent copyWith({
    DetectionStep? step,
    int? trackingId,
  }) =>
      LiveDetectionEvent(
        step: step ?? this.step,
        trackingId: trackingId ?? this.trackingId,
      );
}

class LiveDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceDetectionService detection;

  const LiveDetectionScreen({
    super.key,
    required this.camera,
    required this.detection,
    required this.recognition,
  });

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  late final _detector = widget.detection;
  StreamSubscription<List<Face>>? _detectionStream;
  late final _recognition = widget.recognition..reset();
  StreamSubscription<RecognitionServiceData?>? _recognitionStream;
  final _blinkDetector = AdvancedBlinkDetector();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final _facesNotifier = ValueNotifier<Face?>(null);

  /// Value
  final _valueStream = StreamController<LiveDetectionEvent>.broadcast();
  LiveDetectionEvent _value = LiveDetectionEvent();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream((image) {
        _detector.processCameraImage(image);
        _recognition.process(image);
      });
    });

    _detectionStream = _detector.stream.listen((faces) {
      if (_value.step == DetectionStep.done) return;

      final face = getSingleFace(faces);

      _facesNotifier.value = face;

      // Reset
      if (face?.trackingId != _value.trackingId) {
        _blinkDetector.resetCalibration();
        _recognition.reset();
        _value = _value.copyWith(
          step: DetectionStep.recognize,
          trackingId: face?.trackingId ?? 0,
        );
        _valueStream.add(_value);
        print('--=> Reset');
      }

      // Blink step
      if (_value.step == DetectionStep.blink && face != null) {
        final blinking = _blinkDetector.processFrame(face);

        print('--=> ${blinking.type}');

        if (blinking.type == BlinkType.bothEyes) {
          _value = _value.copyWith(step: DetectionStep.done);
          _valueStream.add(_value);
        }
      }
    });
    _recognitionStream = _recognition.stream.listen((data) {
      final isVerified = data?.isVerify ?? false;

      if (isVerified) {
        _value = _value.copyWith(step: DetectionStep.blink);
        _valueStream.add(_value);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _valueStream.close();
    _facesNotifier.dispose();
    _detectionStream?.cancel();
    _recognitionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: _imageSize.width / _imageSize.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller),
                        ValueListenableBuilder(
                            valueListenable: _facesNotifier,
                            builder: (_, face, w) {
                              if (face == null ||
                                  _value.step == DetectionStep.done) {
                                return const SizedBox();
                              }

                              final pain = FacePainter(face, _imageSize);
                              return CustomPaint(painter: pain);
                            }),
                      ],
                    ),
                  ),
                );
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
          StreamBuilder(
              stream: _valueStream.stream,
              builder: (_, s) {
                final data = s.data;
                final isVerified = data?.step != DetectionStep.recognize;

                return Positioned.fill(
                    child: CustomPaint(
                        painter: RPSCustomPainter(
                  borderColor: isVerified ? Colors.green : null,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  topText: 'Please blink your eyes',
                  bottomText: '03:00 ${data?.step}',
                )));
              }),
        ],
      ),
    );
  }

  Size get _imageSize => Size(_controller.value.previewSize!.height,
      _controller.value.previewSize!.width);
}
