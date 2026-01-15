part of 'main.dart';

enum LiveDetectionStep { recognize, blink, done }

class LiveDetectionEvent {
  final LiveDetectionStep step;
  final int trackingId;

  LiveDetectionEvent({
    this.step = LiveDetectionStep.recognize,
    this.trackingId = 0,
  });

  LiveDetectionEvent copyWith({
    LiveDetectionStep? step,
    int? trackingId,
  }) =>
      LiveDetectionEvent(
        step: step ?? this.step,
        trackingId: trackingId ?? this.trackingId,
      );
}

enum _Stage { initializing, expired, completed }

class LiveDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceDetectionService detection;

  const LiveDetectionScreen(
      {required this.camera,
      required this.detection,
      required this.recognition,
      super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  _Stage _stage = _Stage.initializing;
  final _durationInSeconds = 300;
  late final _timerNotifier = ValueNotifier<int>(_durationInSeconds);
  Timer? _timer;
  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();

    resetTimer();
  }

  void resetTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerNotifier.value > 0) {
        _timerNotifier.value -= 1;
      } else {
        setState(() {
          _stage = _Stage.expired;
        });
        _timer?.cancel();
      }
    });
    _timerNotifier.value = _durationInSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.completed) {
      return Scaffold(
        body: Center(
          child: Stack(
            children: [
              if (_capturedImage != null)
                Image.memory(
                  _capturedImage!,
                ),
              Positioned.fill(
                  child: Column(
                children: [
                  const Spacer(),
                  Positioned(
                      top: MediaQuery.of(context).padding.top + 100,
                      left: 20,
                      child: EyeBlinkWidget(text: 'Please blink your eyes')),
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _stage = _Stage.initializing;
                              resetTimer();
                            });
                          },
                          child: Text('Restart Detection'),
                        ),
                        TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('Back to Home')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ))
            ],
          ),
        ),
      );
    }

    if (_stage == _Stage.expired) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Txt('Time Expired',
                  style: TxtStyle()
                    ..fontSize(24)
                    ..textColor(Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _stage = _Stage.initializing;
                    resetTimer();
                  });
                },
                child: Text('Restart Detection'),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Back to Home')),
            ],
          ),
        ),
      );
    }

    return _LiveDetectionWidget(
      camera: widget.camera,
      detection: widget.detection,
      recognition: widget.recognition,
      timerNotifier: _timerNotifier,
      onChange: (event, img) {
        if (event.step == LiveDetectionStep.done) {
          setState(() {
            _timer?.cancel();
            _capturedImage = img;
            _stage = _Stage.completed;
          });
        }
      },
    );
  }
}

class _LiveDetectionWidget extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceDetectionService detection;
  final ValueNotifier<int> timerNotifier;
  final Function(LiveDetectionEvent event, Uint8List? img)? onChange;

  const _LiveDetectionWidget({
    required this.camera,
    required this.detection,
    required this.recognition,
    required this.timerNotifier,
    this.onChange,
  });

  @override
  State<_LiveDetectionWidget> createState() => _LiveDetectionWidgetState();
}

class _LiveDetectionWidgetState extends State<_LiveDetectionWidget> {
  late final _detector = widget.detection;
  StreamSubscription<List<Face>>? _detectionStream;
  late final _recognition = widget.recognition..reset();
  StreamSubscription<RecognitionServiceData?>? _recognitionStream;
  final _blinkDetector = AdvancedBlinkDetector();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final _facesNotifier = ValueNotifier<Face?>(null);
  CameraImage? _image;
  int _currentTrackingId = 0;

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
        _image = image;
        _detector.processCameraImage(image);
        _recognition.process(image);
      });
    });

    _detectionStream = _detector.stream.listen((faces) async {
      if (_value.step == LiveDetectionStep.done) return;

      final face = getSingleFace(faces);
      _facesNotifier.value = face;

      final id = face?.trackingId ?? 0;

      if (id != 0 && id != _currentTrackingId) {
        _currentTrackingId = id;
      }

      // Reset
      if (_currentTrackingId != _value.trackingId) {
        _blinkDetector.resetCalibration();
        _recognition.reset();
        _value = _value.copyWith(
          step: LiveDetectionStep.recognize,
          trackingId: _currentTrackingId,
        );
        _valueStream.add(_value);
        widget.onChange?.call(_value, null);
        print('--=> Reset');
      }

      // Blink step
      if (_value.step == LiveDetectionStep.blink && face != null) {
        final isFaceCentered0 = isFaceCentered(face, _imageSize);
        final isFaceProperSize0 = isFaceLookingStraight(face);

        if (!isFaceCentered0 || !isFaceProperSize0) {
          return;
        }

        final blinking = _blinkDetector.processFrame(face);

        if (blinking.type == BlinkType.bothEyes) {
          _value = _value.copyWith(step: LiveDetectionStep.done);
          _valueStream.add(_value);
          Uint8List? image;
          if (_image != null) {
            image = ImageUtil.convertCameraImageToByteWithOptions(
              _image!,
              rotation: _detector.rotation,
              quality: 50,
            );
          }

          Uint8List? img;

          if (image != null) {
            final tempDir = Directory.systemTemp;
            final filePath =
                '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(filePath);
            file.writeAsBytesSync(image);
            final rawPath = Uint8List.fromList(filePath.codeUnits);
            img = await addTextWatermark(
                File.fromRawPath(rawPath), 'Verified at ${DateTime.now()}');
          }
          widget.onChange?.call(_value, img);
        }
      }
    });
    _recognitionStream = _recognition.stream.listen((data) {
      final isVerified = data?.isVerify ?? false;

      if (isVerified) {
        _value = _value.copyWith(step: LiveDetectionStep.blink);
        _valueStream.add(_value);
        widget.onChange?.call(_value, null);
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
                                  _value.step == LiveDetectionStep.done) {
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
                final isVerified = data?.step != LiveDetectionStep.recognize;

                return ValueListenableBuilder(
                    valueListenable: widget.timerNotifier,
                    builder: (_, t, w) {
                      final duration = Duration(seconds: t);
                      return Positioned.fill(
                          child: StreamBuilder(
                              stream: _valueStream.stream,
                              builder: (_, s) {
                                return CustomPaint(
                                    painter: RPSCustomPainter(
                                  borderColor: isVerified ? Colors.green : null,
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  bottomText: '${duration.inSeconds}s',
                                ));
                              }));
                    });
              }),
          Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: const BackButton()),
          ValueListenableBuilder(
            valueListenable: _facesNotifier,
            builder: (_, face, w) => StreamBuilder(
                stream: _valueStream.stream,
                builder: (_, s) {
                  String text = 'Please look at the camera';

                  if (s.data?.step == LiveDetectionStep.blink) {
                    text = 'Please blink your eyes';
                  }

                  final isFaceCentered0 = isFaceCentered(face, _imageSize);

                  final isFaceProperSize0 = isFaceLookingStraight(face);

                  if (!isFaceProperSize0) {
                    text = 'Please look straight to the camera';
                  }

                  if (!isFaceCentered0) {
                    text = 'Please center your face';
                  }

                  return Positioned(
                      top: MediaQuery.of(context).padding.top + 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: EyeBlinkWidget(
                          text: text,
                          hideEye: s.data?.step != LiveDetectionStep.blink,
                          color: Colors.black,
                        ),
                      ));
                }),
          ),
        ],
      ),
    );
  }

  Size get _imageSize => Size(_controller.value.previewSize?.height ?? 0,
      _controller.value.previewSize?.width ?? 0);
}
